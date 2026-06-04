module car_horn (
    input wire clk,         // 100MHz system clock
    input wire horn_active, // Triggered by the ESP32 joystick button packet
    output reg horn_pwm     // Output to Pmod JC, Pin 1 (K1)
);

    // 20833 cycles = 2.4 kHz (Crisp electronic beep)
    // Alternative: 113636 cycles = 440 Hz (Deeper, classic car horn tone)
    localparam TONE_LIMIT = 32'd20833;

    reg [31:0] clk_counter = 0;

    always @(posedge clk) begin
        if (!horn_active) begin
            clk_counter <= 0;
            horn_pwm    <= 1'b0; // Force silence when button is released
        end else begin
            if (clk_counter >= TONE_LIMIT) begin
                clk_counter <= 0;
                horn_pwm    <= ~horn_pwm; // Toggle to create the perfect audio wave
            end else begin
                clk_counter <= clk_counter + 1;
            end
        end
    end

endmodule
