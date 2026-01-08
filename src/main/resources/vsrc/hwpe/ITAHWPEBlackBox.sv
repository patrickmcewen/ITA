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

  // tcdm master ports - flattened from Chisel Vec(MP, ...)
  output logic                      tcdm_req_o_0      ,
  output logic                      tcdm_req_o_1      ,
  output logic                      tcdm_req_o_2      ,
  output logic                      tcdm_req_o_3      ,
  output logic                      tcdm_req_o_4      ,
  output logic                      tcdm_req_o_5      ,
  output logic                      tcdm_req_o_6      ,
  output logic                      tcdm_req_o_7      ,
  output logic                      tcdm_req_o_8      ,
  output logic                      tcdm_req_o_9      ,
  output logic                      tcdm_req_o_10     ,
  output logic                      tcdm_req_o_11     ,
  output logic                      tcdm_req_o_12     ,
  output logic                      tcdm_req_o_13     ,
  output logic                      tcdm_req_o_14     ,
  output logic                      tcdm_req_o_15     ,
  input  logic                      tcdm_gnt_i_0      ,
  input  logic                      tcdm_gnt_i_1      ,
  input  logic                      tcdm_gnt_i_2      ,
  input  logic                      tcdm_gnt_i_3      ,
  input  logic                      tcdm_gnt_i_4      ,
  input  logic                      tcdm_gnt_i_5      ,
  input  logic                      tcdm_gnt_i_6      ,
  input  logic                      tcdm_gnt_i_7      ,
  input  logic                      tcdm_gnt_i_8      ,
  input  logic                      tcdm_gnt_i_9      ,
  input  logic                      tcdm_gnt_i_10     ,
  input  logic                      tcdm_gnt_i_11     ,
  input  logic                      tcdm_gnt_i_12     ,
  input  logic                      tcdm_gnt_i_13     ,
  input  logic                      tcdm_gnt_i_14     ,
  input  logic                      tcdm_gnt_i_15     ,
  output logic [31:0]               tcdm_add_o_0      ,
  output logic [31:0]               tcdm_add_o_1      ,
  output logic [31:0]               tcdm_add_o_2      ,
  output logic [31:0]               tcdm_add_o_3      ,
  output logic [31:0]               tcdm_add_o_4      ,
  output logic [31:0]               tcdm_add_o_5      ,
  output logic [31:0]               tcdm_add_o_6      ,
  output logic [31:0]               tcdm_add_o_7      ,
  output logic [31:0]               tcdm_add_o_8      ,
  output logic [31:0]               tcdm_add_o_9      ,
  output logic [31:0]               tcdm_add_o_10     ,
  output logic [31:0]               tcdm_add_o_11     ,
  output logic [31:0]               tcdm_add_o_12     ,
  output logic [31:0]               tcdm_add_o_13     ,
  output logic [31:0]               tcdm_add_o_14     ,
  output logic [31:0]               tcdm_add_o_15     ,
  output logic                      tcdm_wen_o_0      ,
  output logic                      tcdm_wen_o_1      ,
  output logic                      tcdm_wen_o_2      ,
  output logic                      tcdm_wen_o_3      ,
  output logic                      tcdm_wen_o_4      ,
  output logic                      tcdm_wen_o_5      ,
  output logic                      tcdm_wen_o_6      ,
  output logic                      tcdm_wen_o_7      ,
  output logic                      tcdm_wen_o_8      ,
  output logic                      tcdm_wen_o_9      ,
  output logic                      tcdm_wen_o_10     ,
  output logic                      tcdm_wen_o_11     ,
  output logic                      tcdm_wen_o_12     ,
  output logic                      tcdm_wen_o_13     ,
  output logic                      tcdm_wen_o_14     ,
  output logic                      tcdm_wen_o_15     ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_0       ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_1       ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_2       ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_3       ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_4       ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_5       ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_6       ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_7       ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_8       ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_9       ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_10      ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_11      ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_12      ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_13      ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_14      ,
  output logic [MemDataWidth/8-1:0] tcdm_be_o_15      ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_0     ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_1     ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_2     ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_3     ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_4     ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_5     ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_6     ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_7     ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_8     ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_9     ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_10    ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_11    ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_12    ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_13    ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_14    ,
  output logic [MemDataWidth-1:0]   tcdm_data_o_15    ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_0   ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_1   ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_2   ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_3   ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_4   ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_5   ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_6   ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_7   ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_8   ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_9   ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_10  ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_11  ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_12  ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_13  ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_14  ,
  input  logic [MemDataWidth-1:0]   tcdm_r_data_i_15  ,
  input  logic                      tcdm_r_valid_i_0  ,
  input  logic                      tcdm_r_valid_i_1  ,
  input  logic                      tcdm_r_valid_i_2  ,
  input  logic                      tcdm_r_valid_i_3  ,
  input  logic                      tcdm_r_valid_i_4  ,
  input  logic                      tcdm_r_valid_i_5  ,
  input  logic                      tcdm_r_valid_i_6  ,
  input  logic                      tcdm_r_valid_i_7  ,
  input  logic                      tcdm_r_valid_i_8  ,
  input  logic                      tcdm_r_valid_i_9  ,
  input  logic                      tcdm_r_valid_i_10 ,
  input  logic                      tcdm_r_valid_i_11 ,
  input  logic                      tcdm_r_valid_i_12 ,
  input  logic                      tcdm_r_valid_i_13 ,
  input  logic                      tcdm_r_valid_i_14 ,
  input  logic                      tcdm_r_valid_i_15 ,

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

  // Packed arrays for ita_hwpe_wrap
  logic [N_CORES-1:0][1:0]   evt_o_packed;
  logic [MP-1:0]             tcdm_req_o_packed;
  logic [MP-1:0]             tcdm_gnt_i_packed;
  logic [MP-1:0][31:0]       tcdm_add_o_packed;
  logic [MP-1:0]             tcdm_wen_o_packed;
  logic [MP-1:0][MemDataWidth/8-1:0] tcdm_be_o_packed;
  logic [MP-1:0][MemDataWidth-1:0]  tcdm_data_o_packed;
  logic [MP-1:0][MemDataWidth-1:0]  tcdm_r_data_i_packed;
  logic [MP-1:0]             tcdm_r_valid_i_packed;

  // Pack TCDM input signals from individual signals to arrays
  // Use direct assignments for each port (Chisel generates individual ports)
  assign tcdm_gnt_i_packed[0] = tcdm_gnt_i_0;
  assign tcdm_gnt_i_packed[1] = tcdm_gnt_i_1;
  assign tcdm_gnt_i_packed[2] = tcdm_gnt_i_2;
  assign tcdm_gnt_i_packed[3] = tcdm_gnt_i_3;
  assign tcdm_gnt_i_packed[4] = tcdm_gnt_i_4;
  assign tcdm_gnt_i_packed[5] = tcdm_gnt_i_5;
  assign tcdm_gnt_i_packed[6] = tcdm_gnt_i_6;
  assign tcdm_gnt_i_packed[7] = tcdm_gnt_i_7;
  assign tcdm_gnt_i_packed[8] = tcdm_gnt_i_8;
  assign tcdm_gnt_i_packed[9] = tcdm_gnt_i_9;
  assign tcdm_gnt_i_packed[10] = tcdm_gnt_i_10;
  assign tcdm_gnt_i_packed[11] = tcdm_gnt_i_11;
  assign tcdm_gnt_i_packed[12] = tcdm_gnt_i_12;
  assign tcdm_gnt_i_packed[13] = tcdm_gnt_i_13;
  assign tcdm_gnt_i_packed[14] = tcdm_gnt_i_14;
  assign tcdm_gnt_i_packed[15] = tcdm_gnt_i_15;

  assign tcdm_r_data_i_packed[0] = tcdm_r_data_i_0;
  assign tcdm_r_data_i_packed[1] = tcdm_r_data_i_1;
  assign tcdm_r_data_i_packed[2] = tcdm_r_data_i_2;
  assign tcdm_r_data_i_packed[3] = tcdm_r_data_i_3;
  assign tcdm_r_data_i_packed[4] = tcdm_r_data_i_4;
  assign tcdm_r_data_i_packed[5] = tcdm_r_data_i_5;
  assign tcdm_r_data_i_packed[6] = tcdm_r_data_i_6;
  assign tcdm_r_data_i_packed[7] = tcdm_r_data_i_7;
  assign tcdm_r_data_i_packed[8] = tcdm_r_data_i_8;
  assign tcdm_r_data_i_packed[9] = tcdm_r_data_i_9;
  assign tcdm_r_data_i_packed[10] = tcdm_r_data_i_10;
  assign tcdm_r_data_i_packed[11] = tcdm_r_data_i_11;
  assign tcdm_r_data_i_packed[12] = tcdm_r_data_i_12;
  assign tcdm_r_data_i_packed[13] = tcdm_r_data_i_13;
  assign tcdm_r_data_i_packed[14] = tcdm_r_data_i_14;
  assign tcdm_r_data_i_packed[15] = tcdm_r_data_i_15;

  assign tcdm_r_valid_i_packed[0] = tcdm_r_valid_i_0;
  assign tcdm_r_valid_i_packed[1] = tcdm_r_valid_i_1;
  assign tcdm_r_valid_i_packed[2] = tcdm_r_valid_i_2;
  assign tcdm_r_valid_i_packed[3] = tcdm_r_valid_i_3;
  assign tcdm_r_valid_i_packed[4] = tcdm_r_valid_i_4;
  assign tcdm_r_valid_i_packed[5] = tcdm_r_valid_i_5;
  assign tcdm_r_valid_i_packed[6] = tcdm_r_valid_i_6;
  assign tcdm_r_valid_i_packed[7] = tcdm_r_valid_i_7;
  assign tcdm_r_valid_i_packed[8] = tcdm_r_valid_i_8;
  assign tcdm_r_valid_i_packed[9] = tcdm_r_valid_i_9;
  assign tcdm_r_valid_i_packed[10] = tcdm_r_valid_i_10;
  assign tcdm_r_valid_i_packed[11] = tcdm_r_valid_i_11;
  assign tcdm_r_valid_i_packed[12] = tcdm_r_valid_i_12;
  assign tcdm_r_valid_i_packed[13] = tcdm_r_valid_i_13;
  assign tcdm_r_valid_i_packed[14] = tcdm_r_valid_i_14;
  assign tcdm_r_valid_i_packed[15] = tcdm_r_valid_i_15;

  // Unpack outputs from ita_hwpe_wrap to individual signals
  assign evt_o_0 = evt_o_packed[0];
  assign evt_o_1 = evt_o_packed[1];
  assign evt_o_2 = evt_o_packed[2];
  assign evt_o_3 = evt_o_packed[3];
  assign evt_o_4 = evt_o_packed[4];
  assign evt_o_5 = evt_o_packed[5];
  assign evt_o_6 = evt_o_packed[6];
  assign evt_o_7 = evt_o_packed[7];
  assign evt_o_8 = evt_o_packed[8];

  // Unpack TCDM outputs from arrays to individual signals
  assign tcdm_req_o_0 = tcdm_req_o_packed[0];
  assign tcdm_req_o_1 = tcdm_req_o_packed[1];
  assign tcdm_req_o_2 = tcdm_req_o_packed[2];
  assign tcdm_req_o_3 = tcdm_req_o_packed[3];
  assign tcdm_req_o_4 = tcdm_req_o_packed[4];
  assign tcdm_req_o_5 = tcdm_req_o_packed[5];
  assign tcdm_req_o_6 = tcdm_req_o_packed[6];
  assign tcdm_req_o_7 = tcdm_req_o_packed[7];
  assign tcdm_req_o_8 = tcdm_req_o_packed[8];
  assign tcdm_req_o_9 = tcdm_req_o_packed[9];
  assign tcdm_req_o_10 = tcdm_req_o_packed[10];
  assign tcdm_req_o_11 = tcdm_req_o_packed[11];
  assign tcdm_req_o_12 = tcdm_req_o_packed[12];
  assign tcdm_req_o_13 = tcdm_req_o_packed[13];
  assign tcdm_req_o_14 = tcdm_req_o_packed[14];
  assign tcdm_req_o_15 = tcdm_req_o_packed[15];

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

  assign tcdm_wen_o_0 = tcdm_wen_o_packed[0];
  assign tcdm_wen_o_1 = tcdm_wen_o_packed[1];
  assign tcdm_wen_o_2 = tcdm_wen_o_packed[2];
  assign tcdm_wen_o_3 = tcdm_wen_o_packed[3];
  assign tcdm_wen_o_4 = tcdm_wen_o_packed[4];
  assign tcdm_wen_o_5 = tcdm_wen_o_packed[5];
  assign tcdm_wen_o_6 = tcdm_wen_o_packed[6];
  assign tcdm_wen_o_7 = tcdm_wen_o_packed[7];
  assign tcdm_wen_o_8 = tcdm_wen_o_packed[8];
  assign tcdm_wen_o_9 = tcdm_wen_o_packed[9];
  assign tcdm_wen_o_10 = tcdm_wen_o_packed[10];
  assign tcdm_wen_o_11 = tcdm_wen_o_packed[11];
  assign tcdm_wen_o_12 = tcdm_wen_o_packed[12];
  assign tcdm_wen_o_13 = tcdm_wen_o_packed[13];
  assign tcdm_wen_o_14 = tcdm_wen_o_packed[14];
  assign tcdm_wen_o_15 = tcdm_wen_o_packed[15];

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

