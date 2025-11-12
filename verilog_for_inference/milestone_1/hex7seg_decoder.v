// hex7seg_decoder.v
// Maps a 4-bit digit (0..9) to active-low 7-seg {A,B,C,D,E,F,G}
module hex7seg_decoder (
    input  wire [3:0] digit,
    output reg  [6:0] seg
);

    always @* begin
        case (digit)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111;  // all segments off
        endcase
    end

endmodule
