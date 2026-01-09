package chipyard.ita

import chisel3._
import chisel3.util._
import chisel3.experimental.{IntParam, BaseModule}
import freechips.rocketchip.amba.axi4._
import freechips.rocketchip.prci._
import freechips.rocketchip.subsystem.{BaseSubsystem, PBUS}
import org.chipsalliance.cde.config.{Parameters, Field, Config}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.regmapper.{HasRegMap, RegField}
import freechips.rocketchip.tilelink._
import freechips.rocketchip.util._

// ITA HWPE Parameters
case class ITAHWPEParams(
  address: BigInt = 0x6000,
  // HWPE params
  AccDataWidth: Int = 1024,
  IdWidth: Int = 2,
  // System params
  MemDataWidth: Int = 32,
  // ITA dimensions - these should match the SystemVerilog parameters
  N: Int = 16,  // Number of parallel units
  M: Int = 64,  // Input dimension
  S: Int = 64,  // Sequence length
  P: Int = 64,  // Projection space
  E: Int = 64,  // Embedding size
  H: Int = 1,   // Number of heads
  WI: Int = 8,  // Input width
  WO: Int = 26, // Output width
  EMS: Int = 8, // Requant constant width
  GELU_CONSTANTS_WIDTH: Int = 16, // GELU constant width
  N_REQUANT_CONSTS: Int = 8, // Number of requantization constants
  N_WRITE_EN: Int = 64, // Write enable width defaults to M
  N_CORES: Int = 9, // Number of cores for events
) {
  require(AccDataWidth % MemDataWidth == 0, "AccDataWidth must be divisible by MemDataWidth")
  val MP = AccDataWidth / MemDataWidth // Number of TCDM master ports
}

// ITA HWPE Key
case object ITAHWPEKey extends Field[Option[ITAHWPEParams]](None)

// ITA HWPE BlackBox - wraps ita_hwpe_wrap.sv
class ITAHWPEBlackBox(params: ITAHWPEParams) extends BlackBox with HasBlackBoxResource {
  val io = IO(new Bundle {
    val clk_i = Input(Clock())
    val rst_ni = Input(Reset())
    val test_mode_i = Input(Bool())

    // Events and busy
    val evt_o = Output(Vec(params.N_CORES, UInt(2.W)))
    val busy_o = Output(Bool())

    // TCDM master ports (MP ports)
    val tcdm_req_o = Output(UInt(params.MP.W))
    val tcdm_gnt_i = Input(UInt(params.MP.W))
    val tcdm_add_o = Output(Vec(params.MP, UInt(32.W)))
    val tcdm_wen_o = Output(UInt(params.MP.W))
    val tcdm_be_o = Output(Vec(params.MP, UInt((params.MemDataWidth/8).W)))
    val tcdm_data_o = Output(Vec(params.MP, UInt(params.MemDataWidth.W)))
    val tcdm_r_data_i = Input(Vec(params.MP, UInt(params.MemDataWidth.W)))
    val tcdm_r_valid_i = Input(UInt(params.MP.W))

    // Peripheral slave port
    val periph_req_i = Input(Bool())
    val periph_gnt_o = Output(Bool())
    val periph_add_i = Input(UInt(32.W))
    val periph_wen_i = Input(Bool())
    val periph_be_i = Input(UInt(4.W))
    val periph_data_i = Input(UInt(32.W))
    val periph_id_i = Input(UInt(params.IdWidth.W))
    val periph_r_data_o = Output(UInt(32.W))
    val periph_r_valid_o = Output(Bool())
    val periph_r_id_o = Output(UInt(params.IdWidth.W))
  })

  // Add required SystemVerilog resources
  // Package must be added FIRST - all other modules import it
  addResource("/vsrc/hwpe/ita_hwpe_aggregated.sv")

  // Set parameters
  override def desiredName = s"ITAHWPEBlackBox"
  
  // Add parameters as Verilog parameters
  val moduleName = desiredName
  val paramMap = Map(
    "AccDataWidth" -> IntParam(params.AccDataWidth),
    "IdWidth" -> IntParam(params.IdWidth),
    "MemDataWidth" -> IntParam(params.MemDataWidth),
    "MP" -> IntParam(params.MP),
    "N_CORES" -> IntParam(params.N_CORES)
  )
}

// ITA HWPE Top IO
class ITAHWPETopIO(params: ITAHWPEParams) extends Bundle {
  val ita_busy = Output(Bool())
}

trait HasITAHWPETopIO {
  def io: ITAHWPETopIO
}

class ITAHWPETL(params: ITAHWPEParams, beatBytes: Int)(implicit p: Parameters) extends ClockSinkDomain(ClockSinkParameters())(p) {
  val device = new SimpleDevice("ita-hwpe", Seq("ucbbar,ita-hwpe"))
  val node = TLRegisterNode(Seq(AddressSet(params.address, 4096-1)), device, "reg/control", beatBytes=beatBytes)
  
  override lazy val module = new ITAHWPEImpl
  class ITAHWPEImpl extends Impl with HasITAHWPETopIO {
    val io = IO(new ITAHWPETopIO(params))
    withClockAndReset(clock, reset) {
      // Instantiate the ITA HWPE blackbox
      val impl = Module(new ITAHWPEBlackBox(params))

      // Connect clock and reset
      impl.io.clk_i := clock
      impl.io.rst_ni := reset
      impl.io.test_mode_i := false.B

      // Connect events and busy
      io.ita_busy := impl.io.busy_o

      // Registers to drive inputs coming from the memory-mapped side
      val tcdmGntReg      = RegInit(0.U(params.MP.W))
      val tcdmRValidReg   = RegInit(0.U(params.MP.W))
      val tcdmRDataReg    = Reg(Vec(params.MP, UInt(params.MemDataWidth.W)))
      val periphReqReg    = RegInit(false.B)
      val periphAddReg    = RegInit(0.U(32.W))
      val periphWenReg    = RegInit(false.B)
      val periphBeReg     = RegInit(0.U(4.W))
      val periphDataReg   = RegInit(0.U(32.W))
      val periphIdReg     = RegInit(0.U(params.IdWidth.W))

      // Hook input regs to the blackbox
      impl.io.tcdm_gnt_i    := tcdmGntReg
      impl.io.tcdm_r_valid_i:= tcdmRValidReg
      impl.io.tcdm_r_data_i := tcdmRDataReg
      impl.io.periph_req_i  := periphReqReg
      impl.io.periph_add_i  := periphAddReg
      impl.io.periph_wen_i  := periphWenReg
      impl.io.periph_be_i   := periphBeReg
      impl.io.periph_data_i := periphDataReg
      impl.io.periph_id_i   := periphIdReg

      // Address planning to keep blocks contiguous
      // Note: Registers wider than 4 bytes must be 8-byte aligned
      // Event registers take N_CORES * 4 bytes, then TCDM req/gnt at N_CORES * 4
      val tcdmAddBase   = (params.N_CORES * 4) + 8  // After events (N_CORES * 4) and TCDM req/gnt (8 bytes)
      val tcdmBeBase    = tcdmAddBase + params.MP * 4
      // Round up to next 8-byte boundary for 64-bit registers
      val tcdmBeStart   = ((tcdmBeBase + 4 + 7) / 8) * 8
      // tcdmBeStart registers are 8 bytes wide, so space them 8 bytes apart
      val tcdmDataBase  = tcdmBeStart + params.MP * 8
      // tcdmDataBase registers are 8 bytes wide (64 bits), so space them 8 bytes apart
      val tcdmRDataBase = tcdmDataBase + params.MP * 8
      // tcdmRDataBase registers are 8 bytes wide (64 bits), so space them 8 bytes apart
      val tcdmRValidOff = tcdmRDataBase + params.MP * 8
      val periphBase    = tcdmRValidOff + 4

      val regFields =
        // Event outputs - one register per core (2 bits each, spaced 4 bytes apart)
        (0 until params.N_CORES).map { i =>
          (i * 4) -> Seq(RegField.r(2, impl.io.evt_o(i)))
        } ++
        Seq(
          // Start TCDM registers after all event registers
          (params.N_CORES * 4) -> Seq(RegField.r(params.MP, impl.io.tcdm_req_o.asUInt)),
          (params.N_CORES * 4 + 4) -> Seq(RegField.w(params.MP, tcdmGntReg))
        ) ++
        (0 until params.MP).map { i =>
          (tcdmAddBase + i * 4) -> Seq(RegField.r(32, impl.io.tcdm_add_o(i)))
        } ++
        Seq(
          tcdmBeBase -> Seq(RegField.r(params.MP, impl.io.tcdm_wen_o.asUInt))
        ) ++
        (0 until params.MP).map { i =>
          (tcdmBeStart + i * 8) -> Seq(RegField.r(params.MemDataWidth/8, impl.io.tcdm_be_o(i)))
        } ++
        (0 until params.MP).map { i =>
          (tcdmDataBase + i * 8) -> Seq(RegField.r(params.MemDataWidth, impl.io.tcdm_data_o(i)))
        } ++
        (0 until params.MP).map { i =>
          (tcdmRDataBase + i * 8) -> Seq(RegField.w(params.MemDataWidth, tcdmRDataReg(i)))
        } ++
        Seq(
          tcdmRValidOff -> Seq(RegField.w(params.MP, tcdmRValidReg)),
          periphBase    -> Seq(RegField.w(1, periphReqReg)),
          periphBase+4  -> Seq(RegField.r(1, impl.io.periph_gnt_o)),
          periphBase+8  -> Seq(RegField.w(32, periphAddReg)),
          periphBase+12 -> Seq(RegField.w(1, periphWenReg)),
          periphBase+16 -> Seq(RegField.w(4, periphBeReg)),
          periphBase+20 -> Seq(RegField.w(32, periphDataReg)),
          periphBase+24 -> Seq(RegField.w(params.IdWidth, periphIdReg)),
          periphBase+28 -> Seq(RegField.r(32, impl.io.periph_r_data_o)),
          periphBase+32 -> Seq(RegField.r(1, impl.io.periph_r_valid_o)),
          periphBase+36 -> Seq(RegField.r(params.IdWidth, impl.io.periph_r_id_o))
        )

      node.regmap(regFields: _*)
    }
  }
}

// Trait to add ITA HWPE to a subsystem
trait CanHavePeripheryITAHWPE { this: BaseSubsystem =>
  private val portName = "ita"
  private val pbus = locateTLBusWrapper(PBUS)

  private val ita_hwpe_inst = p(ITAHWPEKey).map { params =>
    val ita_hwpe = LazyModule(new ITAHWPETL(params, pbus.beatBytes)(p))
    ita_hwpe.clockNode := pbus.fixedClockNode
    pbus.coupleTo(portName) {
      TLInwardClockCrossingHelper("ita_hwpe_crossing", ita_hwpe, ita_hwpe.node)(SynchronousCrossing()) :=
        TLFragmenter(pbus.beatBytes, pbus.blockBytes) := _
    }
    ita_hwpe
  }

  val ita_hwpe_busy = ita_hwpe_inst.map { ita_hwpe =>
    InModuleBody {
      val busy = IO(Output(Bool())).suggestName("ita_hwpe_busy")
      busy := ita_hwpe.module.io.ita_busy
      busy
    }
  }
}


// Config fragment to enable ITA HWPE
class WithITAHWPE(
  address: BigInt = 0x6000,
  AccDataWidth: Int = 1024,
  IdWidth: Int = 2,
  MemDataWidth: Int = 32,
  N: Int = 16,
  M: Int = 64,
  S: Int = 64,
  P: Int = 64,
  E: Int = 64,
  H: Int = 1,
  N_CORES: Int = 9
) extends Config((site, here, up) => {
  case ITAHWPEKey => Some(ITAHWPEParams(
    address = address,
    AccDataWidth = AccDataWidth,
    IdWidth = IdWidth,
    MemDataWidth = MemDataWidth,
    N = N,
    M = M,
    S = S,
    P = P,
    E = E,
    H = H,
    N_CORES = N_CORES
  ))
})