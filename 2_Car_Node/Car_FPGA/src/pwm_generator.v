module pwm_generator (
    input wire clk,
    input wire rst,
    input wire [7:0] duty_cycle, // Smoothed 0-100% from the slew_rate_limiter
    output reg pwm_out           // Hardware power pulse to L298N
);

    // 100MHz / 20kHz PWM = 5000 clock cycles per period
    localparam PERIOD_MAX = 5000;
    
    reg [12:0] counter = 0;

    // Multiply percentage by 50 to scale 0-100 to 0-5000
    wire [12:0] threshold;
    assign threshold = duty_cycle * 50; 

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            pwm_out <= 0;
        end else begin
            counter <= counter + 1;
            
            // Reset counter at the end of the period
            if (counter == PERIOD_MAX - 1) begin
                counter <= 0;
            end
            
            // Generate the square wave based on the threshold
            if (counter < threshold) begin
                pwm_out <= 1;
            end else begin
                pwm_out <= 0;
            end
        end
    end
endmodule