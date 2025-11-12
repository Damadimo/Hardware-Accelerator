// top_m1.v
module top_m1 (
    input  wire clk,
    input  wire reset_n,
    input  wire start,
    output wire [6:0] hex_seg
);

    wire        done;
    wire [3:0]  digit;

    fc_core #(
        .N_IN(400),
        .N_OUT(10)
    ) u_fc (
        .clk        (clk),
        .reset_n    (reset_n),
        .start      (start),
        .done       (done),
        .pred_digit (digit)
    );

    hex7seg_decoder u_hex (
        .digit (digit),
        .seg   (hex_seg)
    );

endmodule
