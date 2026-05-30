module slew_rate_limiter (
    input wire clk,
    input wire rst,
    input wire [7:0] target_speed, // 0-100 from the car_fsm
    input wire [1:0] throttling,   // 00=Instant, 01=Fast, 10=Smooth, 11=Slow
    
    output reg [7:0] current_speed // 0-100 smoothed output to pwm_generator
);

    // A 20-bit timer is required to count up to 1,000,000
    reg [19:0] timer = 0;
    reg [19:0] step_limit;

    // --- COMBINATIONAL LOGIC ---
    // Instantly update the target step_limit if the user changes the mode
    always @(*) begin
        case (throttling)
            2'b00: step_limit = 20'd0;         // Instant (Bypassed)
            2'b01: step_limit = 20'd250_000;   // Fast   (2.5 ms per step)
            2'b10: step_limit = 20'd500_000;   // Smooth (5.0 ms per step)
            2'b11: step_limit = 20'd1_000_000; // Slow   (10.0 ms per step)
            default: step_limit = 20'd0;
        endcase
    end

    // --- SEQUENTIAL LOGIC ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_speed <= 8'd0;
            timer <= 20'd0;
        end else begin
            
            // Mode 0: Bypass the limiter entirely
            if (throttling == 2'b00) begin
                current_speed <= target_speed;
                timer <= 20'd0;
            end 
            // Modes 1, 2, 3: Engage the hardware limiter
            else begin
                timer <= timer + 1;
                
                // When the timer hits the mathematical delay...
                if (timer >= step_limit) begin
                    timer <= 20'd0; // Reset timer for the next step
                    
                    // Nudge the current speed exactly 1 unit closer to the target
                    if (current_speed < target_speed) begin
                        current_speed <= current_speed + 1;
                    end else if (current_speed > target_speed) begin
                        current_speed <= current_speed - 1;
                    end
                end
            end
            
        end
    end
endmodule