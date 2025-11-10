module pixel_buffer (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        avs_chipselect,
    input  wire        avs_write,
    input  wire        avs_read,
    input  wire [1:0]  avs_address,
    input  wire [31:0] avs_writedata,
    output reg  [31:0] avs_readdata,
    output wire        frame_ready
);
    reg [7:0] ram[0:783];
    reg frame_ready_reg;
    assign frame_ready = frame_ready_reg;

    wire [10:0] idx = avs_writedata[18:8];
    wire [7:0] pix  = avs_writedata[7:0];

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) frame_ready_reg <= 0;
        else if (avs_chipselect && avs_write) begin
            case (avs_address)
                0: if (idx < 784) ram[idx] <= pix;
                1: frame_ready_reg <= avs_writedata[0];
            endcase
        end
    end

    always @(*) begin
        avs_readdata = (avs_address == 1) ? {31'b0, frame_ready_reg} : 0;
    end
endmodule
