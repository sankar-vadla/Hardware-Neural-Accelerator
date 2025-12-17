`timescale 1ns / 1ps

//
// Module: cnn_top_tb_comprehensive.v (Verilog-2001 Standard)
//
// This testbench runs THREE test cases sequentially
// to cover all expected output classes (0, 1, 2).
// It achieves this by loading different DENSE WEIGHTS
// for each test case.
//
module cnn_top_tb_comprehensive;

    // --- Parameters ---
    parameter CLK_PERIOD = 5;
    parameter CONV_DATA_W = 8;
    parameter CONV_ADDR_W = 4;
    parameter CONV_ACCUM_W = 24;
    
    parameter DENSE_DATA_W = 24;
    parameter DENSE_WEIGHT_W = 8;
    parameter DENSE_ADDR_W = 5;
    
    parameter INPUT_FEATURES = 6;
    parameter OUTPUT_CLASSES = 3;

    // --- Testbench Signals ---
    reg clk;
    reg rst_n;
    reg start;
    wire done;
    wire [1:0] final_class_out;
    
    // BRAM Wires
    reg  data_bram_wen;
    reg [CONV_ADDR_W-1:0] data_bram_addr;
    reg [CONV_DATA_W-1:0] data_bram_din;
    
    reg  weight_bram_wen;
    reg [CONV_ADDR_W-1:0] weight_bram_addr;
    reg [CONV_DATA_W-1:0] weight_bram_din;
    
    reg  feature_bram_wen; // Not used by TB, controlled by cnn_top
    reg [DENSE_ADDR_W-1:0] feature_bram_addr; // Not used by TB
    reg [DENSE_DATA_W-1:0] feature_bram_din; // Not used by TB
    
    reg  dense_w_bram_wen;
    reg [DENSE_ADDR_W-1:0] dense_w_bram_addr;
    reg [DENSE_WEIGHT_W-1:0] dense_w_bram_din;

    // --- Instantiate the Design Under Test (DUT) ---
    cnn_top DUT (
        .clk(clk), .rst_n(rst_n), .start(start), .done(done),
        .data_bram_wen(data_bram_wen), .data_bram_addr(data_bram_addr), .data_bram_din(data_bram_din),
        .weight_bram_wen(weight_bram_wen), .weight_bram_addr(weight_bram_addr), .weight_bram_din(weight_bram_din),
        // Pass through feature BRAM ports (unused by TB)
        .feature_bram_wen(feature_bram_wen), .feature_bram_addr(feature_bram_addr), .feature_bram_din(feature_bram_din),
        // Dense Weight BRAM ports
        .dense_w_bram_wen(dense_w_bram_wen), .dense_w_bram_addr(dense_w_bram_addr), .dense_w_bram_din(dense_w_bram_din),
        .final_class_out(final_class_out)
    );

    // --- Clock Generator ---
    always begin
        clk = 1'b0; #(CLK_PERIOD / 2);
        clk = 1'b1; #(CLK_PERIOD / 2);
    end
    
    // --- Helper Tasks ---
    integer i; // Loop variable

    // Task to load Conv1D BRAMs (using simple data [1,1,...])
    task load_conv_brams;
    begin
        $display("T=%0t: Loading Conv1D BRAMs (Data=[1,1,...], Weights=[1,2,1])...", $time);
        data_bram_wen = 1'b1;
        for (i = 0; i < 8; i = i + 1) begin
            data_bram_addr = i; data_bram_din = 1; #(CLK_PERIOD); // All inputs are '1'
        end
        data_bram_wen = 1'b0;
        
        weight_bram_wen = 1'b1;
        weight_bram_addr = 0; weight_bram_din = 1; #(CLK_PERIOD);
        weight_bram_addr = 1; weight_bram_din = 2; #(CLK_PERIOD);
        weight_bram_addr = 2; weight_bram_din = 1; #(CLK_PERIOD);
        weight_bram_wen = 1'b0;
        $display("T=%0t: Conv1D BRAMs loaded.", $time);
    end
    endtask

    // Task to load Dense Weights BRAM for a specific expected class
    task load_dense_weights (input [1:0] expected_class);
        reg [DENSE_WEIGHT_W-1:0] w0, w1, w2; // Weights for each class
    begin
        $display("T=%0t: Loading Dense Weights (Expect Class %d)...", $time, expected_class);
        // Set weights based on expected class
        w0 = (expected_class == 0) ? 5 : 1; // High weight if expecting class 0
        w1 = (expected_class == 1) ? 5 : 1; // High weight if expecting class 1
        w2 = (expected_class == 2) ? 5 : 1; // High weight if expecting class 2

        dense_w_bram_wen = 1'b1;
        // Class 0 weights (Indices 0-5)
        for (i = 0; i < INPUT_FEATURES; i = i + 1) begin
            dense_w_bram_addr = i; dense_w_bram_din = w0; #(CLK_PERIOD);
        end
        // Class 1 weights (Indices 6-11)
        for (i = INPUT_FEATURES; i < 2*INPUT_FEATURES; i = i + 1) begin
            dense_w_bram_addr = i; dense_w_bram_din = w1; #(CLK_PERIOD);
        end
        // Class 2 weights (Indices 12-17)
        for (i = 2*INPUT_FEATURES; i < 3*INPUT_FEATURES; i = i + 1) begin
            dense_w_bram_addr = i; dense_w_bram_din = w2; #(CLK_PERIOD);
        end
        dense_w_bram_wen = 1'b0;
        $display("T=%0t: Dense Weights loaded.", $time);
    end
    endtask

    // Task to run the CNN and check the result
    task run_and_check (input [1:0] expected_class);
    begin
        $display("T=%0t: Starting CNN TOP (Expect Class %d)...", $time, expected_class);
        start = 1'b1;
        #(CLK_PERIOD);
        start = 1'b0;
        
        wait (done == 1'b1);
        $display("T=%0t: CNN TOP Finished.", $time);
        
        #(CLK_PERIOD); // Wait one cycle for output to settle
        
        $display("T=%0t: FINAL CLASS OUTPUT: %d (Expected %d)", $time, final_class_out, expected_class);
        
        if (final_class_out == expected_class) begin
            $display("TEST CASE %d PASSED!", expected_class);
        end else begin
            $display("TEST CASE %d FAILED!", expected_class);
        end
        #(2*CLK_PERIOD); // Small delay between tests
    end
    endtask

    // --- Test Stimulus ---
    initial begin
        $display("Starting COMPREHENSIVE CNN TOP Testbench...");
        
        // 1. Reset
        rst_n = 1'b0;
        start = 1'b0;
        data_bram_wen = 1'b0; weight_bram_wen = 1'b0;
        feature_bram_wen = 1'b0; dense_w_bram_wen = 1'b0;
        #20;
        rst_n = 1'b1;
        #(CLK_PERIOD);

        // --- RUN TEST CASE 0 ---
        load_conv_brams();
        load_dense_weights(0); // Load weights expecting class 0
        run_and_check(0);      // Run and check for class 0
        
        // --- RUN TEST CASE 1 ---
        // Conv BRAMs don't need reloading if data is the same
        load_dense_weights(1); // Load weights expecting class 1
        run_and_check(1);      // Run and check for class 1
        
        // --- RUN TEST CASE 2 ---
        load_dense_weights(2); // Load weights expecting class 2
        run_and_check(2);      // Run and check for class 2

        $display("All test cases complete.");
        $finish;
    end

endmodule