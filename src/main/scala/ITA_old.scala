/*package chipyard.ita

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

// ITA Parameters
case class ITAParams(
  address: BigInt = 0x5000,
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
  N_REQUANT_CONSTS: Int = 8, // Number of requantization constants
  N_WRITE_EN: Int = 8, // Write enable width
  externallyClocked: Boolean = false
)

// ITA Key
case object ITAKey extends Field[Option[ITAParams]](None)

// Layer type enum (matches layer_e in SystemVerilog: {Attention=0, Feedforward=1, Linear=2, SingleAttention=3})
// Using UInt(2.W) to match the 2-bit enum in SystemVerilog
// Activation type enum (matches activation_e in SystemVerilog: {Identity=0, Gelu=1, Relu=2})
// Using UInt(2.W) to match the 2-bit enum in SystemVerilog

// ITA Control Bundle (matches ctrl_t struct)
class ITACtrl(params: ITAParams) extends Bundle {
  val start = Bool()
  val layer = UInt(2.W) // layer_e: {Attention=0, Feedforward=1, Linear=2, SingleAttention=3}
  val activation = UInt(2.W) // activation_e: {Identity=0, Gelu=1, Relu=2}
  val eps_mult = Vec(params.N_REQUANT_CONSTS, UInt(params.EMS.W))
  val right_shift = Vec(params.N_REQUANT_CONSTS, UInt(params.EMS.W))
  val add = Vec(params.N_REQUANT_CONSTS, SInt(params.WI.W))
  val gelu_b = SInt(16.W) // GELU_CONSTANTS_WIDTH
  val gelu_c = SInt(16.W)
  val activation_requant_mult = UInt(params.EMS.W)
  val activation_requant_shift = UInt(params.EMS.W)
  val activation_requant_add = SInt(params.WI.W)
  val tile_s = UInt(32.W)
  val tile_e = UInt(32.W)
  val tile_p = UInt(32.W)
  val tile_f = UInt(32.W)
}

// ITA Data Bundles for Streaming
class ITAInputBundle(params: ITAParams) extends Bundle {
  // inp_t: logic signed [M-1:0][WI-1:0] - input activations
  val data = Vec(params.M, SInt(params.WI.W))
}

class ITAWeightBundle(params: ITAParams) extends Bundle {
  // inp_weight_t: logic [(N*M/N_WRITE_EN)-1:0][WI-1:0] - weights
  val data = Vec(params.N * params.M / params.N_WRITE_EN, SInt(params.WI.W))
}

class ITABiasBundle(params: ITAParams) extends Bundle {
  // bias_t: logic signed [N-1:0][(WO-2)-1:0] - bias values
  val data = Vec(params.N, SInt((params.WO - 2).W))
}

class ITAOutputBundle(params: ITAParams) extends Bundle {
  // requant_oup_t: requant_t [N-1:0] - output activations
  val data = Vec(params.N, SInt(params.WI.W))
}

// ITA IO Bundle - Updated for streaming interfaces
class ITAIO(params: ITAParams) extends Bundle {
  val clk_i = Input(Clock())
  val rst_ni = Input(Reset())
  val ctrl_i = Input(new ITACtrl(params))

  // Streaming input interface
  val inp = Flipped(Decoupled(new ITAInputBundle(params)))

  // Streaming weight interface
  val inp_weight = Flipped(Decoupled(new ITAWeightBundle(params)))

  // Streaming bias interface
  val inp_bias = Flipped(Decoupled(new ITABiasBundle(params)))

  // Streaming output interface
  val oup = Decoupled(new ITAOutputBundle(params))

  val busy_o = Output(Bool())
}

// ITA BlackBox
class ITAMMIOBlackBox(params: ITAParams) extends BlackBox(
  Map(
    "ITA_N" -> IntParam(params.N),
    "ITA_M" -> IntParam(params.M),
    "ITA_S" -> IntParam(params.S),
    "ITA_P" -> IntParam(params.P),
    "ITA_E" -> IntParam(params.E),
    "ITA_H" -> IntParam(params.H),
    "ITA_OUTPUT_FIFO_DEPTH" -> IntParam(12)
  )
) with HasBlackBoxResource {
  val io = IO(new ITAIO(params))
  addResource("/vsrc/ita.sv")
  addResource("/vsrc/ita_package.sv")
}

// ITA Top IO
class ITATopIO extends Bundle {
  val ita_busy = Output(Bool())
}

trait HasITATopIO {
  def io: ITATopIO
}

// ITA TileLink Router with Streaming Interfaces
class ITATL(params: ITAParams, beatBytes: Int)(implicit p: Parameters) extends ClockSinkDomain(ClockSinkParameters())(p) {
  val device = new SimpleDevice("ita", Seq("ucbbar,ita"))
  val node = TLRegisterNode(Seq(AddressSet(params.address, 4096-1)), device, "reg/control", beatBytes=beatBytes)

  // Additional register nodes for streaming data (simplified register-based streaming)
  val dataNode = TLRegisterNode(Seq(AddressSet(params.address + 0x1000, 0xfff)), device, "reg/data", beatBytes=beatBytes)

  override lazy val module = new ITAImpl
  class ITAImpl extends Impl with HasITATopIO {
    val io = IO(new ITATopIO)
    withClockAndReset(clock, reset) {
      // Control register
      val ctrl = Reg(new ITACtrl(params))

      val status = Wire(UInt(2.W))

      // Instantiate the ITA blackbox
      val impl = Module(new ITAMMIOBlackBox(params))

      // Connect clock and reset
      impl.io.clk_i := clock
      impl.io.rst_ni := reset

      // Connect control
      impl.io.ctrl_i := ctrl

      // Block-based memory buffers for data transfer
      val inputBuffer = RegInit(VecInit(Seq.fill(params.M)(0.S(params.WI.W))))
      val weightBuffer = RegInit(VecInit(Seq.fill(params.N * params.M / params.N_WRITE_EN)(0.S(params.WI.W))))
      val biasBuffer = RegInit(VecInit(Seq.fill(params.N)(0.S((params.WO - 2).W))))
      val outputBuffer = RegInit(VecInit(Seq.fill(params.N)(0.S(params.WI.W))))

      // Block transfer control
      val inputBlockValid = RegInit(false.B)
      val weightBlockValid = RegInit(false.B)
      val biasBlockValid = RegInit(false.B)
      val outputBlockValid = RegInit(false.B)

      // Block transfer state
      val inputBlockIdx = RegInit(0.U(log2Ceil(params.M).W))
      val weightBlockIdx = RegInit(0.U(log2Ceil(params.N * params.M / params.N_WRITE_EN).W))
      val biasBlockIdx = RegInit(0.U(log2Ceil(params.N).W))

      // Block write data registers (written by software)
      val inputWriteData = Reg(SInt(params.WI.W))
      val weightWriteData = Reg(SInt(params.WI.W))
      val biasWriteData = Reg(SInt((params.WO - 2).W))

      // Block write control registers
      val inputWriteEn = RegInit(false.B)
      val weightWriteEn = RegInit(false.B)
      val biasWriteEn = RegInit(false.B)

      // Block clear control registers
      val inputBlockClear = RegInit(false.B)
      val weightBlockClear = RegInit(false.B)
      val biasBlockClear = RegInit(false.B)
      val outputBlockClear = RegInit(false.B)

      // Clear block valid flags when requested
      when(inputBlockClear) {
        inputBlockValid := false.B
        inputBlockClear := false.B
      }
      when(weightBlockClear) {
        weightBlockValid := false.B
        weightBlockClear := false.B
      }
      when(biasBlockClear) {
        biasBlockValid := false.B
        biasBlockClear := false.B
      }
      when(outputBlockClear) {
        outputBlockValid := false.B
        outputBlockClear := false.B
      }

      // Connect to ITA when all input blocks are valid
      val allInputsValid = inputBlockValid && weightBlockValid && biasBlockValid
      impl.io.inp.valid := allInputsValid
      impl.io.inp.bits.data := inputBuffer

      impl.io.inp_weight.valid := allInputsValid
      impl.io.inp_weight.bits.data := weightBuffer

      impl.io.inp_bias.valid := allInputsValid
      impl.io.inp_bias.bits.data := biasBuffer

      // Output stream: always ready to capture new output
      impl.io.oup.ready := true.B

      // Handle input processing completion
      when(impl.io.inp.ready && impl.io.inp.valid) {
        inputBlockValid := false.B
        weightBlockValid := false.B
        biasBlockValid := false.B
      }

      // Capture output when ITA produces results
      when(impl.io.oup.valid && impl.io.oup.ready) {
        outputBuffer := impl.io.oup.bits.data
        outputBlockValid := true.B
      }

      // Block write operations
      when(inputWriteEn) {
        inputBuffer(inputBlockIdx) := inputWriteData
        inputBlockIdx := inputBlockIdx + 1.U
        when(inputBlockIdx === (params.M - 1).U) {
          inputBlockValid := true.B
          inputBlockIdx := 0.U
        }
        inputWriteEn := false.B
      }

      when(weightWriteEn) {
        weightBuffer(weightBlockIdx) := weightWriteData
        weightBlockIdx := weightBlockIdx + 1.U
        when(weightBlockIdx === (params.N * params.M / params.N_WRITE_EN - 1).U) {
          weightBlockValid := true.B
          weightBlockIdx := 0.U
        }
        weightWriteEn := false.B
      }

      when(biasWriteEn) {
        biasBuffer(biasBlockIdx) := biasWriteData
        biasBlockIdx := biasBlockIdx + 1.U
        when(biasBlockIdx === (params.N - 1).U) {
          biasBlockValid := true.B
          biasBlockIdx := 0.U
        }
        biasWriteEn := false.B
      }

      // Status and busy - block-based status
      status := Cat(
        allInputsValid && impl.io.inp.ready,  // Ready to process when all inputs loaded and ITA ready
        outputBlockValid  // Output valid when block is ready
      )
      io.ita_busy := impl.io.busy_o || inputBlockValid || weightBlockValid || biasBlockValid || outputBlockValid

      // Control register mapping
      node.regmap(
        0x00 -> Seq(RegField.r(2, status)), // Status register (input_ready, output_valid)
        0x04 -> Seq(RegField.w(1, ctrl.start)), // Start control bit
        0x08 -> Seq(RegField.w(2, ctrl.layer)), // Layer type (0=Attention, 1=Feedforward, 2=Linear, 3=SingleAttention)
        0x0C -> Seq(RegField.w(2, ctrl.activation)), // Activation type (0=Identity, 1=Gelu, 2=Relu)

        // eps_mult vector (8 elements, each 8 bits)
        0x10 -> Seq(RegField.w(params.EMS, ctrl.eps_mult(0))),
        0x14 -> Seq(RegField.w(params.EMS, ctrl.eps_mult(1))),
        0x18 -> Seq(RegField.w(params.EMS, ctrl.eps_mult(2))),
        0x1C -> Seq(RegField.w(params.EMS, ctrl.eps_mult(3))),
        0x20 -> Seq(RegField.w(params.EMS, ctrl.eps_mult(4))),
        0x24 -> Seq(RegField.w(params.EMS, ctrl.eps_mult(5))),
        0x28 -> Seq(RegField.w(params.EMS, ctrl.eps_mult(6))),
        0x2C -> Seq(RegField.w(params.EMS, ctrl.eps_mult(7))),

        // right_shift vector (8 elements, each 8 bits)
        0x30 -> Seq(RegField.w(params.EMS, ctrl.right_shift(0))),
        0x34 -> Seq(RegField.w(params.EMS, ctrl.right_shift(1))),
        0x38 -> Seq(RegField.w(params.EMS, ctrl.right_shift(2))),
        0x3C -> Seq(RegField.w(params.EMS, ctrl.right_shift(3))),
        0x40 -> Seq(RegField.w(params.EMS, ctrl.right_shift(4))),
        0x44 -> Seq(RegField.w(params.EMS, ctrl.right_shift(5))),
        0x48 -> Seq(RegField.w(params.EMS, ctrl.right_shift(6))),
        0x4C -> Seq(RegField.w(params.EMS, ctrl.right_shift(7))),

        // add vector (8 elements, each 8-bit signed)
        0x50 -> Seq(RegField.w(params.WI, ctrl.add(0).asUInt)),
        0x54 -> Seq(RegField.w(params.WI, ctrl.add(1).asUInt)),
        0x58 -> Seq(RegField.w(params.WI, ctrl.add(2).asUInt)),
        0x5C -> Seq(RegField.w(params.WI, ctrl.add(3).asUInt)),
        0x60 -> Seq(RegField.w(params.WI, ctrl.add(4).asUInt)),
        0x64 -> Seq(RegField.w(params.WI, ctrl.add(5).asUInt)),
        0x68 -> Seq(RegField.w(params.WI, ctrl.add(6).asUInt)),
        0x6C -> Seq(RegField.w(params.WI, ctrl.add(7).asUInt)),

        // GELU constants (16-bit signed each)
        0x70 -> Seq(RegField.w(16, ctrl.gelu_b.asUInt)),
        0x74 -> Seq(RegField.w(16, ctrl.gelu_c.asUInt)),

        // Activation requantization parameters
        0x78 -> Seq(RegField.w(params.EMS, ctrl.activation_requant_mult)),
        0x7C -> Seq(RegField.w(params.EMS, ctrl.activation_requant_shift)),
        0x80 -> Seq(RegField.w(params.WI, ctrl.activation_requant_add.asUInt)),

        // Tile parameters (32-bit each)
        0x84 -> Seq(RegField.w(32, ctrl.tile_s)),
        0x88 -> Seq(RegField.w(32, ctrl.tile_e)),
        0x8C -> Seq(RegField.w(32, ctrl.tile_p)),
        0x90 -> Seq(RegField.w(32, ctrl.tile_f)),

        // Block transfer control
        0x94 -> Seq(RegField.w(params.WI, inputWriteData.asUInt)), // Input data write register
        0x98 -> Seq(RegField.w(1, inputWriteEn)), // Trigger input data write to buffer
        0x9C -> Seq(RegField.w(params.WI, weightWriteData.asUInt)), // Weight data write register
        0xA0 -> Seq(RegField.w(1, weightWriteEn)), // Trigger weight data write to buffer
        0xA4 -> Seq(RegField.w(params.WO - 2, biasWriteData.asUInt)), // Bias data write register
        0xA8 -> Seq(RegField.w(1, biasWriteEn)), // Trigger bias data write to buffer
        0xAC -> Seq(RegField.r(1, outputBlockValid)), // Output block valid - read to check if output is ready
        0xB0 -> Seq(RegField.w(1, outputBlockClear)) // Clear output valid - write 1 to clear after reading
      )

      // Block-based data register mapping (streaming data at 0x1000+ offset)
      // Output data registers: 0x1000 + (0 to N-1) * 4 (read-only block)
      val outputRegMap = (0 until params.N).map { i =>
        (0x00 + i * 4) -> Seq(RegField.r(params.WI, outputBuffer(i).asUInt))
      }.toSeq

      // Block status and control registers
      val blockControlMap = Seq(
        0x100 -> Seq(RegField.r(1, inputBlockValid)),   // Input block loaded status
        0x104 -> Seq(RegField.r(1, weightBlockValid)),  // Weight block loaded status
        0x108 -> Seq(RegField.r(1, biasBlockValid)),    // Bias block loaded status
        0x10C -> Seq(RegField.r(1, allInputsValid)),    // All inputs ready status
        0x110 -> Seq(RegField.w(1, inputBlockClear)),   // Clear input block valid
        0x114 -> Seq(RegField.w(1, weightBlockClear)),  // Clear weight block valid
        0x118 -> Seq(RegField.w(1, biasBlockClear))     // Clear bias block valid
      )

      // Combine all register maps
      val allDataRegMap = outputRegMap ++ blockControlMap
      dataNode.regmap(allDataRegMap: _*)
    }
  }
}

// Trait to add ITA to a subsystem
trait CanHavePeripheryITA { this: BaseSubsystem =>
  private val portName = "ita"

  private val pbus = locateTLBusWrapper(PBUS)

  val (ita_busy, ita_clock) = p(ITAKey) match {
    case Some(params) => {
      // Handle external clocking if needed
      val ita_clock = Option.when(params.externallyClocked) {
        InModuleBody { IO(Input(Clock())).suggestName("ita_clock_in") }
      }

      val itaClockNode = if (params.externallyClocked) {
        val itaSourceClockNode = ClockSourceNode(Seq(ClockSourceParameters()))
        InModuleBody {
          itaSourceClockNode.out(0)._1.clock := ita_clock.get
          itaSourceClockNode.out(0)._1.reset := ResetCatchAndSync(ita_clock.get, pbus.module.reset.asBool)
        }
        itaSourceClockNode
      } else {
        pbus.fixedClockNode
      }

      val itaCrossing = if (params.externallyClocked) {
        AsynchronousCrossing()
      } else {
        SynchronousCrossing()
      }

      // Instantiate ITA module
      val ita = LazyModule(new ITATL(params, pbus.beatBytes)(p))
      ita.clockNode := itaClockNode

      // Connect control registers
      pbus.coupleTo(portName) {
        TLInwardClockCrossingHelper("ita_ctrl_crossing", ita, ita.node)(itaCrossing) :=
        TLFragmenter(pbus.beatBytes, pbus.blockBytes) := _
      }

      // Connect data registers (for streaming data)
      pbus.coupleTo(s"${portName}_data") {
        TLInwardClockCrossingHelper("ita_data_crossing", ita, ita.dataNode)(itaCrossing) :=
        TLFragmenter(pbus.beatBytes, pbus.blockBytes) := _
      }
      
      // Expose busy signal
      val ita_busy = InModuleBody {
        val busy = IO(Output(Bool())).suggestName("ita_busy")
        busy := ita.module.io.ita_busy
        busy
      }
      
      (Some(ita_busy), ita_clock)
    }
    case None => (None, None)
  }
}

// Config fragment to enable ITA
class WithITA(
  address: BigInt = 0x5000,
  N: Int = 16,
  M: Int = 64,
  S: Int = 64,
  P: Int = 64,
  E: Int = 64,
  H: Int = 1,
  externallyClocked: Boolean = false
) extends Config((site, here, up) => {
  case ITAKey => Some(ITAParams(
    address = address,
    N = N,
    M = M,
    S = S,
    P = P,
    E = E,
    H = H,
    externallyClocked = externallyClocked
  ))
})*/
