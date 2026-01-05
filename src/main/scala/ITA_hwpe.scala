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
  MemDataWidth: Int = 64,
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
  externallyClocked: Boolean = false
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
    val tcdm_req_o = Output(Vec(params.MP, Bool()))
    val tcdm_gnt_i = Input(Vec(params.MP, Bool()))
    val tcdm_add_o = Output(Vec(params.MP, UInt(32.W)))
    val tcdm_wen_o = Output(Vec(params.MP, Bool()))
    val tcdm_be_o = Output(Vec(params.MP, UInt((params.MemDataWidth/8).W)))
    val tcdm_data_o = Output(Vec(params.MP, UInt(params.MemDataWidth.W)))
    val tcdm_r_data_i = Input(Vec(params.MP, UInt(params.MemDataWidth.W)))
    val tcdm_r_valid_i = Input(Vec(params.MP, Bool()))

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
  addResource("/vsrc/cf_math_pkg.sv")
  addResource("/vsrc/ita_package.sv")
  addResource("/vsrc/hwpe/ita_hwpe_package.sv")
  
  // Main wrapper module
  addResource("/vsrc/hwpe/ita_hwpe_wrap.sv")
  addResource("/vsrc/hwpe/ita_hwpe_top.sv")
  
  // Sub-modules required by ita_hwpe_top
  addResource("/vsrc/hwpe/ita_hwpe_ctrl.sv")
  addResource("/vsrc/hwpe/ita_hwpe_streamer.sv")
  addResource("/vsrc/hwpe/ita_hwpe_engine.sv")
  addResource("/vsrc/hwpe/ita_hwpe_input_buffer.sv")
  addResource("/vsrc/hwpe/ita_hwpe_input_bias_buffer.sv")
  addResource("/vsrc/hwpe/ita_hwpe_input_bias_fence.sv")
  addResource("/vsrc/hwpe/ita_hwpe_output_buffer.sv")
  

  
  // Common cells modules (from PULP/common cells or simulation stubs)
  addResource("/vsrc/fifo_v3.sv")
  addResource("/vsrc/tc_sram.sv")
  addResource("/vsrc/lzc.sv")
  addResource("/vsrc/cluster_clock_gating.sv")

  // Set parameters
  override def desiredName = s"ita_hwpe_wrap"
  
  // Add parameters as Verilog parameters
  val moduleName = desiredName
  val paramMap = Map(
    "AccDataWidth" -> IntParam(params.AccDataWidth),
    "IdWidth" -> IntParam(params.IdWidth),
    "MemDataWidth" -> IntParam(params.MemDataWidth),
    "MP" -> IntParam(params.MP)
  )
}

// ITA HWPE Top IO
class ITAHWPETopIO(params: ITAHWPEParams) extends Bundle {
  val ita_busy = Output(Bool())
  val evt = Output(Vec(params.N_CORES, UInt(2.W)))
  
  // TCDM master ports
  val tcdm_req = Output(Vec(params.MP, Bool()))
  val tcdm_gnt = Input(Vec(params.MP, Bool()))
  val tcdm_add = Output(Vec(params.MP, UInt(32.W)))
  val tcdm_wen = Output(Vec(params.MP, Bool()))
  val tcdm_be = Output(Vec(params.MP, UInt((params.MemDataWidth/8).W)))
  val tcdm_data = Output(Vec(params.MP, UInt(params.MemDataWidth.W)))
  val tcdm_r_data = Input(Vec(params.MP, UInt(params.MemDataWidth.W)))
  val tcdm_r_valid = Input(Vec(params.MP, Bool()))
}

trait HasITAHWPETopIO {
  def io: ITAHWPETopIO
}

// ITA HWPE TileLink Router
// Note: The TCDM ports would need to be connected to a TCDM interconnect
// The peripheral port is connected via TileLink
class ITAHWPETL(params: ITAHWPEParams, beatBytes: Int)(implicit p: Parameters) extends ClockSinkDomain(ClockSinkParameters())(p) {
  val device = new SimpleDevice("ita-hwpe", Seq("ucbbar,ita-hwpe"))
  val node = TLRegisterNode(Seq(AddressSet(params.address, 4096-1)), device, "reg/control", beatBytes=beatBytes)

  override lazy val module = new ITAHWPEImpl
  class ITAHWPEImpl extends Impl with HasITAHWPETopIO {
    val io = IO(new ITAHWPETopIO(ITAHWPETL.this.params))
    withClockAndReset(clock, reset) {
      // Instantiate the ITA HWPE blackbox
      val impl = Module(new ITAHWPEBlackBox(ITAHWPETL.this.params))

      // Connect clock and reset
      impl.io.clk_i := clock
      impl.io.rst_ni := reset
      impl.io.test_mode_i := false.B

      // Connect events and busy
      io.evt := impl.io.evt_o
      io.ita_busy := impl.io.busy_o

      // Connect TCDM ports
      io.tcdm_req := impl.io.tcdm_req_o
      impl.io.tcdm_gnt_i := io.tcdm_gnt
      io.tcdm_add := impl.io.tcdm_add_o
      io.tcdm_wen := impl.io.tcdm_wen_o
      io.tcdm_be := impl.io.tcdm_be_o
      io.tcdm_data := impl.io.tcdm_data_o
      impl.io.tcdm_r_data_i := io.tcdm_r_data
      impl.io.tcdm_r_valid_i := io.tcdm_r_valid

      // Bridge TileLink to HWPE peripheral protocol
      // The HWPE control interface uses a simple req/gnt protocol
      val periph_req = RegInit(false.B)
      val periph_gnt = Wire(Bool())
      val periph_add = RegInit(0.U(32.W))
      val periph_wen = RegInit(false.B)
      val periph_be = RegInit(0.U(4.W))
      val periph_data = RegInit(0.U(32.W))
      val periph_id = RegInit(0.U(ITAHWPETL.this.params.IdWidth.W))
      val periph_r_data = Wire(UInt(32.W))
      val periph_r_valid = Wire(Bool())
      val periph_r_id = Wire(UInt(ITAHWPETL.this.params.IdWidth.W))

      // HWPE register file shadow registers (17 registers as per ITA_IO_REGS)
      // These shadow the HWPE internal register file
      val hwpe_regs = RegInit(VecInit(Seq.fill(17)(0.U(32.W))))
      
      // Register file access state machine
      val sIdle :: sWaitGrant :: sWaitResponse :: Nil = Enum(3)
      val state = RegInit(sIdle)
      val pending_addr = RegInit(0.U(32.W))
      val pending_wen = RegInit(false.B)
      val pending_data = RegInit(0.U(32.W))
      val pending_be = RegInit(0.U(4.W))
      val pending_id = RegInit(0.U(ITAHWPETL.this.params.IdWidth.W))
      val pending_reg_idx = RegInit(0.U(5.W))

      // Connect peripheral port to blackbox
      impl.io.periph_req_i := periph_req
      periph_gnt := impl.io.periph_gnt_o
      impl.io.periph_add_i := periph_add
      impl.io.periph_wen_i := periph_wen
      impl.io.periph_be_i := periph_be
      impl.io.periph_data_i := periph_data
      impl.io.periph_id_i := periph_id
      periph_r_data := impl.io.periph_r_data_o
      periph_r_valid := impl.io.periph_r_valid_o
      periph_r_id := impl.io.periph_r_id_o

      // State machine to handle HWPE peripheral protocol
      switch(state) {
        is(sIdle) {
          // Wait for TileLink access
        }
        is(sWaitGrant) {
          when(periph_gnt) {
            periph_req := false.B
            state := sWaitResponse
          }
        }
        is(sWaitResponse) {
          when(periph_r_valid) {
            // Update shadow register on read
            when(!pending_wen) {
              hwpe_regs(pending_reg_idx) := periph_r_data
            }
            state := sIdle
          }
        }
      }

      // TileLink register mapping - bridge to HWPE peripheral protocol
      // HWPE uses register offsets 0-16 (17 registers total, ITA_IO_REGS = 17)
      // Each register is 32 bits, mapped at 4-byte boundaries
      // Register map per ita_hwpe_package.sv:
      //  0: ITA_REG_INPUT_PTR
      //  1: ITA_REG_WEIGHT_PTR0
      //  2: ITA_REG_WEIGHT_PTR1
      //  3: ITA_REG_BIAS_PTR
      //  4: ITA_REG_OUTPUT_PTR
      //  5: ITA_REG_SEQ_LENGTH
      //  6: ITA_REG_TILES (tile_s[3:0], tile_e[7:4], tile_p[11:8], tile_f[15:12])
      //  7: ITA_REG_EPS_MULT0 (eps_mult[0-3])
      //  8: ITA_REG_EPS_MULT1 (eps_mult[4-7])
      //  9: ITA_REG_RIGHT_SHIFT0 (right_shift[0-3])
      // 10: ITA_REG_RIGHT_SHIFT1 (right_shift[4-7])
      // 11: ITA_REG_ADD0 (add[0-3])
      // 12: ITA_REG_ADD1 (add[4-7])
      // 13: ITA_REG_CTRL_ENGINE (layer[1:0], activation[3:2])
      // 14: ITA_REG_CTRL_STREAM (weight_preload, weight_nextload, bias_disable, bias_direction, output_disable)
      // 15: ITA_REG_GELU_B_C (gelu_b[15:0], gelu_c[31:16])
      // 16: ITA_REG_ACTIVATION_REQUANT (activation_requant_mult[7:0], activation_requant_shift[15:8], activation_requant_add[23:16])
      
      // TileLink to HWPE register bridge
      // Writes: Immediately update shadow register and forward to HWPE via peripheral protocol
      // Reads: Return shadow register value (updated when HWPE responds to previous reads)
      // Note: Shadow registers are updated on write completion and read responses.
      // For guaranteed fresh reads, a blocking read implementation would be needed.
      val regmap_entries = (0 until 17).map { i =>
        val reg_offset = i * 4
        reg_offset -> Seq(
          // Read-write field: return shadow register value on read, update on write
          RegField(32, hwpe_regs(i), (valid: Bool, data: UInt) => {
            when(valid && state === sIdle) {
              pending_addr := reg_offset.U
              pending_wen := true.B
              pending_data := data
              pending_be := 0xf.U // Full word write
              pending_id := 0.U
              pending_reg_idx := i.U
              periph_req := true.B
              periph_add := reg_offset.U
              periph_wen := true.B
              periph_data := data
              periph_be := 0xf.U
              periph_id := 0.U
              state := sWaitGrant
              // Update shadow immediately for write
              hwpe_regs(i) := data
            }
            true.B
          })
        )
      }
      
      // Optional: Background refresh of shadow registers
      // This could be done periodically or on demand
      // For now, shadow registers are updated on writes and read responses

      // Also add a status register to read busy state
      val status_reg = RegInit(0.U(32.W))
      status_reg := Cat(0.U(31.W), impl.io.busy_o)

      // Combine all register map entries (17 HWPE registers + status register)
      val all_regmap_entries = regmap_entries :+ (0x44 -> Seq(RegField.r(32, status_reg)))

      node.regmap(all_regmap_entries: _*)
    }
  }
}

// Trait to add ITA HWPE to a subsystem
trait CanHavePeripheryITAHWPE { this: BaseSubsystem =>
  private val portName = "ita-hwpe"

  private val pbus = locateTLBusWrapper(PBUS)

  val (ita_hwpe_busy, ita_hwpe_clock, ita_hwpe_tcdm_ports) = p(ITAHWPEKey) match {
    case Some(params: ITAHWPEParams) => {
      // Handle external clocking if needed
      val ita_hwpe_clock = Option.when(params.externallyClocked) {
        InModuleBody { IO(Input(Clock())).suggestName("ita_hwpe_clock_in") }
      }

      val itaHWPEClockNode = if (params.externallyClocked) {
        val itaSourceClockNode = ClockSourceNode(Seq(ClockSourceParameters()))
        InModuleBody {
          itaSourceClockNode.out(0)._1.clock := ita_hwpe_clock.get
          itaSourceClockNode.out(0)._1.reset := ResetCatchAndSync(ita_hwpe_clock.get, pbus.module.reset.asBool)
        }
        itaSourceClockNode
      } else {
        pbus.fixedClockNode
      }

      val itaHWPECrossing = if (params.externallyClocked) {
        AsynchronousCrossing()
      } else {
        SynchronousCrossing()
      }

      // Instantiate ITA HWPE module
      val ita_hwpe = LazyModule(new ITAHWPETL(params, pbus.beatBytes)(p))
      ita_hwpe.clockNode := itaHWPEClockNode

      // Connect peripheral registers
      pbus.coupleTo(portName) {
        TLInwardClockCrossingHelper("ita_hwpe_crossing", ita_hwpe, ita_hwpe.node)(itaHWPECrossing) :=
        TLFragmenter(pbus.beatBytes, pbus.blockBytes) := _
      }
      
      // Expose busy signal and events
      val ita_hwpe_busy = InModuleBody {
        val busy = IO(Output(Bool())).suggestName("ita_hwpe_busy")
        val evt = IO(Output(Vec(params.N_CORES, UInt(2.W)))).suggestName("ita_hwpe_evt")
        busy := ita_hwpe.module.io.ita_busy
        evt := ita_hwpe.module.io.evt
        busy
      }

      // Expose TCDM ports - these need to be connected to TCDM interconnect
      val ita_hwpe_tcdm_ports = InModuleBody {
        val tcdm_req = IO(Output(Vec(params.MP, Bool()))).suggestName("ita_hwpe_tcdm_req")
        val tcdm_add = IO(Output(Vec(params.MP, UInt(32.W)))).suggestName("ita_hwpe_tcdm_add")
        val tcdm_wen = IO(Output(Vec(params.MP, Bool()))).suggestName("ita_hwpe_tcdm_wen")
        val tcdm_be = IO(Output(Vec(params.MP, UInt((params.MemDataWidth/8).W)))).suggestName("ita_hwpe_tcdm_be")
        val tcdm_data = IO(Output(Vec(params.MP, UInt(params.MemDataWidth.W)))).suggestName("ita_hwpe_tcdm_data")
        
        // For input ports that are not yet connected, use wires with default values
        // These can be replaced with IO ports when TCDM interconnect is added
        val tcdm_gnt = WireDefault(VecInit(Seq.fill(params.MP)(false.B)))
        val tcdm_r_data = WireDefault(VecInit(Seq.fill(params.MP)(0.U(params.MemDataWidth.W))))
        val tcdm_r_valid = WireDefault(VecInit(Seq.fill(params.MP)(false.B)))

        // Connect to module IO
        tcdm_req := ita_hwpe.module.io.tcdm_req
        ita_hwpe.module.io.tcdm_gnt := tcdm_gnt
        tcdm_add := ita_hwpe.module.io.tcdm_add
        tcdm_wen := ita_hwpe.module.io.tcdm_wen
        tcdm_be := ita_hwpe.module.io.tcdm_be
        tcdm_data := ita_hwpe.module.io.tcdm_data
        ita_hwpe.module.io.tcdm_r_data := tcdm_r_data
        ita_hwpe.module.io.tcdm_r_valid := tcdm_r_valid

        // Return a bundle or tuple for access
        // For now, we'll just return the ports as a reference
        // In practice, these would be connected to a TCDM interconnect
        (tcdm_req, tcdm_gnt, tcdm_add, tcdm_wen, tcdm_be, tcdm_data, tcdm_r_data, tcdm_r_valid)
      }
      
      (Some(ita_hwpe_busy), ita_hwpe_clock, Some(ita_hwpe_tcdm_ports))
    }
    case None => (None, None, None)
  }
}

// Config fragment to enable ITA HWPE
class WithITAHWPE(
  address: BigInt = 0x6000,
  AccDataWidth: Int = 1024,
  IdWidth: Int = 2,
  MemDataWidth: Int = 64,
  N: Int = 16,
  M: Int = 64,
  S: Int = 64,
  P: Int = 64,
  E: Int = 64,
  H: Int = 1,
  N_CORES: Int = 9,
  externallyClocked: Boolean = false
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
    N_CORES = N_CORES,
    externallyClocked = externallyClocked
  ))
})

