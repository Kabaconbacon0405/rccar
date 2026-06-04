module speed_encoder (
    input  wire       clk,         // 100 MHz system clock
    input  wire       rst,         // synchronous reset (active high)
    input  wire       sensor_pin,  // raw async OUT from KeyesEye IR encoder
    output reg  [7:0] real_speed   // pulses counted during the last 100 ms window
);

    // =========================================================================
    // 1. TWO-STAGE FLIP-FLOP SYNCHRONIZER (+ edge-detect delay flop)
    // -------------------------------------------------------------------------
    //   sync_0 : first capture of the asynchronous pin (may be metastable)
    //   sync_1 : metastability resolved -> clean, clock-aligned sensor level
    //   sync_q : sync_1 delayed by one clock, used only for edge detection
    //   A rising edge is "high now (sync_1) AND low one clock ago (sync_q)",
    //   which guarantees exactly one count per physical pulse.
    // =========================================================================
    reg sync_0 = 1'b0;
    reg sync_1 = 1'b0;
    reg sync_q = 1'b0;

    always @(posedge clk) begin
        sync_0 <= sensor_pin;
        sync_1 <= sync_0;
        sync_q <= sync_1;
    end

    wire pulse_edge = sync_1 & ~sync_q;   // one-clock pulse per rising edge

    // =========================================================================
    // 2. 100 ms GATING WINDOW
    // -------------------------------------------------------------------------
    //   100 MHz * 100 ms = 10,000,000 clock cycles.
    //   Minimum width = ceil(log2(10,000,000)) = 24 bits (max 16,777,215).
    //   We use 27 bits for generous headroom so the window can never overflow
    //   and can be re-tuned later without touching the bit-width.
    // =========================================================================
    localparam [26:0] WINDOW_MAX = 27'd10_000_000;   // 100 ms @ 100 MHz

    reg [26:0] win_timer   = 27'd0;
    reg [7:0]  pulse_accum = 8'd0;

    always @(posedge clk) begin
        if (rst) begin
            win_timer   <= 27'd0;
            pulse_accum <= 8'd0;
            real_speed  <= 8'd0;
        end else if (win_timer >= (WINDOW_MAX - 1)) begin
            // ---- END OF WINDOW : latch THEN reset accumulator ----
            real_speed  <= pulse_accum;                 // 3. safe latch of count
            // Seed the next window with an edge that happens to land on this
            // exact boundary cycle, so no pulse is ever lost at the seam.
            pulse_accum <= pulse_edge ? 8'd1 : 8'd0;
            win_timer   <= 27'd0;
        end else begin
            win_timer <= win_timer + 1'b1;
            if (pulse_edge && (pulse_accum != 8'd255))
                pulse_accum <= pulse_accum + 1'b1;       // saturate, no wrap
        end
    end

endmodule
