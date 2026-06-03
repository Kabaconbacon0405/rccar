module transmission_control (
    input wire clk,
    input wire rst,
    input wire paddle_up_raw,   // Noisy input from right crash detector
    input wire paddle_down_raw, // Noisy input from left crash detector
    output reg [1:0] speed_mode // Clean output to the config byte
);

    // --- 1. DEBOUNCER ---
    wire [1:0] clean_paddles;
    wire up_clean = clean_paddles[1];
    wire down_clean = clean_paddles[0];

    // Instantiate your existing switch_debouncer for both paddles simultaneously
    switch_debouncer #( .WIDTH(2), .DEBOUNCE_TIME(1_000_000) ) debouncer (
        .clk(clk),
        .rst(rst),
        .sw_in({paddle_up_raw, paddle_down_raw}),
        .sw_out(clean_paddles)
    );

    // --- 2. EDGE DETECTION ---
    reg up_prev = 0;
    reg down_prev = 0;
    wire up_pulse;
    wire down_pulse;

    always @(posedge clk) begin
        up_prev <= up_clean;
        down_prev <= down_clean;
    end
    
    // Generates exactly one HIGH clock cycle when the button is pressed down
    assign up_pulse = up_clean & ~up_prev;
    assign down_pulse = down_clean & ~down_prev;

    // --- 3. GEAR SHIFTER FSM ---
    reg [1:0] current_gear;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_gear <= 2'd1; // Start in 1st Gear safely
            speed_mode <= 2'b01;  // 50% Speed
        end else begin
            // Shift Up (Cap at 3rd Gear)
            if (up_pulse && current_gear < 2'd3) begin
                current_gear <= current_gear + 1;
            end 
            // Shift Down (Floor at 1st Gear)
            else if (down_pulse && current_gear > 2'd1) begin
                current_gear <= current_gear - 1;
            end

            // Map Physical Gear to ESP32 Speed Mode logic
            case (current_gear)
                2'd1: speed_mode <= 2'b01; // 1st Gear -> 50% Top Speed
                2'd2: speed_mode <= 2'b10; // 2nd Gear -> 75% Top Speed
                2'd3: speed_mode <= 2'b11; // 3rd Gear -> 100% Top Speed
                default: speed_mode <= 2'b01; 
            endcase
        end
    end
endmodule