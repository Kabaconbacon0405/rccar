module top_car (
    input wire clk,
    input wire rst,
    input wire rx_pin,       // From Car ESP32 (Pin 17)
    
    // Telemetry Pin
    output wire tx_pin,      // To Car ESP32 (Pin 16)

    // Motor Driver Pins
    output wire ena,
    output wire in1,
    output wire in2,
    output wire enb,
    output wire in3,
    output wire in4,
    
    // The Horn Pin (direct-drive speaker on Pmod JC Pin 1 / K1 — no transistor)
    output wire horn_pin,

    // 7-segment display: live PWM duty on the right 3 digits (e.g. 100/90/80)
    output wire [6:0] seg,
    output wire [7:0] an
);

    // --- INTERNAL WIRES ---
    wire [7:0] uart_data;
    wire uart_done;
    
    wire [7:0] target_speed;
    wire [1:0] throttling_mode;
    wire direction;
    wire horn_signal;
    
    wire [7:0] current_speed; // The smoothed output from the limiter
    wire final_pwm;           // The single physical square wave

    // --- 1. UART RECEIVER (ESP32 -> FPGA) ---
    uart_rx #(
        .CLK_FREQ(100_000_000), 
        .BAUD_RATE(9600)
    ) my_uart (
        .clk(clk),
        .rst(rst),
        .rx_pin(rx_pin),
        .rx_data(uart_data),
        .rx_done(uart_done)
    );

    // --- 2. THE PACKET PARSER ---
    car_fsm my_fsm (
        .clk(clk),
        .rst(rst),
        .rx_data(uart_data),
        .rx_done(uart_done),
        .target_speed(target_speed),
        .throttling(throttling_mode),
        .direction(direction),
        .horn(horn_signal)
    );

    // --- 3. ACCELERATION CURVE (Throttling) ---
    slew_rate_limiter my_limiter (
        .clk(clk),
        .rst(rst),
        .target_speed(target_speed),
        .throttling(throttling_mode),
        .current_speed(current_speed)
    );

    // --- 4. UNIFIED PWM GENERATOR ---
    pwm_generator my_pwm (
        .clk(clk),
        .rst(rst),
        .duty_cycle(current_speed), // Feeds the exact same speed to both wheels
        .pwm_out(final_pwm)
    );

    // --- 5. TELEMETRY TRANSMITTER (FPGA -> ESP32) ---
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;

    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(9600)
    ) my_telemetry_tx (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_pin(tx_pin),
        .tx_busy(tx_busy)
    );

    // Telemetry State Machine: Send [0xCF, current_speed, status] ~10 times a second.
    // (The IR speed sensor was removed, so we report the commanded PWM duty.)
    reg [23:0] telem_timer = 0;
    localparam TELEM_RATE = 10_000_000;  // 100ms window
    localparam INTER_BYTE_GAP = 100_000; // 1ms breather gap between bytes
    reg [3:0] tx_state = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_state <= 0;
            tx_start <= 0;
            telem_timer <= 0;
        end else begin
            case (tx_state)
                0: begin // Wait 100ms to sample speed
                    tx_start <= 0;
                    if (telem_timer >= TELEM_RATE) begin
                        telem_timer <= 0;
                        tx_data <= 8'hCF; // Byte 1: SYNC
                        tx_state <= 1;
                    end else begin
                        telem_timer <= telem_timer + 1;
                    end
                end

                1: begin // Send SYNC
                    tx_start <= 1;
                    if (tx_busy) begin
                        tx_start <= 0;
                        tx_state <= 2;
                    end
                end

                2: begin // Wait for SYNC to finish
                    if (!tx_busy) begin
                        telem_timer <= 0; 
                        tx_state <= 3;
                    end
                end

                3: begin // 1ms Gap
                    if (telem_timer >= INTER_BYTE_GAP) begin
                        tx_data <= current_speed; // Byte 2: SPEED (commanded duty)
                        tx_state <= 4;
                    end else begin
                        telem_timer <= telem_timer + 1;
                    end
                end

                4: begin // Send SPEED
                    tx_start <= 1;
                    if (tx_busy) begin
                        tx_start <= 0;
                        tx_state <= 5;
                    end
                end

                5: begin // Wait for SPEED to finish
                    if (!tx_busy) begin
                        telem_timer <= 0;
                        tx_state <= 6;
                    end
                end

                6: begin // 1ms Gap
                    if (telem_timer >= INTER_BYTE_GAP) begin
                        tx_data <= 8'd1; // Byte 3: STATUS (Hardcoded to 1 = OK for now)
                        tx_state <= 7;
                    end else begin
                        telem_timer <= telem_timer + 1;
                    end
                end

                7: begin // Send STATUS
                    tx_start <= 1;
                    if (tx_busy) begin
                        tx_start <= 0;
                        tx_state <= 8;
                    end
                end

                8: begin // Wait for STATUS to finish
                    if (!tx_busy) begin
                        tx_state <= 0; // Done! Back to waiting for the next 100ms tick.
                    end
                end
            endcase
        end
    end

    // --- 6b. 7-SEGMENT PWM DISPLAY (right 3 digits show current_speed) ---
    seven_seg_car my_display (
        .clk(clk),
        .rst(rst),
        .value(current_speed),   // live PWM duty fed to pwm_generator
        .seg(seg),
        .an(an)
    );

    // --- 7. HORN PWM BEEP GENERATOR (Lab 7 direct-drive) ---
    // car_horn produces a fixed 2.4 kHz square wave while horn_active is high,
    // and forces the pin to 0 when the horn bit (command_byte[3], decoded by
    // car_fsm as horn_signal) is low so the speaker never floats with a DC
    // bias / hum. Output now drives the speaker directly from Pmod JC Pin 1
    // (K1) — the external breadboard transistor circuit is no longer used.
    car_horn my_horn (
        .clk(clk),
        .horn_active(horn_signal),
        .horn_pwm(horn_pin)
    );

    // --- 8. PHYSICAL HARDWARE ROUTING ---

    // Route the exact same PWM power to both L298N channels
    assign ena = final_pwm;
    assign enb = final_pwm;

    // Direction Logic: Forward = [1, 0], Reverse = [0, 1]
    assign in1 = direction;
    assign in2 = ~direction;
    assign in3 = direction;
    assign in4 = ~direction;

endmodule