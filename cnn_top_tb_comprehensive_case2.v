`timescale 1ns / 1ps

//
// Module: cnn_top_tb_comprehensive_case2.v (Verilog-2001 Standard)
//
// This is the SECOND comprehensive testbench.
// - Uses NEW input data: [1, 0, 1, 0, 1, 0, 1, 0]
// - Uses the SAME weights structure as the first comprehensive testbench.
// - Runs three cases covering expected outputs 0, 1, and 2.
//
module cnn_top_tb_comprehensive_case2;

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
    reg  data_bram_wen;
    reg [CONV_ADDR_W-1:0] data_bram_addr;
    reg [CONV_DATA_W-1:0] data_bram_din;
    reg  weight_bram_wen;
    reg [CONV_ADDR_W-1:0] weight_bram_addr;
    reg [CONV_DATA_W-1:0] weight_bram_din;
    reg  feature_bram_wen;
    reg [DENSE_ADDR_W-1:0] feature_bram_addr;
    reg [DENSE_DATA_W-1:0] feature_bram_din;
    reg  dense_w_bram_wen;
    reg [DENSE_ADDR_W-1:0] dense_w_bram_addr;
    reg [DENSE_WEIGHT_W-1:0] dense_w_bram_din;

    // --- Instantiate the Design Under Test (DUT) ---
    cnn_top DUT (
        .clk(clk), .rst_n(rst_n), .start(start), .done(done),
        .data_bram_wen(data_bram_wen), .data_bram_addr(data_bram_addr), .data_bram_din(data_bram_din),
        .weight_bram_wen(weight_bram_wen), .weight_bram_addr(weight_bram_addr), .weight_bram_din(weight_bram_din),
        .feature_bram_wen(feature_bram_wen), .feature_bram_addr(feature_bram_addr), .feature_bram_din(feature_bram_din),
        .dense_w_bram_wen(dense_w_bram_wen), .dense_w_bram_addr(dense_w_bram_addr), .dense_w_bram_din(dense_w_bram_din),
        .final_class_out(final_class_out)
    );

    // --- Clock Generator ---
    always begin
        clk = 1'b0; #(CLK_PERIOD / 2);
        clk = 1'b1; #(CLK_PERIOD / 2);
    end

    // --- Helper Tasks ---
    integer i;

    // Task to load Conv1D BRAMs (NEW alternating data)
    task load_conv_brams_case2;
    begin
        $display("T=%0t: Loading Conv1D BRAMs (Data=[1,0,...], Weights=[1,2,1])...", $time);
        data_bram_wen = 1'b1;
        for (i = 0; i < 8; i = i + 1) begin
            data_bram_addr = i;
            data_bram_din = (i % 2 == 0) ? 1 : 0; // Data is 1, 0, 1, 0...
            #(CLK_PERIOD);
        end
        data_bram_wen = 1'b0;

        weight_bram_wen = 1'b1; // Same weights
        weight_bram_addr = 0; weight_bram_din = 1; #(CLK_PERIOD);
        weight_bram_addr = 1; weight_bram_din = 2; #(CLK_PERIOD);
        weight_bram_addr = 2; weight_bram_din = 1; #(CLK_PERIOD);
        weight_bram_wen = 1'b0;
        $display("T=%0t: Conv1D BRAMs loaded.", $time);
    end
    endtask

    // Task to load Dense Weights BRAM (SAME as before)
    task load_dense_weights (input [1:0] expected_class);
        reg [DENSE_WEIGHT_W-1:0] w0, w1, w2;
    begin
        $display("T=%0t: Loading Dense Weights (Expect Class %d)...", $time, expected_class);
        w0 = (expected_class == 0) ? 5 : 1;
        w1 = (expected_class == 1) ? 5 : 1;
        w2 = (expected_class == 2) ? 5 : 1;

        dense_w_bram_wen = 1'b1;
        for (i = 0; i < INPUT_FEATURES; i = i + 1) begin // Class 0
            dense_w_bram_addr = i; dense_w_bram_din = w0; #(CLK_PERIOD);
        end
        for (i = INPUT_FEATURES; i < 2*INPUT_FEATURES; i = i + 1) begin // Class 1
            dense_w_bram_addr = i; dense_w_bram_din = w1; #(CLK_PERIOD);
        end
        for (i = 2*INPUT_FEATURES; i < 3*INPUT_FEATURES; i = i + 1) begin // Class 2
            dense_w_bram_addr = i; dense_w_bram_din = w2; #(CLK_PERIOD);
        end
        dense_w_bram_wen = 1'b0;
        $display("T=%0t: Dense Weights loaded.", $time);
    end
    endtask

    // Task to run the CNN and check the result (SAME as before)
    task run_and_check (input [1:0] expected_class);
    begin
        $display("T=%0t: Starting CNN TOP (Expect Class %d)...", $time, expected_class);
        start = 1'b1; #(CLK_PERIOD); start = 1'b0;
        wait (done == 1'b1);
        $display("T=%0t: CNN TOP Finished.", $time);
        #(CLK_PERIOD);
        $display("T=%0t: FINAL CLASS OUTPUT: %d (Expected %d)", $time, final_class_out, expected_class);
        if (final_class_out == expected_class) begin
            $display("TEST CASE %d PASSED!", expected_class);
        end else begin
            $display("TEST CASE %d FAILED!", expected_class);
        end
        #(2*CLK_PERIOD);
    end
    endtask

    // --- Test Stimulus ---
    initial begin
        $display("Starting COMPREHENSIVE CNN TOP Testbench - CASE 2...");
        rst_n = 1'b0; start = 1'b0; // Reset other signals
        data_bram_wen = 1'b0; weight_bram_wen = 1'b0;
        feature_bram_wen = 1'b0; dense_w_bram_wen = 1'b0;
        #20; rst_n = 1'b1; #(CLK_PERIOD);

        // --- RUN TEST CASE 0 ---
        load_conv_brams_case2(); // Use new data loader
        load_dense_weights(0);
        run_and_check(0);

        // --- RUN TEST CASE 1 ---
        load_dense_weights(1);
        run_and_check(1);

        // --- RUN TEST CASE 2 ---
        load_dense_weights(2);
        run_and_check(2);

        $display("All test cases complete.");
        $finish;
    end

endmodule