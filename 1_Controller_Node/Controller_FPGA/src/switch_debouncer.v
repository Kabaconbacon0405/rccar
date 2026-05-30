module switch_debouncer #(
    parameter WIDTH = 8,
    parameter DEBOUNCE_TIME = 1_000_000 // 10ms at 100MHz clock
)(
    input wire clk,
    input wire rst,
    input wire [WIDTH-1:0] sw_in,
    output reg [WIDTH-1:0] sw_out
);
    
    // Double-flop synchronizer to prevent metastability from physical inputs
    reg [WIDTH-1:0] sync_0, sync_1;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync_0 <= 0; 
            sync_1 <= 0;
        end else begin
            sync_0 <= sw_in;
            sync_1 <= sync_0;
        end
    end

    reg [20:0] counter = 0;
    reg [WIDTH-1:0] sw_state = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            sw_state <= 0;
            sw_out <= 0;
        end else begin
            // If the switch input changes, start counting
            if (sw_state != sync_1) begin
                counter <= counter + 1;
                
                // If it stays stable for 10ms, lock in the new value
                if (counter >= DEBOUNCE_TIME) begin
                    sw_state <= sync_1;
                    sw_out <= sync_1;
                    counter <= 0;
                end
            end else begin
                counter <= 0; // Reset counter if it bounced
            end
        end
    end
endmodule