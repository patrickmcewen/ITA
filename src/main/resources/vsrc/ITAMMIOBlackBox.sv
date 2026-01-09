// Wrapper for ITA module - accepts packed UInt signals from Chisel and unpacks them for the ita module
// The Chisel ITAWrapper packs Vecs/Bundles into UInts to avoid flattening issues
// The ita module uses ifdef directives from ita_package, so no parameters needed here

`include "ita_package.sv"

module ITAMMIOBlackBox (
  input  logic clk_i,
  input  logic rst_ni,
  
  // Packed control signal (as UInt from Chisel)
  input  logic [((1 + 2 + 2 + N_REQUANT_CONSTS * EMS * 2 + 
                 N_REQUANT_CONSTS * WI + 16 * 2 + 
                 EMS * 2 + WI + 32 * 4)-1):0] ctrl_i,
  
  // Handshake signals
  input  logic inp_valid_i,
  output logic inp_ready_o,
  input  logic inp_weight_valid_i,
  output logic inp_weight_ready_o,
  input  logic inp_bias_valid_i,
  output logic inp_bias_ready_o,
  output logic valid_o,
  input  logic ready_i,
  output logic busy_o,
  
  // Packed input vectors (as UInt from Chisel)
  input  logic [((M*WI)-1):0] inp_i,
  input  logic [((N*M/N_WRITE_EN*WI)-1):0] inp_weight_i,
  input  logic [((N*(WO-2))-1):0] inp_bias_i,
  
  // Packed output vector
  output logic [((N*WI)-1):0] oup_o
);

  import ita_package::*;
  
  // Unpack control struct from UInt (matches Chisel packing order)
  // Order: start, layer, activation, eps_mult[0..7], right_shift[0..7], add[0..7],
  //        gelu_b, gelu_c, activation_requant_mult, activation_requant_shift,
  //        activation_requant_add, tile_s, tile_e, tile_p, tile_f
  ctrl_t ctrl_unpacked;
  
  // Use direct assignment with calculated offsets
  localparam int EPS_MULT_BITS = N_REQUANT_CONSTS * EMS;
  localparam int RIGHT_SHIFT_BITS = N_REQUANT_CONSTS * EMS;
  localparam int ADD_BITS = N_REQUANT_CONSTS * WI;
  
  assign ctrl_unpacked.start = ctrl_i[0];
  assign ctrl_unpacked.layer = layer_e'(ctrl_i[1 +: 2]);
  assign ctrl_unpacked.activation = activation_e'(ctrl_i[3 +: 2]);
  
  // eps_mult array (reverse order as packed by Chisel)
  genvar j;
  generate
    for (j = 0; j < N_REQUANT_CONSTS; j++) begin
      assign ctrl_unpacked.eps_mult[j] = ctrl_i[5 + (N_REQUANT_CONSTS - 1 - j) * EMS +: EMS];
    end
    // right_shift array
    for (j = 0; j < N_REQUANT_CONSTS; j++) begin
      assign ctrl_unpacked.right_shift[j] = ctrl_i[5 + EPS_MULT_BITS + (N_REQUANT_CONSTS - 1 - j) * EMS +: EMS];
    end
    // add array
    for (j = 0; j < N_REQUANT_CONSTS; j++) begin
      assign ctrl_unpacked.add[j] = $signed(ctrl_i[5 + EPS_MULT_BITS + RIGHT_SHIFT_BITS + (N_REQUANT_CONSTS - 1 - j) * WI +: WI]);
    end
  endgenerate
  
  localparam int BASE = 5 + EPS_MULT_BITS + RIGHT_SHIFT_BITS + ADD_BITS;
  assign ctrl_unpacked.gelu_b = $signed(ctrl_i[BASE +: 16]);
  assign ctrl_unpacked.gelu_c = $signed(ctrl_i[BASE + 16 +: 16]);
  assign ctrl_unpacked.activation_requant_mult = ctrl_i[BASE + 32 +: EMS];
  assign ctrl_unpacked.activation_requant_shift = ctrl_i[BASE + 32 + EMS +: EMS];
  assign ctrl_unpacked.activation_requant_add = $signed(ctrl_i[BASE + 32 + EMS * 2 +: WI]);
  assign ctrl_unpacked.tile_s = ctrl_i[BASE + 32 + EMS * 2 + WI +: 32];
  assign ctrl_unpacked.tile_e = ctrl_i[BASE + 32 + EMS * 2 + WI + 32 +: 32];
  assign ctrl_unpacked.tile_p = ctrl_i[BASE + 32 + EMS * 2 + WI + 64 +: 32];
  assign ctrl_unpacked.tile_f = ctrl_i[BASE + 32 + EMS * 2 + WI + 96 +: 32];
  
  // Unpack input/output vectors from UInt
  inp_t inp_unpacked;
  inp_weight_t inp_weight_unpacked;
  bias_t inp_bias_unpacked;
  requant_oup_t oup_unpacked;
  
  genvar i;
  generate
    // Unpack inp_i from UInt
    for (i = 0; i < M; i = i + 1) begin : gen_inp
      assign inp_unpacked[i] = $signed(inp_i[i*WI +: WI]);
    end
    
    // Unpack inp_weight_i
    for (i = 0; i < (N*M/N_WRITE_EN); i = i + 1) begin : gen_weight
      assign inp_weight_unpacked[i] = $signed(inp_weight_i[i*WI +: WI]);
    end
    
    // Unpack inp_bias_i
    for (i = 0; i < N; i = i + 1) begin : gen_bias
      assign inp_bias_unpacked[i] = $signed(inp_bias_i[i*(WO-2) +: (WO-2)]);
    end
    
    // Pack oup_o to UInt
    for (i = 0; i < N; i = i + 1) begin : gen_oup
      assign oup_o[i*WI +: WI] = oup_unpacked[i];
    end
  endgenerate
  
  // Instantiate actual ita module (no parameters - uses package ifdef values)
  ita ita_inst (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .ctrl_i(ctrl_unpacked),
    .inp_valid_i(inp_valid_i),
    .inp_ready_o(inp_ready_o),
    .inp_weight_valid_i(inp_weight_valid_i),
    .inp_weight_ready_o(inp_weight_ready_o),
    .inp_bias_valid_i(inp_bias_valid_i),
    .inp_bias_ready_o(inp_bias_ready_o),
    .valid_o(valid_o),
    .ready_i(ready_i),
    .busy_o(busy_o),
    .inp_i(inp_unpacked),
    .inp_weight_i(inp_weight_unpacked),
    .inp_bias_i(inp_bias_unpacked),
    .oup_o(oup_unpacked)
  );

endmodule

