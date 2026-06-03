module top_controller (
    input  wire clk,
    input  wire rst_btn,       // Hardware Reset (SW0)
    
    // Physical Dashboard Inputs
    input  wire paddle_up,     // Right Crash Detector OUT
    input  wire paddle_down,   // Left Crash Detector OUT
    input  wire [1:0] sw_sens, // Switches for Steering Sensitivity
    input  wire [1:0] sw_throt,// Switches for Throttling Profile
    
    // UART Communication with Controller ESP32
    input  wire rx_pin,        // From ESP32 TX2 (Pin 17) -> Receives Telemetry
    output wire tx_out,        // To ESP32 RX2 (Pin 16) -> Sends Config Byte
    
    // 7-Segment Display Outputs
    output wire [7:0] an,      // Anodes
    output wire [6:0] seg      // Cathodes
);

    // ==========================================
    // 1. DASHBOARD LOGIC (The "ECU")
    // ==========================================
    wire [1:0] current_speed_mode;
    wire [7:0] config_byte;
    
    // Pack the configuration bits for the ESP32
    assign config_byte = {2'b00, sw_throt, sw_sens, current_speed_mode};

    transmission_control gearbox (
        .clk(clk),
        .rst(rst_btn),
        .paddle_up_raw(paddle_up),
        .paddle_down_raw(paddle_down),
        .speed_mode(current_speed_mode)
    );

    // ==========================================
    // 2. UART RECEPTION (ESP32 -> FPGA)
    // ==========================================
    wire [7:0] rx_data_stream;
    wire rx_done_pulse;
    wire [7:0] car_real_speed;
    wire [7:0] car_status;

    uart_rx my_uart_rx (
        .clk(clk), .rst(rst_btn),
        .rx_pin(rx_pin), 
        .rx_data(rx_data_stream), .rx_done(rx_done_pulse)
    );

    telemetry_parser my_parser (
        .clk(clk), .rst(rst_btn),
        .rx_data(rx_data_stream), .rx_done(rx_done_pulse),
        .real_speed(car_real_speed), .status_byte(car_status)
    );

    // ==========================================
    // 3. 7-SEGMENT DISPLAY
    // ==========================================
    seven_seg_mux dashboard_display (
        .clk(clk),
        .rst(rst_btn),
        .real_speed(car_real_speed),
        .sw_config(config_byte), // Displays Throttling, Sensitivity, and Gear
        .an(an),
        .seg(seg)
    );

    // ==========================================
    // 4. UART TRANSMISSION (FPGA -> ESP32)
    // ==========================================
    reg tx_start = 0;
    reg [7:0] tx_data = 0;
    wire tx_busy;
    
    // Broadcast Timer: Send commands to ESP32 ~20 times a second
    reg [22:0] broadcast_timer = 0; 
    localparam BROADCAST_RATE = 5_000_000; // 50ms at 100MHz
    localparam INTER_BYTE_GAP = 100_000;   // 1ms gap between bytes
    
    reg [2:0] tx_state = 0;

    always @(posedge clk or posedge rst_btn) begin
        if (rst_btn) begin
            tx_state <= 0;
            tx_start <= 0;
            broadcast_timer <= 0;
        end else begin
            case (tx_state)
                0: begin // Wait for the 50ms timer
                    tx_start <= 0;
                    if (broadcast_timer >= BROADCAST_RATE) begin
                        broadcast_timer <= 0;
                        tx_data <= 8'hFC; // 1st Byte: SYNC
                        tx_state <= 1;
                    end else begin
                        broadcast_timer <= broadcast_timer + 1;
                    end
                end
                
                1: begin // Trigger SYNC byte
                    tx_start <= 1;
                    if (tx_busy) begin
                        tx_start <= 0; 
                        tx_state <= 2;
                    end
                end

                2: begin // Wait for SYNC byte to finish transmitting
                    if (!tx_busy) begin
                        broadcast_timer <= 0; // Reset timer for the breather gap
                        tx_state <= 3;
                    end
                end

                3: begin // THE 1-MILLISECOND BREATHER GAP
                    if (broadcast_timer >= INTER_BYTE_GAP) begin
                        tx_data <= config_byte; // Load 2nd Byte: DASHBOARD CONFIG
                        tx_state <= 4;
                    end else begin
                        broadcast_timer <= broadcast_timer + 1;
                    end
                end

                4: begin // Trigger CONFIG byte
                    tx_start <= 1;
                    if (tx_busy) begin
                        tx_start <= 0;
                        tx_state <= 5;
                    end
                end

                5: begin // Wait for CONFIG byte to finish
                    if (!tx_busy) begin
                        tx_state <= 0; // Done! Return to idle timer.
                    end
                end
            endcase
        end
    end

    uart_tx my_uart_tx (
        .clk(clk), .rst(rst_btn),
        .tx_start(tx_start), .tx_data(tx_data),
        .tx_pin(tx_out), .tx_busy(tx_busy)
    );

endmodule