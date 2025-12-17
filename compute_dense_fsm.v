`timescale 1ns / 1ps


module compute_dense_fsm (
    clk,
    rst_n,
    start,
    done,
    
    // BRAM Port A
    feature_bram_wen, feature_bram_addr, feature_bram_din,
    dense_w_bram_wen, dense_w_bram_addr, dense_w_bram_din,
    
    // Final result
    final_class_out
);
    // --- Parameters ---
    parameter DATA_WIDTH = 24;
    parameter WEIGHT_WIDTH = 8;
    parameter ACCUM_WIDTH = 32;
    parameter INPUT_FEATURES = 6;
    parameter OUTPUT_CLASSES = 3;
    parameter ADDR_WIDTH = 5;

    // --- Ports ---
    input             clk;
    input             rst_n;
    input             start;
    output reg        done;
    
    // BRAM Port A
    input             feature_bram_wen;
    input [ADDR_WIDTH-1:0] feature_bram_addr;
    input [DATA_WIDTH-1:0] feature_bram_din;
    input             dense_w_bram_wen;
    input [ADDR_WIDTH-1:0] dense_w_bram_addr;
    input [WEIGHT_WIDTH-1:0] dense_w_bram_din;
    output reg [1:0]  final_class_out;

    // --- Internal Registers ---
    reg signed [ACCUM_WIDTH-1:0] output_scores [0:OUTPUT_CLASSES-1];

    // --- FSM State Registers ---
    parameter [3:0] IDLE            = 4'b0000,
                    BRAM_READ       = 4'b0001,
                    BRAM_WAIT       = 4'b0010,
                    MAC_CYCLE       = 4'b0011,
                    MAC_WAIT1       = 4'b0100,
                    MAC_WAIT2       = 4'b0101,
                    SAVE_LAST_SCORE = 4'b0110,
                    FIND_MAX        = 4'b0111,
                    ALL_DONE        = 4'b1000;
                    
    reg [3:0] state, next_state;

    // --- Datapath Registers ---
    reg signed [ACCUM_WIDTH-1:0] accum_reg;
    reg [2:0] class_pos;
    reg [2:0] feature_pos;

    // --- BRAM Wires ---
    reg [ADDR_WIDTH-1:0] feature_bram_b_addr;
    wire [DATA_WIDTH-1:0] feature_bram_b_dout;
    reg [ADDR_WIDTH-1:0] dense_w_bram_b_addr;
    wire [WEIGHT_WIDTH-1:0] dense_w_bram_b_dout;
    
    // --- MAC Wires ---
    wire signed [ACCUM_WIDTH-1:0] mac_cout;
    reg signed [DATA_WIDTH-1:0]   mac_a;    
    reg signed [WEIGHT_WIDTH-1:0] mac_b; 
    reg signed [ACCUM_WIDTH-1:0]  mac_cin;  
    reg                           mac_en;   
    
    // --- Instantiate BRAMs & MAC ---
    dual_port_bram #( .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH) ) 
    feature_bram_inst ( .clk(clk), .a_wen(feature_bram_wen), .a_addr(feature_bram_addr), .a_din(feature_bram_din),
                        .b_en(1'b1), .b_addr(feature_bram_b_addr), .b_dout(feature_bram_b_dout) );

    dual_port_bram #( .DATA_WIDTH(WEIGHT_WIDTH), .ADDR_WIDTH(ADDR_WIDTH) ) 
    weight_bram_inst ( .clk(clk), .a_wen(dense_w_bram_wen), .a_addr(dense_w_bram_addr), .a_din(dense_w_bram_din),
                       .b_en(1'b1), .b_addr(dense_w_bram_b_addr), .b_dout(dense_w_bram_b_dout) );

    mac_unit #( .A_WIDTH(DATA_WIDTH), .B_WIDTH(WEIGHT_WIDTH), .ACCUM_WIDTH(ACCUM_WIDTH) ) 
    mac_inst ( .clk(clk), .rst_n(rst_n), .en(mac_en), .a(mac_a), .b(mac_b), .c_in(mac_cin), .c_out(mac_cout) );
    
    // --- PROCESS 1: Sequential Logic (All Registers) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            class_pos <= 0; feature_pos <= 0; accum_reg <= 0;
            mac_a <= 0; mac_b <= 0;
            final_class_out <= 0;
            output_scores[0] <= 0; output_scores[1] <= 0; output_scores[2] <= 0; 
        end 
        else begin
            state <= next_state;
            
            // Latch BRAM data after wait cycle
            if (state == BRAM_WAIT) begin
                mac_a <= $signed(feature_bram_b_dout);
                mac_b <= $signed(dense_w_bram_b_dout);
            end

            // Update counters based on *current* state
            case (state)
                IDLE: begin
                    if (start) begin // Reset counters on start
                        class_pos <= 0; feature_pos <= 0; accum_reg <= 0;
                        output_scores[0] <= 0; output_scores[1] <= 0; output_scores[2] <= 0; 
                    end
                end
                
                // --- REVISED MAC_WAIT2 LOGIC ---
                MAC_WAIT2: begin // MAC output (mac_cout) is valid now
                    // First, save the result unconditionally
                    if (feature_pos == INPUT_FEATURES - 1) begin
                        // This is the last feature, save final score for the current class
                        output_scores[class_pos] <= mac_cout;
                        accum_reg <= 0; // Reset accumulator for the next class (if any)
                    end else begin
                        // Not the last feature, save partial sum
                        accum_reg <= mac_cout;
                    end

                    // Second, update counters based on conditions
                    if (feature_pos == INPUT_FEATURES - 1) begin
                        // If it was the last feature...
                        if (class_pos != OUTPUT_CLASSES - 1) begin
                             // ...and not the last class, move to next class
                            class_pos <= class_pos + 1;
                        end
                         // Reset feature position regardless of class end
                        feature_pos <= 0;
                    end else begin
                        // If it wasn't the last feature, move to next feature
                        feature_pos <= feature_pos + 1;
                    end
                end
                // --- END REVISED LOGIC ---
                
                FIND_MAX: begin // Compare scores (scores are stable)
                    if (output_scores[0] >= output_scores[1] && output_scores[0] >= output_scores[2]) begin
                        final_class_out <= 0;
                    end
                    else if (output_scores[1] >= output_scores[0] && output_scores[1] >= output_scores[2]) begin
                        final_class_out <= 1;
                    end
                    else begin
                        final_class_out <= 2;
                    end
                end
            endcase
        end
    end

    // --- PROCESS 2: Combinational Logic (Control Unit) ---
    // (Remains the same as Correction #21)
    always @(state or start or class_pos or feature_pos or accum_reg) begin
        
        // Defaults
        next_state = state;
        done = 1'b0;
        mac_en = 1'b0;
        mac_cin = accum_reg;
        feature_bram_b_addr = feature_pos; // Default read addrs
        dense_w_bram_b_addr = class_pos * INPUT_FEATURES + feature_pos;

        case (state)
            IDLE: begin
                mac_cin = 0; 
                if (start) begin
                    next_state = BRAM_READ;
                end
            end
            
            BRAM_READ: begin
                // Set read addresses based on current counters
                feature_bram_b_addr = feature_pos;
                dense_w_bram_b_addr = class_pos * INPUT_FEATURES + feature_pos;
                next_state = BRAM_WAIT;
            end
            
            BRAM_WAIT: begin
                // Wait for BRAM data (latched in sequential block)
                next_state = MAC_CYCLE;
            end
            
            MAC_CYCLE: begin
                mac_en = 1'b1; 
                mac_cin = accum_reg; 
                next_state = MAC_WAIT1;
            end
            
            MAC_WAIT1: begin
                mac_en = 1'b1; 
                mac_cin = accum_reg;
                next_state = MAC_WAIT2;
            end
            
            MAC_WAIT2: begin
                mac_en = 1'b1; 
                mac_cin = accum_reg;
                
                // Decide next step based on counters *before* they update in seq block
                if (feature_pos == INPUT_FEATURES - 1) begin // Was this the last feature?
                    if (class_pos == OUTPUT_CLASSES - 1) begin // Was this the last class?
                        next_state = SAVE_LAST_SCORE; // Go to save state before finding max
                    end
                    else begin // Not the last class
                        next_state = BRAM_READ; // Go read first feature of next class
                    end
                end 
                else begin // Not the last feature
                    next_state = BRAM_READ; // Go read next feature of current class
                end
            end

            SAVE_LAST_SCORE: begin
                // This state just waits one cycle to ensure output_scores[2] is updated
                next_state = FIND_MAX;
            end
            
            FIND_MAX: begin
                // Comparison happens in sequential block
                next_state = ALL_DONE;
            end
            
            ALL_DONE: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule