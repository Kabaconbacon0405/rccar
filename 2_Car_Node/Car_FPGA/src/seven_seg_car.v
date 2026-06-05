module seven_seg_car (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] value,    // 0-100 PWM duty to show (current_speed)
    output reg  [6:0] seg,      // active-low cathodes  {CG..CA}, seg[0]=CA
    output reg  [7:0] an        // active-low anodes,    an[0] = rightmost digit
);

    // --- Binary -> BCD (constant divisors synthesize cleanly) ---
    wire [3:0] ones     =  value        % 10;
    wire [3:0] tens     = (value / 10)  % 10;
    wire [3:0] hundreds =  value / 100;

    // --- Refresh / digit scan (~95 Hz per digit, flicker-free) ---
    reg [19:0] refresh = 0;
    always @(posedge clk or posedge rst) begin
        if (rst) refresh <= 0;
        else     refresh <= refresh + 1'b1;
    end
    wire [2:0] sel = refresh[19:17];

    // --- Select the active digit (only the rightmost 3 are used) ---
    reg [3:0] digit;
    reg       blank;
    always @(*) begin
        digit = 4'd0;
        blank = 1'b0;
        an    = 8'b1111_1111;                 // all digits off by default
        case (sel)
            3'd0: begin an = 8'b1111_1110; digit = ones;     blank = 1'b0;                  end // AN0 ones
            3'd1: begin an = 8'b1111_1101; digit = tens;     blank = (hundreds==0 && tens==0); end // AN1 tens
            3'd2: begin an = 8'b1111_1011; digit = hundreds; blank = (hundreds==0);          end // AN2 hundreds
            default: an = 8'b1111_1111;       // AN3..AN7 stay blank
        endcase
    end

    // --- Decimal digit -> 7-segment pattern (active-low) ---
    always @(*) begin
        if (blank) begin
            seg = 7'b1111111;                 // all segments off
        end else begin
            case (digit)
                4'd0: seg = 7'b1000000;
                4'd1: seg = 7'b1111001;
                4'd2: seg = 7'b0100100;
                4'd3: seg = 7'b0110000;
                4'd4: seg = 7'b0011001;
                4'd5: seg = 7'b0010010;
                4'd6: seg = 7'b0000010;
                4'd7: seg = 7'b1111000;
                4'd8: seg = 7'b0000000;
                4'd9: seg = 7'b0010000;
                default: seg = 7'b1111111;
            endcase
        end
    end

endmodule
