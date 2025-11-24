module mnist_vga_top (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,

    // Arduino pins
    input  wire        serial_data_in,   // D2
    input  wire        bit_clk_in,       // D3
    input  wire        frame_start_in,   // D4

    // VGA outputs
    output wire [7:0]  VGA_R,
    output wire [7:0]  VGA_G,
    output wire [7:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N,
    output wire        VGA_CLK
);

    wire resetn         = KEY[0];      // active-low reset
    wire display_button = ~KEY[1];     // active-high "start blit"

    // Shared frame RAM
    wire        ram_we_a;
    wire [9:0]  ram_addr_a;
    wire [7:0]  ram_din_a;

    wire [9:0]  ram_addr_b;
    wire [7:0]  ram_dout_b;

    mnist_frame_ram frame_ram (
        .clk    (CLOCK_50),
        .we_a   (ram_we_a),
        .addr_a (ram_addr_a),
        .din_a  (ram_din_a),
        .addr_b (ram_addr_b),
        .dout_b (ram_dout_b)
    );

    // Arduino capture (writer on Port A)
    wire frame_ready;

    arduino_mnist_capture capture (
        .clk            (CLOCK_50),
        .resetn         (resetn),
        .serial_data_in (serial_data_in),
        .bit_clk_in     (bit_clk_in),
        .frame_start_in (frame_start_in),
        .ram_we         (ram_we_a),
        .ram_addr       (ram_addr_a),
        .ram_din        (ram_din_a),
        .frame_ready    (frame_ready)
    );

    // VGA blitter (reader on Port B)
    wire [9:0] vga_x;
    wire [8:0] vga_y;
    wire [8:0] vga_color;
    wire       vga_write;
    wire       blit_busy;

    vga_image_blitter #(
        .BASE_X(10'd0),
        .BASE_Y(9'd0)
    ) blitter (
        .clk         (CLOCK_50),
        .resetn      (resetn),
        .start       (display_button),
        .frame_ready (frame_ready),
        .ram_addr_b  (ram_addr_b),
        .ram_data_b  (ram_dout_b),
        .vga_x       (vga_x),
        .vga_y       (vga_y),
        .vga_color   (vga_color),
        .vga_write   (vga_write),
        .busy        (blit_busy)
    );

    // Existing VGA adapter (unaltered files)
    vga_adapter #(
        .RESOLUTION      ("640x480"),
        .COLOR_DEPTH     (9),
        .BACKGROUND_IMAGE("rainbow_640_9.mif")
    ) vga (
        .resetn      (resetn),
        .clock       (CLOCK_50),
        .color       (vga_color),
        .x           (vga_x),
        .y           (vga_y),
        .write       (vga_write),
        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N),
        .VGA_CLK     (VGA_CLK)
    );

endmodule
