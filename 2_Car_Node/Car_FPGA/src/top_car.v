module top_car (
    input wire clk,
    input wire rst,
    input wire rx_pin,       // From Car ESP32 (Pin 17)
    
    // Telemetry Pins
    output wire tx_pin,      // To Car ESP32 (Pin 16)
    input wire sensor_pin,   // From KeyesEye Sensor
    
    // Motor Driver Pins
    output wire ena,
    output wire in1,
    output wire in2,
    output wire enb,
    output wire in3,
    output wire in4,
    
    // The Horn Pin
    output wire horn_pin
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

    // --- 5. SPEED ENCODER (KeyesEye) ---
    wire [7:0] real_speed;

    speed_encoder my_encoder (
        .clk(clk),
        .rst(rst),
        .sensor_pin(sensor_pin),
        .real_speed(real_speed)
    );

    // --- 6. TELEMETRY TRANSMITTER (FPGA -> ESP32) ---
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

    // Telemetry State Machine: Send [0xCF, real_speed, status] ~10 times a second
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
                        tx_data <= real_speed; // Byte 2: SPEED
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

    // --- 7. PHYSICAL HARDWARE ROUTING ---
    assign horn_pin = horn_signal;

    // Route the exact same PWM power to both L298N channels
    assign ena = final_pwm;
    assign enb = final_pwm;

    // Direction Logic: Forward = [1, 0], Reverse = [0, 1]
    assign in1 = direction;
    assign in2 = ~direction;
    assign in3 = direction;
    assign in4 = ~direction;

endmodule