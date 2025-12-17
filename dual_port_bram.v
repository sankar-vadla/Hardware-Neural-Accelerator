`timescale 1ns / 1ps


// This is a generic true dual-port Block RAM.
// - Port A is a Write Port (for the testbench to load data)
// - Port B is a Read Port (for the FSM to read data)
//
// It has a 1-cycle read latency on Port B.
// (You give an address on 'b_addr', you get data
//  on 'b_dout' on the *next* clock cycle).
//
module dual_port_bram (
    clk,
    
    // Port A (Write Port)
    a_wen,    // Write Enable
    a_addr,   // Write Address
    a_din,    // Data In
    
    // Port B (Read Port)
    b_en,     // Read Enable
    b_addr,   // Read Address
    b_dout    // Data Out
);

    // --- Parameters ---
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 6; // 2^6 = 64 locations
    
    // --- Port Declarations ---
    input                           clk;
    
    // Port A
    input                           a_wen;
    input      [ADDR_WIDTH-1:0]     a_addr;
    input      [DATA_WIDTH-1:0]     a_din;
    
    // Port B
    input                           b_en;
    input      [ADDR_WIDTH-1:0]     b_addr;
    output reg [DATA_WIDTH-1:0]     b_dout; // Registered output
    
    // --- Core BRAM Memory Array ---
    reg [DATA_WIDTH-1:0] ram_core [0:(1<<ADDR_WIDTH)-1];

    // --- Port A Write Logic ---
    always @(posedge clk) begin
        if (a_wen) begin
            ram_core[a_addr] <= a_din;
        end
    end

    // --- Port B Read Logic (Pipelined) ---
    always @(posedge clk) begin
        if (b_en) begin
            b_dout <= ram_core[b_addr];
        end
    end

endmodule