// 28x28x8-bit dual-port image RAM
module mnist_frame_ram #(
    parameter DATA_WIDTH = 8,
    parameter IMG_ROWS   = 28,
    parameter IMG_COLS   = 28
) (
    input  wire                      clk,

    // Port A: write side (e.g. Arduino capture)
    input  wire                      we_a,
    input  wire [9:0]                addr_a,   // 0..783
    input  wire [DATA_WIDTH-1:0]     din_a,

    // Port B: read side (e.g. VGA, CNN, etc)
    input  wire [9:0]                addr_b,   // 0..783
    output reg  [DATA_WIDTH-1:0]     dout_b
);
    localparam IMG_SIZE = IMG_ROWS * IMG_COLS; // 784

    reg [DATA_WIDTH-1:0] mem [0:IMG_SIZE-1];

    always @(posedge clk) begin
        if (we_a)
            mem[addr_a] <= din_a;

        // synchronous read
        dout_b <= mem[addr_b];
    end

endmodule
