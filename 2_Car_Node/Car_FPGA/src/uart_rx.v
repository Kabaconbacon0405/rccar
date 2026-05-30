module uart_rx #(
    parameter CLK_FREQ = 100_000_000, 
    parameter BAUD_RATE = 9600
)(
    input wire clk,
    input wire rst,           
    input wire rx_pin,        
    output reg [7:0] rx_data, 
    output reg rx_done        
);

    localparam BIT_TIMER_MAX = CLK_FREQ / BAUD_RATE;
    localparam BIT_TIMER_HALF = BIT_TIMER_MAX / 2;

    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;
    localparam DONE  = 3'd4;

    reg [2:0] state = IDLE;
    reg [15:0] timer = 0;       
    reg [2:0] bit_index = 0;    
    reg [7:0] shift_reg = 0;    

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            timer <= 0;
            bit_index <= 0;
            rx_data <= 0;
            rx_done <= 0;
            shift_reg <= 0;
        end else begin
            rx_done <= 0; 

            case (state)
                IDLE: begin
                    timer <= 0;
                    bit_index <= 0;
                    if (!rx_pin) state <= START;
                end

                START: begin
                    timer <= timer + 1;
                    if (timer == BIT_TIMER_HALF) begin
                        if (!rx_pin) begin
                            timer <= 0;
                            state <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end
                end

                DATA: begin
                    timer <= timer + 1;
                    if (timer == BIT_TIMER_MAX) begin
                        timer <= 0;
                        shift_reg[bit_index] <= rx_pin;
                        if (bit_index == 3'd7) state <= STOP;
                        else bit_index <= bit_index + 1;
                    end
                end

                STOP: begin
                    if (timer == BIT_TIMER_MAX) begin
                        state <= DONE;
                    end else begin
                        timer <= timer + 1;
                    end
                end

                DONE: begin
                    rx_data <= shift_reg;
                    rx_done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
