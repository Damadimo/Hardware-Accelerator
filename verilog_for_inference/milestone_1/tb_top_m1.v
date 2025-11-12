// tb_top_m1.v
`timescale 1ns/1ps

module tb_top_m1;

    reg clk;
    reg reset_n;
    reg start;
    wire [6:0] hex_seg;

    top_m1 dut (
        .clk     (clk),
        .reset_n (reset_n),
        .start   (start),
        .hex_seg (hex_seg)
    );
    initial begin
    $dumpfile("wave.vcd");     // name of the waveform file
    $dumpvars(0, tb_top_m1);   // dump everything in this testbench hierarchy
end

    // 50 MHz clock (20 ns period)
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;  // 10 ns high, 10 ns low
    end

    initial begin
        // init
        reset_n = 1'b0;
        start   = 1'b0;

        // hold reset low
        #100;
        reset_n = 1'b1;

        // wait a bit then pulse start
        #40;
        start = 1'b1;
        #20;
        start = 1'b0;

        // wait long enough for FC to finish
        // worst-case cycles ~ N_OUT * N_IN = 4000 MACs + argmax
        // at 50 MHz (20ns per cycle): 4000 * 20ns = 80us
        // use 200us margin:
        #200000;

        $display("HEX segments (active-low) = %b", hex_seg);
        $stop;
    end

endmodule
