// Simulation stub for cluster_clock_gating (PULP common cells)
// This is a minimal implementation for Verilator simulation
// In simulation, clock gating is typically bypassed

module cluster_clock_gating (
  output logic clk_o,
  input  logic en_i,
  input  logic test_en_i,
  input  logic clk_i
);

  // For simulation, just pass through the clock when enabled
  // In real hardware, this would gate the clock
  assign clk_o = (en_i || test_en_i) ? clk_i : 1'b0;

endmodule

