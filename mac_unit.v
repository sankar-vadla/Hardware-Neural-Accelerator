`timescale 1ns / 1ps


module mac_unit (
    clk,
    rst_n,
    en,
    a,
    b,
    c_in,
    c_out
);

    // --- Parameters ---
    parameter A_WIDTH = 8;
    parameter B_WIDTH = 8;
    parameter ACCUM_WIDTH = 24;

    // --- Port Declarations ---
    input                           clk;
    input                           rst_n;
    input                           en;
    input      signed [A_WIDTH-1:0] a;
    input      signed [B_WIDTH-1:0] b;
    input      signed [ACCUM_WIDTH-1:0] c_in;
    output     signed [ACCUM_WIDTH-1:0] c_out;

    // --- Internal Registers ---
    
    // Stage 1 Registers
    reg signed [A_WIDTH+B_WIDTH-1:0] mult_reg; // Correct width
    reg signed [ACCUM_WIDTH-1:0]     cin_reg;
    
    // Stage 2 Register
    reg signed [ACCUM_WIDTH-1:0]     add_reg;

    // --- Pipelined Logic ---
    always @(posedge clk) begin
        if (!rst_n) begin
            mult_reg <= 0;
            cin_reg  <= 0;
            add_reg  <= 0;
        end 
        else if (en) begin
            // Pipeline Stage 1:
            mult_reg <= a * b;
            cin_reg  <= c_in;
            
            // Pipeline Stage 2:
            add_reg  <= mult_reg + cin_reg;
        end
    end

    // Assign the final output from the last pipeline stage
    assign c_out = add_reg;

endmodule