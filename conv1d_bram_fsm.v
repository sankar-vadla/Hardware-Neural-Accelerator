`timescale 1ns / 1ps


module conv1d_bram_fsm (
    clk,
    rst_n,
    start,
    done,
    
    // BRAM Port A (for testbench)
    data_bram_wen, data_bram_addr, data_bram_din,
    weight_bram_wen, weight_bram_addr, weight_bram_din,
    
    // New "Boss" Read Port
    boss_read_addr,
    boss_read_dout
);

    // --- Parameters ---
    parameter DATA_WIDTH = 8;
    parameter ACCUM_WIDTH = 24;
    parameter INPUT_LEN = 8;
    parameter KERNEL_SIZE = 3;
    
    parameter OUTPUT_LEN = INPUT_LEN - KERNEL_SIZE + 1; // 8 - 3 + 1 = 6
    parameter ADDR_WIDTH = 4; // 2^4 = 16 locations

    // --- Ports ---
    input             clk;
    input             rst_n;
    input             start;
    output reg        done;
    
    input             data_bram_wen;
    input [ADDR_WIDTH-1:0] data_bram_addr;
    input [DATA_WIDTH-1:0] data_bram_din;
    
    input             weight_bram_wen;
    input [ADDR_WIDTH-1:0] weight_bram_addr;
    input [DATA_WIDTH-1:0] weight_bram_din;

    input [2:0]       boss_read_addr; 
    output [ACCUM_WIDTH-1:0] boss_read_dout;


    // --- Internal Registers & Memories ---
    reg [ACCUM_WIDTH-1:0] output_feature_map [0:OUTPUT_LEN-1];

    // --- FSM State Registers ---
    parameter [3:0] IDLE        = 4'b0000,
                    BRAM_READ   = 4'b0001,
                    BRAM_WAIT   = 4'b0010, 
                    MAC_CYCLE   = 4'b0011,
                    MAC_WAIT1   = 4'b0100,
                    MAC_WAIT2   = 4'b0101,
                    ALL_DONE    = 4'b0110;
                    
    reg [3:0] state, next_state; 

    // --- Datapath Registers ---
    reg signed [ACCUM_WIDTH-1:0] accum_reg;
    reg [3:0] window_pos; 
    reg [2:0] kernel_pos; 

    // --- BRAM Wires ---
    reg [ADDR_WIDTH-1:0] data_bram_b_addr;
    wire [DATA_WIDTH-1:0] data_bram_b_dout;
    reg [ADDR_WIDTH-1:0] weight_bram_b_addr;
    wire [DATA_WIDTH-1:0] weight_bram_b_dout;
    
    // --- MAC Wires ---
    wire signed [ACCUM_WIDTH-1:0] mac_cout;
    reg signed [DATA_WIDTH-1:0]   mac_a;    
    reg signed [DATA_WIDTH-1:0]   mac_b;    
    reg signed [ACCUM_WIDTH-1:0]  mac_cin;  
    reg                           mac_en;   
    
    // --- Instantiate BRAMs ---
    dual_port_bram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) 
    data_bram_inst (.clk(clk), .a_wen(data_bram_wen), .a_addr(data_bram_addr), .a_din(data_bram_din),
                    .b_en(1'b1), .b_addr(data_bram_b_addr), .b_dout(data_bram_b_dout));

    dual_port_bram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) 
    weight_bram_inst (.clk(clk), .a_wen(weight_bram_wen), .a_addr(weight_bram_addr), .a_din(weight_bram_din),
                      .b_en(1'b1), .b_addr(weight_bram_b_addr), .b_dout(weight_bram_b_dout));

    // --- CORRECTED MAC INSTANTIATION ---
    mac_unit #(
        .A_WIDTH(DATA_WIDTH),     // 'a' is DATA_WIDTH
        .B_WIDTH(DATA_WIDTH),     // 'b' is also DATA_WIDTH
        .ACCUM_WIDTH(ACCUM_WIDTH)
    ) mac_inst (
        .clk(clk), .rst_n(rst_n), .en(mac_en), 
        .a(mac_a), .b(mac_b), .c_in(mac_cin), .c_out(mac_cout)
    );

    // --- Combinational read logic for boss ---
    assign boss_read_dout = output_feature_map[boss_read_addr];
    
    // --- PROCESS 1: Sequential Logic (All Registers) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            window_pos <= 0; kernel_pos <= 0; accum_reg <= 0;
            mac_a <= 0; mac_b <= 0;
        end 
        else begin
            state <= next_state;
            
            if (state == BRAM_WAIT) begin
                mac_a <= $signed(data_bram_b_dout);
                mac_b <= $signed(weight_bram_b_dout);
            end

            case (state)
                IDLE: begin
                    if (start) begin
                        window_pos <= 0; kernel_pos <= 0; accum_reg <= 0;
                    end
                end
                
                MAC_WAIT2: begin
                    if (kernel_pos == KERNEL_SIZE - 1) begin
                        output_feature_map[window_pos] <= mac_cout;
                        window_pos <= window_pos + 1;
                        kernel_pos <= 0; accum_reg <= 0;
                    end
                    else begin
                        kernel_pos <= kernel_pos + 1;
                        accum_reg <= mac_cout;
                    end
                end
            endcase
        end
    end

    // --- PROCESS 2: Combinational Logic (Control Unit) ---
    always @(state or start or window_pos or kernel_pos or accum_reg) begin
        
        next_state = state;
        done = 1'b0;
        mac_en = 1'b0;
        mac_cin = accum_reg;
        data_bram_b_addr = window_pos + kernel_pos;
        weight_bram_b_addr = kernel_pos;

        case (state)
            IDLE: begin
                mac_cin = 0; 
                if (start) begin
                    next_state = BRAM_READ;
                end
            end
            
            BRAM_READ: begin
                data_bram_b_addr = window_pos + kernel_pos;
                weight_bram_b_addr = kernel_pos;
                next_state = BRAM_WAIT;
            end
            
            BRAM_WAIT: begin
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
                
                if (kernel_pos == KERNEL_SIZE - 1) begin
                    if (window_pos == OUTPUT_LEN - 1) begin
                        next_state = ALL_DONE; 
                    end
                    else begin
                        next_state = BRAM_READ;
                    end
                end 
                else begin
                    next_state = BRAM_READ; 
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