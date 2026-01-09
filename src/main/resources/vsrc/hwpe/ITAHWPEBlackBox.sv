// Wrapper for ita_hwpe_wrap module - converts between Chisel flattened signals and SystemVerilog packed arrays
// Chisel flattens Vec signals into individual ports (e.g., tcdm_req_o_0, tcdm_req_o_1, ...)
// ita_hwpe_wrap expects packed arrays (e.g., logic [MP-1:0] tcdm_req_o)
// This wrapper packs/unpacks the signals appropriately

`include "hci_helpers.svh"

import ita_hwpe_package::*;
import hwpe_ctrl_package::*;
import hwpe_stream_package::*;
import hci_package::*;

module ITAHWPEBlackBox
#(
  // hwpe params
  parameter int unsigned AccDataWidth = 1024,
  parameter int unsigned IdWidth      = ID_WIDTH,
  // system params
  parameter int unsigned MemDataWidth = 64,
  parameter int unsigned MP           = (AccDataWidth / MemDataWidth),
  parameter int unsigned N_CORES      = 9
) (
  // global signals
  input  logic                      clk_i         ,
  input  logic                      rst_ni        ,
  input  logic                      test_mode_i   ,

  // events - flattened from Chisel Vec(N_CORES, UInt(2.W))
  output logic [1:0]                evt_o_0       ,
  output logic [1:0]                evt_o_1       ,
  output logic [1:0]                evt_o_2       ,
  output logic [1:0]                evt_o_3       ,
  output logic [1:0]                evt_o_4       ,
  output logic [1:0]                evt_o_5       ,
  output logic [1:0]                evt_o_6       ,
  output logic [1:0]                evt_o_7       ,
  output logic [1:0]                evt_o_8       ,
  output logic                      busy_o        ,

  // tcdm master ports - matching Chisel generated interface
  // UInt types generate packed arrays, Vec types generate flattened ports
  output logic [      MP-1:0]                     tcdm_req_o      ,  // UInt -> packed array
  input  logic [      MP-1:0]                     tcdm_gnt_i      ,  // UInt -> packed array
  output logic [31:0]               tcdm_add_o_0, tcdm_add_o_1, tcdm_add_o_2, tcdm_add_o_3, tcdm_add_o_4, tcdm_add_o_5, tcdm_add_o_6, tcdm_add_o_7, tcdm_add_o_8, tcdm_add_o_9, tcdm_add_o_10, tcdm_add_o_11, tcdm_add_o_12, tcdm_add_o_13, tcdm_add_o_14, tcdm_add_o_15, tcdm_add_o_16, tcdm_add_o_17, tcdm_add_o_18, tcdm_add_o_19, tcdm_add_o_20, tcdm_add_o_21, tcdm_add_o_22, tcdm_add_o_23, tcdm_add_o_24, tcdm_add_o_25, tcdm_add_o_26, tcdm_add_o_27, tcdm_add_o_28, tcdm_add_o_29, tcdm_add_o_30, tcdm_add_o_31,  // Vec -> flattened
  output logic [      MP-1:0]                     tcdm_wen_o      ,  // UInt -> packed array
  output logic [MemDataWidth/8-1:0] tcdm_be_o_0, tcdm_be_o_1, tcdm_be_o_2, tcdm_be_o_3, tcdm_be_o_4, tcdm_be_o_5, tcdm_be_o_6, tcdm_be_o_7, tcdm_be_o_8, tcdm_be_o_9, tcdm_be_o_10, tcdm_be_o_11, tcdm_be_o_12, tcdm_be_o_13, tcdm_be_o_14, tcdm_be_o_15, tcdm_be_o_16, tcdm_be_o_17, tcdm_be_o_18, tcdm_be_o_19, tcdm_be_o_20, tcdm_be_o_21, tcdm_be_o_22, tcdm_be_o_23, tcdm_be_o_24, tcdm_be_o_25, tcdm_be_o_26, tcdm_be_o_27, tcdm_be_o_28, tcdm_be_o_29, tcdm_be_o_30, tcdm_be_o_31,  // Vec -> flattened
  output logic [MemDataWidth-1:0]   tcdm_data_o_0, tcdm_data_o_1, tcdm_data_o_2, tcdm_data_o_3, tcdm_data_o_4, tcdm_data_o_5, tcdm_data_o_6, tcdm_data_o_7, tcdm_data_o_8, tcdm_data_o_9, tcdm_data_o_10, tcdm_data_o_11, tcdm_data_o_12, tcdm_data_o_13, tcdm_data_o_14, tcdm_data_o_15, tcdm_data_o_16, tcdm_data_o_17, tcdm_data_o_18, tcdm_data_o_19, tcdm_data_o_20, tcdm_data_o_21, tcdm_data_o_22, tcdm_data_o_23, tcdm_data_o_24, tcdm_data_o_25, tcdm_data_o_26, tcdm_data_o_27, tcdm_data_o_28, tcdm_data_o_29, tcdm_data_o_30, tcdm_data_o_31,  // Vec -> flattened
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_0, tcdm_r_data_i_1, tcdm_r_data_i_2, tcdm_r_data_i_3, tcdm_r_data_i_4, tcdm_r_data_i_5, tcdm_r_data_i_6, tcdm_r_data_i_7, tcdm_r_data_i_8, tcdm_r_data_i_9, tcdm_r_data_i_10, tcdm_r_data_i_11, tcdm_r_data_i_12, tcdm_r_data_i_13, tcdm_r_data_i_14, tcdm_r_data_i_15, tcdm_r_data_i_16, tcdm_r_data_i_17, tcdm_r_data_i_18, tcdm_r_data_i_19, tcdm_r_data_i_20, tcdm_r_data_i_21, tcdm_r_data_i_22, tcdm_r_data_i_23, tcdm_r_data_i_24, tcdm_r_data_i_25, tcdm_r_data_i_26, tcdm_r_data_i_27, tcdm_r_data_i_28, tcdm_r_data_i_29, tcdm_r_data_i_30, tcdm_r_data_i_31,  // Vec -> flattened
  input  logic [      MP-1:0]                     tcdm_r_valid_i  ,  // UInt -> packed array

  // periph slave port
  input  logic                      periph_req_i    ,
  output logic                      periph_gnt_o    ,
  input  logic [        31:0]       periph_add_i    ,
  input  logic                      periph_wen_i    ,
  input  logic [         3:0]       periph_be_i     ,
  input  logic [        31:0]       periph_data_i   ,
  input  logic [ IdWidth-1:0]       periph_id_i     ,
  output logic [        31:0]       periph_r_data_o ,
  output logic                      periph_r_valid_o,
  output logic [ IdWidth-1:0]       periph_r_id_o
);

  // Packed arrays for ita_hwpe_wrap - matching ita_hwpe_wrap.sv interface
  logic [N_CORES-1:0][1:0]   evt_o_packed;
  logic [MP-1:0]             tcdm_req_o_packed;
  logic [MP-1:0]             tcdm_gnt_i_packed;
  logic [MP-1:0][31:0]       tcdm_add_o_packed;
  logic [MP-1:0]             tcdm_wen_o_packed;
  logic [MP-1:0][MemDataWidth/8-1:0] tcdm_be_o_packed;
  logic [MP-1:0][MemDataWidth-1:0]  tcdm_data_o_packed;
  logic [MP-1:0][MemDataWidth-1:0]  tcdm_r_data_i_packed;
  logic [MP-1:0]             tcdm_r_valid_i_packed;

  // Pack/unpack signals between Chisel interface and ita_hwpe_wrap
  // Packed arrays (UInt types) - direct connection
  // Outputs: ita_hwpe_wrap drives packed arrays, assign to Chisel output ports
  assign tcdm_req_o = tcdm_req_o_packed;        // Output: from ita_hwpe_wrap to Chisel
  assign tcdm_wen_o = tcdm_wen_o_packed;        // Output: from ita_hwpe_wrap to Chisel
  // Inputs: Chisel drives input ports, assign to packed arrays for ita_hwpe_wrap
  assign tcdm_gnt_i_packed = tcdm_gnt_i;        // Input: from Chisel to ita_hwpe_wrap
  assign tcdm_r_valid_i_packed = tcdm_r_valid_i; // Input: from Chisel to ita_hwpe_wrap

  // Flattened INPUT signals (Vec types) - pack into arrays
  // Note: OUTPUT signals (tcdm_add_o, tcdm_be_o, tcdm_data_o) are driven by ita_hwpe_wrap
  // and unpacked below, so they should NOT be packed here
  genvar i;
  generate
    for (i = 0; i < MP; i++) begin : gen_tcdm_pack
      assign tcdm_r_data_i_packed[i] = (i == 0) ? tcdm_r_data_i_0 :
                                        (i == 1) ? tcdm_r_data_i_1 :
                                        (i == 2) ? tcdm_r_data_i_2 :
                                        (i == 3) ? tcdm_r_data_i_3 :
                                        (i == 4) ? tcdm_r_data_i_4 :
                                        (i == 5) ? tcdm_r_data_i_5 :
                                        (i == 6) ? tcdm_r_data_i_6 :
                                        (i == 7) ? tcdm_r_data_i_7 :
                                        (i == 8) ? tcdm_r_data_i_8 :
                                        (i == 9) ? tcdm_r_data_i_9 :
                                        (i == 10) ? tcdm_r_data_i_10 :
                                        (i == 11) ? tcdm_r_data_i_11 :
                                        (i == 12) ? tcdm_r_data_i_12 :
                                        (i == 13) ? tcdm_r_data_i_13 :
                                        (i == 14) ? tcdm_r_data_i_14 :
                                        (i == 15) ? tcdm_r_data_i_15 :
                                        (i == 16) ? tcdm_r_data_i_16 :
                                        (i == 17) ? tcdm_r_data_i_17 :
                                        (i == 18) ? tcdm_r_data_i_18 :
                                        (i == 19) ? tcdm_r_data_i_19 :
                                        (i == 20) ? tcdm_r_data_i_20 :
                                        (i == 21) ? tcdm_r_data_i_21 :
                                        (i == 22) ? tcdm_r_data_i_22 :
                                        (i == 23) ? tcdm_r_data_i_23 :
                                        (i == 24) ? tcdm_r_data_i_24 :
                                        (i == 25) ? tcdm_r_data_i_25 :
                                        (i == 26) ? tcdm_r_data_i_26 :
                                        (i == 27) ? tcdm_r_data_i_27 :
                                        (i == 28) ? tcdm_r_data_i_28 :
                                        (i == 29) ? tcdm_r_data_i_29 :
                                        (i == 30) ? tcdm_r_data_i_30 :
                                        tcdm_r_data_i_31;
    end
  endgenerate

  // Unpack outputs from ita_hwpe_wrap to flattened ports (direct assignments)
  assign tcdm_add_o_0 = tcdm_add_o_packed[0];
  assign tcdm_add_o_1 = tcdm_add_o_packed[1];
  assign tcdm_add_o_2 = tcdm_add_o_packed[2];
  assign tcdm_add_o_3 = tcdm_add_o_packed[3];
  assign tcdm_add_o_4 = tcdm_add_o_packed[4];
  assign tcdm_add_o_5 = tcdm_add_o_packed[5];
  assign tcdm_add_o_6 = tcdm_add_o_packed[6];
  assign tcdm_add_o_7 = tcdm_add_o_packed[7];
  assign tcdm_add_o_8 = tcdm_add_o_packed[8];
  assign tcdm_add_o_9 = tcdm_add_o_packed[9];
  assign tcdm_add_o_10 = tcdm_add_o_packed[10];
  assign tcdm_add_o_11 = tcdm_add_o_packed[11];
  assign tcdm_add_o_12 = tcdm_add_o_packed[12];
  assign tcdm_add_o_13 = tcdm_add_o_packed[13];
  assign tcdm_add_o_14 = tcdm_add_o_packed[14];
  assign tcdm_add_o_15 = tcdm_add_o_packed[15];
  assign tcdm_add_o_16 = tcdm_add_o_packed[16];
  assign tcdm_add_o_17 = tcdm_add_o_packed[17];
  assign tcdm_add_o_18 = tcdm_add_o_packed[18];
  assign tcdm_add_o_19 = tcdm_add_o_packed[19];
  assign tcdm_add_o_20 = tcdm_add_o_packed[20];
  assign tcdm_add_o_21 = tcdm_add_o_packed[21];
  assign tcdm_add_o_22 = tcdm_add_o_packed[22];
  assign tcdm_add_o_23 = tcdm_add_o_packed[23];
  assign tcdm_add_o_24 = tcdm_add_o_packed[24];
  assign tcdm_add_o_25 = tcdm_add_o_packed[25];
  assign tcdm_add_o_26 = tcdm_add_o_packed[26];
  assign tcdm_add_o_27 = tcdm_add_o_packed[27];
  assign tcdm_add_o_28 = tcdm_add_o_packed[28];
  assign tcdm_add_o_29 = tcdm_add_o_packed[29];
  assign tcdm_add_o_30 = tcdm_add_o_packed[30];
  assign tcdm_add_o_31 = tcdm_add_o_packed[31];
  assign tcdm_be_o_0 = tcdm_be_o_packed[0];
  assign tcdm_be_o_1 = tcdm_be_o_packed[1];
  assign tcdm_be_o_2 = tcdm_be_o_packed[2];
  assign tcdm_be_o_3 = tcdm_be_o_packed[3];
  assign tcdm_be_o_4 = tcdm_be_o_packed[4];
  assign tcdm_be_o_5 = tcdm_be_o_packed[5];
  assign tcdm_be_o_6 = tcdm_be_o_packed[6];
  assign tcdm_be_o_7 = tcdm_be_o_packed[7];
  assign tcdm_be_o_8 = tcdm_be_o_packed[8];
  assign tcdm_be_o_9 = tcdm_be_o_packed[9];
  assign tcdm_be_o_10 = tcdm_be_o_packed[10];
  assign tcdm_be_o_11 = tcdm_be_o_packed[11];
  assign tcdm_be_o_12 = tcdm_be_o_packed[12];
  assign tcdm_be_o_13 = tcdm_be_o_packed[13];
  assign tcdm_be_o_14 = tcdm_be_o_packed[14];
  assign tcdm_be_o_15 = tcdm_be_o_packed[15];
  assign tcdm_be_o_16 = tcdm_be_o_packed[16];
  assign tcdm_be_o_17 = tcdm_be_o_packed[17];
  assign tcdm_be_o_18 = tcdm_be_o_packed[18];
  assign tcdm_be_o_19 = tcdm_be_o_packed[19];
  assign tcdm_be_o_20 = tcdm_be_o_packed[20];
  assign tcdm_be_o_21 = tcdm_be_o_packed[21];
  assign tcdm_be_o_22 = tcdm_be_o_packed[22];
  assign tcdm_be_o_23 = tcdm_be_o_packed[23];
  assign tcdm_be_o_24 = tcdm_be_o_packed[24];
  assign tcdm_be_o_25 = tcdm_be_o_packed[25];
  assign tcdm_be_o_26 = tcdm_be_o_packed[26];
  assign tcdm_be_o_27 = tcdm_be_o_packed[27];
  assign tcdm_be_o_28 = tcdm_be_o_packed[28];
  assign tcdm_be_o_29 = tcdm_be_o_packed[29];
  assign tcdm_be_o_30 = tcdm_be_o_packed[30];
  assign tcdm_be_o_31 = tcdm_be_o_packed[31];
  assign tcdm_data_o_0 = tcdm_data_o_packed[0];
  assign tcdm_data_o_1 = tcdm_data_o_packed[1];
  assign tcdm_data_o_2 = tcdm_data_o_packed[2];
  assign tcdm_data_o_3 = tcdm_data_o_packed[3];
  assign tcdm_data_o_4 = tcdm_data_o_packed[4];
  assign tcdm_data_o_5 = tcdm_data_o_packed[5];
  assign tcdm_data_o_6 = tcdm_data_o_packed[6];
  assign tcdm_data_o_7 = tcdm_data_o_packed[7];
  assign tcdm_data_o_8 = tcdm_data_o_packed[8];
  assign tcdm_data_o_9 = tcdm_data_o_packed[9];
  assign tcdm_data_o_10 = tcdm_data_o_packed[10];
  assign tcdm_data_o_11 = tcdm_data_o_packed[11];
  assign tcdm_data_o_12 = tcdm_data_o_packed[12];
  assign tcdm_data_o_13 = tcdm_data_o_packed[13];
  assign tcdm_data_o_14 = tcdm_data_o_packed[14];
  assign tcdm_data_o_15 = tcdm_data_o_packed[15];
  assign tcdm_data_o_16 = tcdm_data_o_packed[16];
  assign tcdm_data_o_17 = tcdm_data_o_packed[17];
  assign tcdm_data_o_18 = tcdm_data_o_packed[18];
  assign tcdm_data_o_19 = tcdm_data_o_packed[19];
  assign tcdm_data_o_20 = tcdm_data_o_packed[20];
  assign tcdm_data_o_21 = tcdm_data_o_packed[21];
  assign tcdm_data_o_22 = tcdm_data_o_packed[22];
  assign tcdm_data_o_23 = tcdm_data_o_packed[23];
  assign tcdm_data_o_24 = tcdm_data_o_packed[24];
  assign tcdm_data_o_25 = tcdm_data_o_packed[25];
  assign tcdm_data_o_26 = tcdm_data_o_packed[26];
  assign tcdm_data_o_27 = tcdm_data_o_packed[27];
  assign tcdm_data_o_28 = tcdm_data_o_packed[28];
  assign tcdm_data_o_29 = tcdm_data_o_packed[29];
  assign tcdm_data_o_30 = tcdm_data_o_packed[30];
  assign tcdm_data_o_31 = tcdm_data_o_packed[31];

  // Unpack events
  assign evt_o_0 = evt_o_packed[0];
  assign evt_o_1 = evt_o_packed[1];
  assign evt_o_2 = evt_o_packed[2];
  assign evt_o_3 = evt_o_packed[3];
  assign evt_o_4 = evt_o_packed[4];
  assign evt_o_5 = evt_o_packed[5];
  assign evt_o_6 = evt_o_packed[6];
  assign evt_o_7 = evt_o_packed[7];
  assign evt_o_8 = evt_o_packed[8];

  // Instantiate actual ita_hwpe_wrap module
  ita_hwpe_wrap #(
    .AccDataWidth(AccDataWidth),
    .IdWidth(IdWidth),
    .MemDataWidth(MemDataWidth),
    .MP(MP)
  ) ita_hwpe_wrap_inst (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .test_mode_i(test_mode_i),
    .evt_o(evt_o_packed),
    .busy_o(busy_o),
    .tcdm_req_o(tcdm_req_o_packed),
    .tcdm_gnt_i(tcdm_gnt_i_packed),
    .tcdm_add_o(tcdm_add_o_packed),
    .tcdm_wen_o(tcdm_wen_o_packed),
    .tcdm_be_o(tcdm_be_o_packed),
    .tcdm_data_o(tcdm_data_o_packed),
    .tcdm_r_data_i(tcdm_r_data_i_packed),
    .tcdm_r_valid_i(tcdm_r_valid_i_packed),
    .periph_req_i(periph_req_i),
    .periph_gnt_o(periph_gnt_o),
    .periph_add_i(periph_add_i),
    .periph_wen_i(periph_wen_i),
    .periph_be_i(periph_be_i),
    .periph_data_i(periph_data_i),
    .periph_id_i(periph_id_i),
    .periph_r_data_o(periph_r_data_o),
    .periph_r_valid_o(periph_r_valid_o),
    .periph_r_id_o(periph_r_id_o)
  );

endmodule : ITAHWPEBlackBox

