module car_fsm (
    input wire clk,
    input wire rst,
    input wire [7:0] rx_data,   
    input wire rx_done,         
    
    // Extracted Hardware Commands
    output reg [7:0] target_speed, // 0-100%
    output reg [1:0] throttling,   // 0=Instant, 1=Fast, 2=Smooth, 3=Slow
    output reg direction,          // 1=Forward, 0=Reverse
    output reg horn                // 1=Honk, 0=Silent
);

    // FSM States
    localparam WAIT_SYNC  = 2'd0;
    localparam GET_SPEED  = 2'd1;
    localparam GET_CMD    = 2'd2;
    localparam VERIFY_END = 2'd3;

    reg [1:0] state = WAIT_SYNC;

    // Shadow registers (Hold data temporarily in case the packet is corrupted)
    reg [7:0] speed_reg = 0;
    reg [7:0] cmd_reg   = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= WAIT_SYNC;
            target_speed <= 8'd0;
            throttling <= 2'd0;
            direction <= 1'b1;
            horn <= 1'b0;
            speed_reg <= 8'd0;
            cmd_reg <= 8'd0;
        end else begin
            if (rx_done) begin
                case (state)
                    WAIT_SYNC: begin
                        if (rx_data == 8'hAA) state <= GET_SPEED;
                    end

                    GET_SPEED: begin
                        speed_reg <= rx_data;
                        state <= GET_CMD;
                    end

                    GET_CMD: begin
                        cmd_reg <= rx_data;
                        state <= VERIFY_END;
                    end

                    VERIFY_END: begin
                        // SECURITY CHECK: Did we actually get the End Byte?
                        if (rx_data == 8'h55) begin
                            // The packet is perfect. Lock it into the hardware!
                            target_speed <= speed_reg;
                            
                            // Bit-slice the command register based on our C++ structure
                            // cmd_reg = [ 0 0 0 0 | Horn(Bit 3) | Dir(Bit 2) | Throttling(Bits 1:0) ]
                            horn       <= cmd_reg[3];
                            direction  <= cmd_reg[2];
                            throttling <= cmd_reg[1:0];
                        end
                        // Whether it succeeded or failed, reset to wait for the next packet
                        state <= WAIT_SYNC;
                    end

                    default: state <= WAIT_SYNC;
                endcase
            end
        end
    end
endmodule