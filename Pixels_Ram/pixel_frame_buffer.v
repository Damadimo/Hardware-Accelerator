module pixel_frame_buffer #(
    parameter WIDTH  = 28,
    parameter HEIGHT = 28,
    parameter NUM_PIXELS = WIDTH * HEIGHT
)(
    // From Arduino
    input  wire        pix_clk,      // pixel clock from Arduino (one pulse per pixel)
    input  wire        frame_start,  // asserted HIGH at the beginning of a frame
    input  wire [7:0]  data_in,      // grayscale pixel value

    // Status
    output reg         frame_done,   // goes HIGH for one pix_clk cycle when frame is complete

    // Read port for inference logic (same clock domain as pix_clk for now)
    input  wire        rd_en,        // read enable
    input  wire [9:0]  rd_addr,      // address 0..NUM_PIXELS-1
    output reg  [7:0]  rd_data       // pixel value at rd_addr
);

    // Hint for synthesis: implement as block RAM if possible
    (* ram_style = "block" *) reg [7:0] frame_mem [0:NUM_PIXELS-1];

    reg [9:0] wr_addr = 10'd0;  // write address (0..783)

    // --- WRITE SIDE: capture pixels from Arduino into RAM ---
    always @(posedge pix_clk or posedge frame_start) begin
        if (frame_start) begin
            // New frame is starting: reset write pointer and clear flag
            wr_addr    <= 10'd0;
            frame_done <= 1'b0;
        end else begin
            // Write incoming pixel into memory
            frame_mem[wr_addr] <= data_in;

            // Move to next address
            if (wr_addr == NUM_PIXELS-1) begin
                // Last pixel received
                frame_done <= 1'b1;   // one-cycle pulse
                wr_addr    <= 10'd0;  // wrap or hold, depending on your preference
            end else begin
                wr_addr    <= wr_addr + 10'd1;
                frame_done <= 1'b0;
            end
        end
    end

    // --- READ SIDE: inference logic reads pixels by address ---
    // Simple synchronous read using the same clock (pix_clk).
    // If your inference logic uses a different clock, you’ll want
    // to adapt this to a dual-clock RAM or add proper CDC.
    always @(posedge pix_clk) begin
        if (rd_en) begin
            rd_data <= frame_mem[rd_addr];
        end
    end

endmodule
