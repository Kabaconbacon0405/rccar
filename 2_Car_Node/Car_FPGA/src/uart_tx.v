module uart_tx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 9600
)(
    input wire clk,
    input wire rst,
    input wire tx_start,
    input wire [7:0] tx_data,
    output reg tx_pin,
    output reg tx_busy
);
    
    localparam BIT_TIMER_MAX = CLK_FREQ / BAUD_RATE;

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state = IDLE;
    reg [15:0] timer = 0;
    reg [2:0] bit_index = 0;
    reg [7:0] shift_reg = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx_pin <= 1'b1; 
            tx_busy <= 0;
            timer <= 0;
            bit_index <= 0;
            shift_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_pin <= 1'b1;
                    tx_busy <= 0;
                    timer <= 0;
                    bit_index <= 0; 
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        tx_busy <= 1'b1;
                        state <= START;
                    end
                end
                
                START: begin
                    tx_pin <= 1'b0; 
                    if (timer == BIT_TIMER_MAX - 1) begin
                        timer <= 0;
                        state <= DATA;
                    end else begin
                        timer <= timer + 1;
                    end
                end
                
                DATA: begin
                    tx_pin <= shift_reg[bit_index]; 
                    if (timer == BIT_TIMER_MAX - 1) begin
                        timer <= 0;
                        if (bit_index == 3'd7) state <= STOP;
                        else bit_index <= bit_index + 1;
                    end else begin
                        timer <= timer + 1;
                    end
                end
                
                STOP: begin
                    tx_pin <= 1'b1; 
                    if (timer == BIT_TIMER_MAX - 1) begin
                        timer <= 0;
                        state <= IDLE;
                    end else begin
                        timer <= timer + 1;
                    end
                end
            endcase
        end
    end
endmodule