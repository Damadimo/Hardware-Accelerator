// Captures 28x28 = 784 bytes from Arduino bit-serial stream
// and exposes them as write operations into a RAM.
module arduino_mnist_capture (
    input  wire       clk,            // 50 MHz system clock
    input  wire       resetn,         // active-low reset

    input  wire       serial_data_in, // from Arduino D2
    input  wire       bit_clk_in,     // from Arduino D3
    input  wire       frame_start_in, // from Arduino D4

    // Write interface to frame RAM (Port A)
    output reg        ram_we,
    output reg [9:0]  ram_addr,       // 0..783
    output reg [7:0]  ram_din,

    // Frame status
    output reg        frame_ready
);

    // Sync external signals into clk domain
    reg [2:0] bit_clk_sync;
    reg [2:0] frame_start_sync;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            bit_clk_sync     <= 3'b000;
            frame_start_sync <= 3'b000;
        end else begin
            bit_clk_sync     <= {bit_clk_sync[1:0], bit_clk_in};
            frame_start_sync <= {frame_start_sync[1:0], frame_start_in};
        end
    end

    wire bit_clk_rising     = (bit_clk_sync[2:1] == 2'b01);
    wire frame_start_rising = (frame_start_sync[2:1] == 2'b01);

    // Counters and shift register
    reg [2:0]  bit_index;    // 0..7
    reg [9:0]  pixel_index;  // 0..783
    reg [7:0]  shift_reg;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            bit_index   <= 3'd0;
            pixel_index <= 10'd0;
            shift_reg   <= 8'd0;
            frame_ready <= 1'b0;
            ram_we      <= 1'b0;
            ram_addr    <= 10'd0;
            ram_din     <= 8'd0;
        end else begin
            ram_we <= 1'b0;  // default

            // Start of new frame
            if (frame_start_rising) begin
                bit_index   <= 3'd0;
                pixel_index <= 10'd0;
                frame_ready <= 1'b0;
            end

            if (bit_clk_rising) begin
                // Bits arrive LSB-first
                shift_reg[bit_index] <= serial_data_in;

                if (bit_index == 3'd7) begin
                    // Last bit of this pixel
                    // Construct full byte
                    ram_addr <= pixel_index;
                    ram_din  <= {serial_data_in, shift_reg[6:0]};
                    ram_we   <= 1'b1;          // one-cycle write

                    bit_index <= 3'd0;

                    if (pixel_index == 10'd783) begin
                        frame_ready <= 1'b1;
                    end else begin
                        pixel_index <= pixel_index + 10'd1;
                    end
                end else begin
                    bit_index <= bit_index + 3'd1;
                end
            end
        end
    end

endmodule
