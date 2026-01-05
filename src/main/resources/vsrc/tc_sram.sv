// Simulation stub for tc_sram (PULP common cells)
// This is a minimal implementation for Verilator simulation

module tc_sram #(
  parameter int unsigned NumWords = 1024,
  parameter int unsigned DataWidth = 32,
  parameter int unsigned ByteWidth = 8,
  parameter int unsigned NumPorts = 1,
  parameter int unsigned Latency = 1
)(
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic [NumPorts-1:0]     req_i,
  input  logic [NumPorts-1:0]     we_i,
  input  logic [NumPorts-1:0][$clog2(NumWords)-1:0] addr_i,
  input  logic [NumPorts-1:0][DataWidth-1:0] wdata_i,
  input  logic [NumPorts-1:0][DataWidth/ByteWidth-1:0] be_i,
  output logic [NumPorts-1:0][DataWidth-1:0] rdata_o
);

  // Simple memory array
  logic [DataWidth-1:0] mem [NumWords-1:0];

  // Write and read logic for each port
  genvar i;
  generate
    for (i = 0; i < NumPorts; i++) begin : gen_ports
      always_ff @(posedge clk_i) begin
        if (req_i[i] && we_i[i]) begin
          for (int j = 0; j < DataWidth/ByteWidth; j++) begin
            if (be_i[i][j]) begin
              mem[addr_i[i]][j*ByteWidth +: ByteWidth] <= wdata_i[i][j*ByteWidth +: ByteWidth];
            end
          end
        end
      end
      
      if (Latency == 0) begin
        assign rdata_o[i] = req_i[i] && !we_i[i] ? mem[addr_i[i]] : '0;
      end else begin
        logic [DataWidth-1:0] rdata_q;
        always_ff @(posedge clk_i) begin
          if (req_i[i] && !we_i[i]) begin
            rdata_q <= mem[addr_i[i]];
          end
        end
        assign rdata_o[i] = rdata_q;
      end
    end
  endgenerate

endmodule

