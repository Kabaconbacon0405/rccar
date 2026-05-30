module telemetry_parser (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] rx_data,     // byte stream from uart_rx
    input  wire       rx_done,     // 1-cycle pulse when rx_data is valid
    output reg  [7:0] real_speed,  // latched current speed (0-100)
    output reg  [7:0] status_byte  // latched status/battery byte
);

    // Telemetry packet from the Controller ESP32:
    //   [0xCF sync][speed][status]
    localparam [7:0] SYNC = 8'hCF;

    localparam WAIT_SYNC = 2'd0;
    localparam GET_SPEED = 2'd1;
    localparam GET_STAT  = 2'd2;

    reg [1:0] state = WAIT_SYNC;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= WAIT_SYNC;
            real_speed  <= 8'd0;
            status_byte <= 8'd0;
        end else if (rx_done) begin
            case (state)
                WAIT_SYNC: begin
                    // Only advance on a valid sync marker; otherwise resync.
                    if (rx_data == SYNC) state <= GET_SPEED;
                    else                 state <= WAIT_SYNC;
                end
                GET_SPEED: begin
                    real_speed <= rx_data;
                    state      <= GET_STAT;
                end
                GET_STAT: begin
                    status_byte <= rx_data;
                    state       <= WAIT_SYNC;
                end
                default: state <= WAIT_SYNC;
            endcase
        end
    end
endmodule
