module top_car (
    input wire clk,
    input wire rst,
    input wire rx_pin,       // From Car ESP32 (Pin 17)
    
    // Motor Driver Pins (Both channels mirroring to the rear axle)
    output wire ena,
    output wire in1,
    output wire in2,
    output wire enb,
    output wire in3,
    output wire in4,
    
    // The Horn Pin (Connect to an active buzzer on a Pmod)
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
    wire final_pwm;           // The physical square wave

    // --- 1. UART RECEIVER ---
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

    // --- 4. PWM GENERATOR ---
    pwm_generator my_pwm (
        .clk(clk),
        .rst(rst),
        .duty_cycle(current_speed), // Feed it the smoothed speed, not the target!
        .pwm_out(final_pwm)
    );

    // --- 5. PHYSICAL HARDWARE ROUTING ---
    // Horn: Assuming an active buzzer (High = Beep, Low = Silent)
    assign horn_pin = horn_signal;

    // Route the exact same PWM power to both L298N channels for max torque
    assign ena = final_pwm;
    assign enb = final_pwm;

    // Direction Logic: Forward = [1, 0], Reverse = [0, 1]
    assign in1 = direction;
    assign in2 = ~direction;
    assign in3 = direction;
    assign in4 = ~direction;

endmodule