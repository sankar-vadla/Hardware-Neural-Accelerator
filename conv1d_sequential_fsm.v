`timescale 1ns / 1ps


module conv1d_sequential_fsm (
    clk,
    rst_n,
    start,
    done
);

    // --- Parameters ---
    parameter DATA_WIDTH = 8;
    parameter ACCUM_WIDTH = 24;
    parameter INPUT_LEN = 8;
    parameter KERNEL_SIZE = 3;
    
    parameter OUTPUT_LEN = INPUT_LEN - KERNEL_SIZE + 1; // 8 - 3 + 1 = 6

    // --- Ports ---
    input             clk;
    input             rst_n;
    input             start;
    output reg        done;

    // --- Internal Registers & Memories ---
    reg [ACCUM_WIDTH-1:0] output_feature_map [0:OUTPUT_LEN-1];

    // --- FSM State Registers ---
    parameter [2:0] IDLE        = 3'b000,
                    MAC_CYCLE   = 3'b001,
                    MAC_WAIT1   = 3'b010,
                    MAC_WAIT2   = 3'b011,
                    ALL_DONE    = 3'b100;
                    
    reg [2:0] state, next_state; // State registers

    // --- Datapath Registers (Counters & Accumulator) ---
    reg signed [ACCUM_WIDTH-1:0] accum_reg;
    reg [3:0] window_pos; // Tracks the start of the window (0 to 5)
    reg [2:0] kernel_pos; // Tracks position in kernel (0 to 2)

    // --- Hardcoded Data ---
    reg signed [DATA_WIDTH-1:0] input_data [0:INPUT_LEN-1];
    reg signed [DATA_WIDTH-1:0] kernel_weights [0:KERNEL_SIZE-1];
    
    // --- Wires to connect to the MAC unit ---
    wire signed [ACCUM_WIDTH-1:0] mac_cout; // Output from MAC
    reg signed [DATA_WIDTH-1:0]   mac_a;    // Input 'a' to MAC
    reg signed [DATA_WIDTH-1:0]   mac_b;    // Input 'b' to MAC
    reg signed [ACCUM_WIDTH-1:0]  mac_cin;  // Input 'c_in' to MAC
    reg                           mac_en;   // Enable to MAC
    
    // --- Initialize Hardcoded Data ---
    initial begin
        input_data[0] = 1; input_data[1] = 2; input_data[2] = 3; input_data[3] = 4;
        input_data[4] = 1; input_data[5] = 1; input_data[6] = 1; input_data[7] = 1;
        kernel_weights[0] = 1; kernel_weights[1] = 2; kernel_weights[2] = 1;
    end

    // --- Instantiate the MAC Unit ---
    mac_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH)
    ) mac_inst (
        .clk(clk),
        .rst_n(rst_n),
        .en(mac_en),
        .a(mac_a),
        .b(mac_b),
        .c_in(mac_cin),
        .c_out(mac_cout)
    );
    
    // --- PROCESS 1: Sequential Logic (All Registers) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            window_pos <= 0;
            kernel_pos <= 0;
            accum_reg <= 0;
        end 
        else begin
            // Update the state
            state <= next_state;

            // Update counters based on the *CURRENT* state
            case (state)
                IDLE: begin
                    if (start) begin
                        window_pos <= 0;
                        kernel_pos <= 0;
                        accum_reg <= 0;
                    end
                end
                
                MAC_WAIT2: begin // This is when mac_cout is valid
                    
                    if (kernel_pos == KERNEL_SIZE - 1) begin
                        // This window just finished
                        output_feature_map[window_pos] <= mac_cout;
                        window_pos <= window_pos + 1;
                        // Reset for next window
                        kernel_pos <= 0;
                        accum_reg <= 0;
                    end
                    else begin
                        // This window is not done
                        kernel_pos <= kernel_pos + 1;
                        accum_reg <= mac_cout; // Save partial sum
                    end
                end
            endcase
        end
    end

    // --- PROCESS 2: Combinational Logic (Control Unit) ---
    always @(state or start or window_pos or kernel_pos or accum_reg) begin
        
        // Set "safe" defaults
        next_state = state;
        done = 1'b0;
        mac_en = 1'b0;
        mac_a = 0; 
        mac_b = 0; 
        mac_cin = accum_reg;

        case (state)
            IDLE: begin
                mac_cin = 0; // Override default
                if (start) begin
                    next_state = MAC_CYCLE;
                end
            end
            
            MAC_CYCLE: begin
                mac_en = 1'b1; // Keep EN=1 for pipeline
                mac_a = input_data[window_pos + kernel_pos];
                mac_b = kernel_weights[kernel_pos];
                mac_cin = accum_reg; 
                next_state = MAC_WAIT1;
            end
            
            MAC_WAIT1: begin
                mac_en = 1'b1; // Keep EN=1 for pipeline
                mac_a = input_data[window_pos + kernel_pos];
                mac_b = kernel_weights[kernel_pos];
                mac_cin = accum_reg;
                next_state = MAC_WAIT2;
            end
            
            MAC_WAIT2: begin
                mac_en = 1'b1; // Keep EN=1 for pipeline
                mac_a = input_data[window_pos + kernel_pos];
                mac_b = kernel_weights[kernel_pos];
                mac_cin = accum_reg;

                // On the *next* clock edge, mac_cout will be valid
                // for the *current* k_pos.
                
                if (kernel_pos == KERNEL_SIZE - 1) begin
                    // This window is finishing
                    // Check if this *was* the last window
                    if (window_pos == OUTPUT_LEN - 1) begin
                        next_state = ALL_DONE; // All windows are done
                    end
                    else begin
                        // Not the last window, start the next one
                        next_state = MAC_CYCLE;
                    end
                end 
                else begin
                    // This window is not finished, do next MAC
                    next_state = MAC_CYCLE; 
                end
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