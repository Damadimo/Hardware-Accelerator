// top_m1.v  (Milestone 1 top-level for simulation)
module top_m1 (
    input  wire clk,
    input  wire reset_n,
    input  wire start,
    output wire [6:0] hex_seg    // active-low 7-seg output
);

    wire        cnn_done;
    wire [3:0]  cnn_digit;

    // Instantiate your CNN core
    cnn_core u_cnn_core (
        .clk        (clk),
        .reset_n    (reset_n),
        .start      (start),
        .done       (cnn_done),
        .pred_digit (cnn_digit)
    );

    // Instantiate 7-seg decoder
    hex7seg_decoder u_hex (
        .digit (cnn_digit),
        .seg   (hex_seg)
    );

endmodule
