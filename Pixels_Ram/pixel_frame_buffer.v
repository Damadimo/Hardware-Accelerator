// Serial 1-bit interface -> 28x28 (784-byte) frame buffer
// Assumes: 1 bit per clock, LSB-first for each pixel byte.

module serial_pixel_frame_buffer #(
    parameter WIDTH      = 28,
    parameter HEIGHT     = 28,
    parameter NUM_PIXELS = WIDTH * HEIGHT
)(
    // From Arduino
    input  wire        bit_clk,       // 1 clock pulse per *bit*
    input  wire        frame_start,   // pulse/high at start of frame
    input  wire        serial_data,   // 1-bit data line from Arduino

    // Status
    output reg         frame_done,    // 1-cycle pulse when full frame received

    // Read port for inference logic (same clock domain for now)
    input  wire        rd_en,
    input  wire [9:0]  rd_addr,       // 0..783
    output reg  [7:0]  rd_data
);

    // 28x28 = 784 bytes
    (* ram_style = "block" *) reg [7:0] frame_mem [0:NUM_PIXELS-1];

    reg [9:0] wr_addr   = 10'd0;  // which pixel we're writing (0..783)
    reg [2:0] bit_cnt   = 3'd0;   // counts bits 0..7 within a pixel
    reg [7:0] shift_reg = 8'd0;   // builds up a pixel byte

    // --- WRITE SIDE: shift in bits and store full pixels into RAM ---
    // Assumes LSB-first: Arduino sends bit0, bit1, ..., bit7.
    // We reconstruct using a right-shift with new bit inserted as MSB.
    //
    // On each bit_clk:
    //   next_shift = {serial_data, shift_reg[7:1]};
    // After 8 bits, next_shift == original pixel byte.
    //
    always @(posedge bit_clk or posedge frame_start) begin
        if (frame_start) begin
            // Start of new frame
            wr_addr    <= 10'd0;
            bit_cnt    <= 3'd0;
            shift_reg  <= 8'd0;
            frame_done <= 1'b0;
        end else begin
            // Compute next shift value with new incoming bit
            // Insert incoming bit as MSB, shift right
            // (This matches LSB-first sending from Arduino)
            shift_reg <= {serial_data, shift_reg[7:1]};

            if (bit_cnt == 3'd7) begin
                // We just received the 8th bit -> full pixel ready
                // Note: use the "new" value that includes this bit
                //       which is {serial_data, shift_reg[7:1]}
                frame_mem[wr_addr] <= {serial_data, shift_reg[7:1]};

                bit_cnt <= 3'd0;

                if (wr_addr == NUM_PIXELS-1) begin
                    // Last pixel of the frame
                    wr_addr    <= 10'd0;   // wrap (or you can hold if you prefer)
                    frame_done <= 1'b1;    // 1-cycle pulse
                end else begin
                    wr_addr    <= wr_addr + 10'd1;
                    frame_done <= 1'b0;
                end
            end else begin
                // Still in the middle of this pixel
                bit_cnt    <= bit_cnt + 3'd1;
                frame_done <= 1'b0;
            end
        end
    end

    // --- READ SIDE: simple synchronous read on same clock ---
    // For now we use bit_clk as read clock too.
    // If your inference runs on a different clock, you’ll adapt this
    // to a dual-clock RAM or add CDC later.
    always @(posedge bit_clk) begin
        if (rd_en) begin
            rd_data <= frame_mem[rd_addr];
        end
    end

endmodule
