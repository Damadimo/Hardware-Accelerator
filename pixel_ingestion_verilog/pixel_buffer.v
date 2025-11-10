// pixel_buffer.v
// 28x28 = 784-byte pixel buffer with simple Avalon-MM slave interface.
// HPS writes pixels via register at address 0.
// HPS controls frame_ready via register at address 1.
// CNN/accelerator can read pixels via cnn_addr/cnn_data port.

module pixel_buffer (
    input  wire        clk,
    input  wire        reset_n,

    // Avalon-MM slave (to HPS)
    input  wire        avs_chipselect,
    input  wire        avs_write,
    input  wire        avs_read,
    input  wire [1:0]  avs_address,     // 0: PIXEL_DATA, 1: CTRL
    input  wire [31:0] avs_writedata,
    output reg  [31:0] avs_readdata,

    // CNN read port (FPGA-side)
    input  wire [9:0]  cnn_addr,        // 0..783
    output reg  [7:0]  cnn_data,

    // Frame status
    output wire        frame_ready
);

    // 784 x 8-bit RAM
    reg [7:0] pixel_ram [0:783];

    // frame_ready flag
    reg frame_ready_reg;
    assign frame_ready = frame_ready_reg;

    // Decode index and pixel from write data:
    // Layout: [7:0]   = pixel value
    //         [18:8]  = index (0..783)
    wire [7:0]  avs_pix = avs_writedata[7:0];
    wire [10:0] avs_idx = avs_writedata[18:8]; // 11 bits; we will check range

    // --------------------------
    // Avalon write operations
    // --------------------------
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            frame_ready_reg <= 1'b0;
        end else begin
            if (avs_chipselect && avs_write) begin
                case (avs_address)
                    2'd0: begin
                        // PIXEL_DATA write
                        if (avs_idx < 11'd784)
                            pixel_ram[avs_idx] <= avs_pix;
                    end

                    2'd1: begin
                        // CTRL write: bit 0 = frame_ready
                        frame_ready_reg <= avs_writedata[0];
                    end

                    default: begin
                        // do nothing
                    end
                endcase
            end
        end
    end

    // --------------------------
    // Avalon read operations
    // --------------------------
    always @(*) begin
        if (avs_chipselect && avs_read) begin
            case (avs_address)
                2'd1: avs_readdata = {31'b0, frame_ready_reg};
                default: avs_readdata = 32'h00000000;
            endcase
        end else begin
            avs_readdata = 32'h00000000;
        end
    end

    // --------------------------
    // CNN read port
    // --------------------------
    always @(posedge clk) begin
        if (cnn_addr < 10'd784)
            cnn_data <= pixel_ram[cnn_addr];
        else
            cnn_data <= 8'h00;
    end

endmodule
