module top_controller #(
    parameter BAUD_RATE = 9600,     // Add this parameter declaration
    parameter CLOCK_FREQ = 50000000 // You usually need the clock frequency too
)(
    input wire clk,
    input wire rst,          
    input wire [7:0] sw,     // SW0 to SW7
    input wire rx_pin,       // Telemetry data line input from ESP32
    output wire tx_pin,      // Configuration command line output to ESP32
    
    // Nexys4 DDR 7-Segment Interfaces
    output wire [7:0] an,
    output wire [6:0] seg
);

    // --- 1. DEBOUNCE AND CONDITION SWITCH TRACKS ---
    wire [7:0] clean_sw;
    switch_debouncer #(
        .WIDTH(8)
    ) master_debounce (
        .clk(clk),
        .rst(rst),
        .sw_in(sw),
        .sw_out(clean_sw)
    );

    // --- 2. TRANSMITTER ROUTINE (FPGA -> ESP32) ---
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;

    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(9600)
    ) controller_tx (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_pin(tx_pin),
        .tx_busy(tx_busy)
    );

    // Command transmission pacing loop
    localparam WAIT_TIMER_MAX = 5_000_000; // 50ms heartbeat cycle
    reg [22:0] wait_timer = 0;

    localparam SEND_SYNC    = 3'd0;
    localparam WAIT_SYNC_TX = 3'd1;
    localparam SEND_CFG     = 3'd2;
    localparam WAIT_CFG_TX  = 3'd3;
    localparam DELAY        = 3'd4;
    reg [2:0] tx_state = SEND_SYNC;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_state <= SEND_SYNC;
            tx_start <= 0;
            tx_data <= 0;
            wait_timer <= 0;
        end else begin
            tx_start <= 0; 
            case (tx_state)
                SEND_SYNC: begin
                    tx_data <= 8'hFC; 
                    tx_start <= 1'b1;
                    tx_state <= WAIT_SYNC_TX;
                end
                WAIT_SYNC_TX: begin
                    if (!tx_busy && !tx_start) tx_state <= SEND_CFG;
                end
                SEND_CFG: begin
                    tx_data <= clean_sw; 
                    tx_start <= 1'b1;
                    tx_state <= WAIT_CFG_TX;
                end
                WAIT_CFG_TX: begin
                    if (!tx_busy && !tx_start) begin
                        tx_state <= DELAY;
                        wait_timer <= 0;
                    end
                end
                DELAY: begin
                    if (wait_timer >= WAIT_TIMER_MAX) tx_state <= SEND_SYNC;
                    else wait_timer <= wait_timer + 1;
                end
                default: tx_state <= SEND_SYNC;
            endcase
        end
    end

    // --- 3. RECEIVER ROUTINE (ESP32 -> FPGA) ---
    wire [7:0] uart_rx_data;
    wire uart_rx_done;

    uart_rx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(9600)
    ) controller_rx (
        .clk(clk),
        .rst(rst),
        .rx_pin(rx_pin),
        .rx_data(uart_rx_data),
        .rx_done(uart_rx_done)
    );

    wire [7:0] live_speed;
    wire [7:0] live_status;

    telemetry_parser parser_inst (
        .clk(clk),
        .rst(rst),
        .rx_data(uart_rx_data),
        .rx_done(uart_rx_done),
        .real_speed(live_speed),
        .status_byte(live_status)
    );

    // --- 4. HARDWARE DISPATCH MONITOR ---
    seven_seg_mux dashboard_display (
        .clk(clk),
        .rst(rst),
        .real_speed(live_speed),
        .sw_config(clean_sw),
        .an(an),
        .seg(seg)
    );

endmodule