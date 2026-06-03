module speed_encoder (
    input wire clk,          // 100MHz system clock
    input wire rst,          // Reset button
    input wire sensor_pin,   // The OUT pin from the KeyesEye sensor
    output reg [7:0] real_speed
);

    // ==========================================
    // 1. HARDWARE SYNCHRONIZER & DEBOUNCER
    // (Prevents physical electrical noise from crashing the FPGA)
    // ==========================================
    reg sync_1 = 0, sync_2 = 0, sync_3 = 0;
    always @(posedge clk) begin
        sync_1 <= sensor_pin;
        sync_2 <= sync_1;
        sync_3 <= sync_2;
    end

    wire pulse_detected = (sync_2 && !sync_3);

    // ==========================================
    // 2. THE 100ms SPEEDOMETER WINDOW
    // ==========================================
    localparam WINDOW_MAX = 24'd10_000_000;

    reg [23:0] timer = 0;
    reg [7:0] pulse_count = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            timer <= 0;
            pulse_count <= 0;
            real_speed <= 0;
        end else begin
            if (timer >= WINDOW_MAX) begin
                real_speed <= pulse_count;
                pulse_count <= 0;
                timer <= 0;
            end else begin
                timer <= timer + 1;
                if (pulse_detected) begin
                    if (pulse_count < 8'd255) begin
                        pulse_count <= pulse_count + 1;
                    end
                end
            end
        end
    end
endmodule
