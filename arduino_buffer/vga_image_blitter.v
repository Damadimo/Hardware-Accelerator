module vga_image_blitter #(
    parameter BASE_X = 10'd0,  // top-left X on screen
    parameter BASE_Y = 9'd0    // top-left Y on screen
)(
    input  wire       clk,
    input  wire       resetn,

    input  wire       start,        // e.g. button: "copy to VGA now"
    input  wire       frame_ready,  // ensure valid frame in RAM

    // RAM read port (Port B of mnist_frame_ram)
    output reg  [9:0] ram_addr_b,   // 0..783
    input  wire [7:0] ram_data_b,   // 8-bit grayscale

    // Interface to vga_adapter
    output reg  [9:0] vga_x,
    output reg  [8:0] vga_y,
    output reg  [8:0] vga_color,
    output reg        vga_write,
    output reg        busy          // optional: high while copying
);

    // Start edge detect
    reg [1:0] start_sync;
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            start_sync <= 2'b00;
        else
            start_sync <= {start_sync[0], start};
    end
    wire start_rising = (start_sync == 2'b01);

    // FSM
    localparam S_IDLE     = 2'd0;
    localparam S_SET_ADDR = 2'd1;
    localparam S_WRITE    = 2'd2;

    reg [1:0] state;

    reg [4:0] col;   // 0..27
    reg [4:0] row;   // 0..27
    reg [9:0] idx;   // 0..783

    // grayscale -> 9-bit RGB
    wire [2:0] g3   = ram_data_b[7:5];
    wire [8:0] rgb9 = {g3, g3, g3};

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state      <= S_IDLE;
            col        <= 5'd0;
            row        <= 5'd0;
            idx        <= 10'd0;
            ram_addr_b <= 10'd0;
            vga_x      <= 10'd0;
            vga_y      <= 9'd0;
            vga_color  <= 9'd0;
            vga_write  <= 1'b0;
            busy       <= 1'b0;
        end else begin
            vga_write <= 1'b0;
            busy      <= (state != S_IDLE);

            case (state)
                S_IDLE: begin
                    if (start_rising && frame_ready) begin
                        // init counters
                        col        <= 5'd0;
                        row        <= 5'd0;
                        idx        <= 10'd0;
                        ram_addr_b <= 10'd0;
                        state      <= S_SET_ADDR;
                    end
                end

                S_SET_ADDR: begin
                    // Address already set; next cycle data will be valid
                    state <= S_WRITE;
                end

                S_WRITE: begin
                    // Use ram_data_b from previous addr, write to VGA RAM
                    vga_x     <= BASE_X + col;
                    vga_y     <= BASE_Y + row;
                    vga_color <= rgb9;
                    vga_write <= 1'b1;

                    // Prepare next pixel indices and RAM address
                    if (idx == 10'd783) begin
                        state <= S_IDLE; // done
                    end else begin
                        idx <= idx + 10'd1;

                        if (col == 5'd27) begin
                            col <= 5'd0;
                            row <= row + 5'd1;
                        end else begin
                            col <= col + 5'd1;
                        end

                        ram_addr_b <= idx + 10'd1;
                        state      <= S_SET_ADDR;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
