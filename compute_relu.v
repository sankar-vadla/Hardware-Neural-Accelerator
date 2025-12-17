`timescale 1ns / 1ps


module compute_relu (
    din,
    dout
);

    // --- Parameters ---
    parameter DATA_WIDTH = 24; // Input from accumulator

    // --- Ports ---
    input  signed [DATA_WIDTH-1:0] din;
    output signed [DATA_WIDTH-1:0] dout;

    // --- Logic ---
    // If the sign bit (Most Significant Bit) is 1, it's negative.
    assign dout = (din[DATA_WIDTH-1] == 1'b1) ? 0 : din;

endmodule