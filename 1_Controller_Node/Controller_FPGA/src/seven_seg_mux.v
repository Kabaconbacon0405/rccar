module seven_seg_mux (
    input wire clk,
    input wire rst,
    input wire [7:0] real_speed, // 0 - 100
    input wire [7:0] sw_config,  // Raw clean switch inputs for configuration data
    output reg [7:0] an,         // Anodes (Active LOW: 0 = ON)
    output reg [6:0] seg         // Cathodes CA-CG (Active LOW: 0 = ON)
);

    // Unpack configuration states from local switches
    wire [1:0] top_speed   = sw_config[1:0];
    wire [1:0] sensitivity = sw_config[3:2];
    wire [1:0] throttling  = sw_config[5:4];
    wire       record_mode = sw_config[6];
    wire       play_mode   = sw_config[7];
    
    // Direction inference: direction bit is mapped inside our top-level control logic
    // For simplicity, we can decode direction via telemetry status or layout if needed.
    // Here we deduce it from local state or placeholder (Assume Forward 'F' for now)

    // 1. Binary to BCD (Binary Coded Decimal) Engine for Speed (0-100)
    reg [3:0] bcd_hundreds, bcd_tens, bcd_ones;
    always @(*) begin
        bcd_hundreds = real_speed / 100;
        bcd_tens     = (real_speed % 100) / 10;
        bcd_ones     = real_speed % 10;
    end

    // 2. Refresh Counter for Multiplexing
    // 100MHz / 2^16 = ~1.5kHz refresh rate per digit scanning cycle
    reg [15:0] refresh_counter = 0;
    always @(posedge clk or posedge rst) begin
        if (rst) refresh_counter <= 0;
        else refresh_counter <= refresh_counter + 1;
    end
    wire [2:0] active_digit = refresh_counter[15:13];

    // 3. Anode Decoding (Select exactly one display pin to ground)
    always @(*) begin
        if (rst) an = 8'b11111111;
        else begin
            case (active_digit)
                3'd0: an = 8'b11111110; // Digit 0: Macro Status
                3'd1: an = 8'b11111101; // Digit 1: Throttling
                3'd2: an = 8'b11111011; // Digit 2: Sensitivity
                3'd3: an = 8'b11110111; // Digit 3: Max Speed Limit
                3'd4: an = 8'b11101111; // Digit 4: Direction Indication
                3'd5: an = 8'b11011111; // Digit 5: Speed Ones
                3'd6: an = 8'b10111111; // Digit 6: Speed Tens
                3'd7: an = 8'b01111111; // Digit 7: Speed Hundreds
            endcase
        end
    end

    // 4. Character Mapping to Cathodes (Active LOW, 0=ON, 1=OFF)
    reg [3:0] hex_digit;
    reg [6:0] custom_char;
    reg use_custom;

    always @(*) begin
        use_custom = 1'b0;
        hex_digit = 4'h0;
        custom_char = 7'b1111111; // All segments off

        case (active_digit)
            3'd0: begin // Macro status
                use_custom = 1'b1;
                if (play_mode)        custom_char = 7'b0001100; // 'P'
                else if (record_mode) custom_char = 7'b1111010; // 'r'
                else                  custom_char = 7'b1110111; // '_'
            end
            3'd1: hex_digit = {2'b00, throttling};
            3'd2: hex_digit = {2'b00, sensitivity};
            3'd3: hex_digit = {2'b00, top_speed};
            3'd4: begin // Direction Character
                use_custom = 1'b1;
                custom_char = 7'b0001110; // Default 'F' for Forward
            end
            3'd5: hex_digit = bcd_ones;
            3'd6: hex_digit = bcd_tens;
            3'd7: hex_digit = bcd_hundreds;
        endcase
    end

    // 7-Segment Hex Decoder
    always @(*) begin
        if (use_custom) begin
            seg = custom_char;
        end else begin
            case (hex_digit)
                4'h0: seg = 7'b1000000; // 0
                4'h1: seg = 7'b1111001; // 1
                4'h2: seg = 7'b0100100; // 2
                4'h3: seg = 7'b0110000; // 3
                4'h4: seg = 7'b0011001; // 4
                4'h5: seg = 7'b0010010; // 5
                4'h6: seg = 7'b0000010; // 6
                4'h7: seg = 7'b1111000; // 7
                4'h8: seg = 7'b0000000; // 8
                4'h9: seg = 7'b0010000; // 9
                default: seg = 7'b1111111; // Blank
            endcase
        end
    end
endmodule