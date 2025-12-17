`timescale 1ns / 1ps


`module cnn_top (
    clk,
    rst_n,
    start,
    done,
    
    // BRAM Ports
    data_bram_wen, data_bram_addr, data_bram_din,
    weight_bram_wen, weight_bram_addr, weight_bram_din,
    feature_bram_wen, feature_bram_addr, feature_bram_din,
    dense_w_bram_wen, dense_w_bram_addr, dense_w_bram_din,
    
    // Final Output
    final_class_out
);

    // --- Parameters ---
    parameter CONV_DATA_W = 8;
    parameter CONV_ADDR_W = 4;
    parameter CONV_ACCUM_W = 24;
    parameter DENSE_DATA_W = 24;
    parameter DENSE_WEIGHT_W = 8;
    parameter DENSE_ADDR_W = 5;
    parameter INPUT_FEATURES = 6;
    
    // --- Ports ---
    input             clk;
    input             rst_n;
    input             start; // External start trigger
    output reg        done;  // Top-level done signal
    
    // BRAM Ports (pass-through)
    input             data_bram_wen;
    input [CONV_ADDR_W-1:0] data_bram_addr;
    input [CONV_DATA_W-1:0] data_bram_din;
    input             weight_bram_wen;
    input [CONV_ADDR_W-1:0] weight_bram_addr;
    input [CONV_DATA_W-1:0] weight_bram_din;
    input             feature_bram_wen;
    input [DENSE_ADDR_W-1:0] feature_bram_addr;
    input [DENSE_DATA_W-1:0] feature_bram_din;
    input             dense_w_bram_wen;
    input [DENSE_ADDR_W-1:0] dense_w_bram_addr;
    input [DENSE_WEIGHT_W-1:0] dense_w_bram_din;
    output [1:0]      final_class_out;

    // --- Boss FSM States ---
    // Added START states for clean pulsing
    parameter [3:0] IDLE        = 4'b0000,
                    START_CONV  = 4'b0001, // New
                    WAIT_CONV   = 4'b0010, // Renamed from RUN_CONV
                    COPY_RELU   = 4'b0011,
                    START_DENSE = 4'b0100, // New
                    WAIT_DENSE  = 4'b0101, // Renamed from RUN_DENSE
                    ALL_DONE    = 4'b0110;
                    
    reg [3:0] state, next_state;

    // --- Control Wires for Workers ---
    reg  conv1d_start; // Driven by combinational block
    wire conv1d_done;
    reg  dense_start; // Driven by combinational block
    wire dense_done;
    
    // --- Wires/Regs for Copy ---
    reg [2:0] copy_counter; // 0 to 5
    wire [CONV_ACCUM_W-1:0] conv_result_in;
    wire [CONV_ACCUM_W-1:0] relu_result_out;
    reg [DENSE_ADDR_W-1:0] feature_bram_addr_internal;
    reg [DENSE_DATA_W-1:0] feature_bram_din_internal;
    reg                    feature_bram_wen_internal;

    // --- Wires for Muxed BRAM Port A Connection ---
    wire                  feature_bram_wen_muxed;
    wire [DENSE_ADDR_W-1:0] feature_bram_addr_muxed;
    wire [DENSE_DATA_W-1:0] feature_bram_din_muxed;

    // --- Instantiate Modules ---
    conv1d_bram_fsm #( .DATA_WIDTH(CONV_DATA_W), .ACCUM_WIDTH(CONV_ACCUM_W), .ADDR_WIDTH(CONV_ADDR_W) ) 
    conv1d_unit ( .clk(clk), .rst_n(rst_n), .start(conv1d_start), .done(conv1d_done),
                  .data_bram_wen(data_bram_wen), .data_bram_addr(data_bram_addr), .data_bram_din(data_bram_din),
                  .weight_bram_wen(weight_bram_wen), .weight_bram_addr(weight_bram_addr), .weight_bram_din(weight_bram_din),
                  .boss_read_addr(copy_counter), .boss_read_dout(conv_result_in) );

    compute_dense_fsm #( .DATA_WIDTH(DENSE_DATA_W), .INPUT_FEATURES(INPUT_FEATURES) ) 
    dense_unit ( .clk(clk), .rst_n(rst_n), .start(dense_start), .done(dense_done),
                 .feature_bram_wen(feature_bram_wen_muxed), .feature_bram_addr(feature_bram_addr_muxed), .feature_bram_din(feature_bram_din_muxed),
                 .dense_w_bram_wen(dense_w_bram_wen), .dense_w_bram_addr(dense_w_bram_addr), .dense_w_bram_din(dense_w_bram_din),
                 .final_class_out(final_class_out) );

    compute_relu #( .DATA_WIDTH(CONV_ACCUM_W) ) 
    relu_unit ( .din(conv_result_in), .dout(relu_result_out) );
    
    // --- BRAM Port A Mux Logic ---
    assign feature_bram_wen_muxed  = feature_bram_wen_internal  ? 1'b1                   : feature_bram_wen;
    assign feature_bram_addr_muxed = feature_bram_wen_internal  ? feature_bram_addr_internal : feature_bram_addr;
    assign feature_bram_din_muxed  = feature_bram_wen_internal  ? feature_bram_din_internal  : feature_bram_din;
    
    // --- PROCESS 1: Sequential Logic (Boss FSM) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            copy_counter <= 0;
        end else begin
            state <= next_state;
            
            // Update copy counter based on *current* state
            case(state)
                IDLE: begin
                    if (start) begin
                        copy_counter <= 0; // Reset on external start
                    end
                end
                COPY_RELU: begin
                    if (copy_counter == INPUT_FEATURES - 1) begin
                         copy_counter <= 0; // Reset after last copy
                    end else begin
                         copy_counter <= copy_counter + 1;
                    end
                end
            endcase
        end
    end
    
    // --- PROCESS 2: Combinational Logic (Boss FSM) ---
    always @(state or start or conv1d_done or dense_done or copy_counter or relu_result_out) begin
        
        // Defaults
        next_state = state;
        done = 1'b0;
        conv1d_start = 1'b0; // Default off
        dense_start = 1'b0; // Default off
        feature_bram_wen_internal = 1'b0; // Default off
        feature_bram_addr_internal = 0;
        feature_bram_din_internal = 0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = START_CONV;
                end
            end
            
            START_CONV: begin
                conv1d_start = 1'b1; // Assert start for one cycle
                next_state = WAIT_CONV;
            end

            WAIT_CONV: begin
                conv1d_start = 1'b0; // De-assert start
                if (conv1d_done) begin
                    next_state = COPY_RELU;
                    // Counter reset handled in sequential block when IDLE->START_CONV occurred
                end
                // else stay in WAIT_CONV
            end
            
            COPY_RELU: begin
                // Drive internal BRAM write signals based on current counter
                feature_bram_wen_internal = 1'b1;
                feature_bram_addr_internal = copy_counter;
                feature_bram_din_internal = relu_result_out;
                
                // Check current counter value to decide next state
                if (copy_counter == INPUT_FEATURES - 1) begin
                    next_state = START_DENSE; // Move after this write completes
                end else begin
                    next_state = COPY_RELU; // Stay to increment counter
                end
            end

            START_DENSE: begin
                 dense_start = 1'b1; // Assert start for one cycle
                 next_state = WAIT_DENSE;
            end
            
            WAIT_DENSE: begin
                 dense_start = 1'b0; // De-assert start
                 if (dense_done) begin
                    next_state = ALL_DONE;
                 end
                 // else stay in WAIT_DENSE
            end
            
            ALL_DONE: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule