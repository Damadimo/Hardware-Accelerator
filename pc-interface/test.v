// uart_ack_test.v
// Sends 0xAB back to PC whenever any byte is received

module uart_ack_test (
    input  wire CLOCK_50,
    input  wire PIN_AG14,
    output wire PIN_AF14
);

    wire rx_ready;
    wire [7:0] rx_data;
    reg  tx_start = 0;
    wire tx_busy;
    reg  [7:0] tx_data = 8'hAB;  // fixed confirmation byte

    // Instantiate receiver
    uart_rx #(
        .CLK_FREQ(50000000),
        .BAUD_RATE(115200)
    ) receiver (
        .clk(CLOCK_50),
        .reset_n(1'b1),
        .rx(PIN_AG14),
        .data(rx_data),
        .ready(rx_ready)
    );

    // Instantiate transmitter
    uart_tx #(
        .CLK_FREQ(50000000),
        .BAUD_RATE(115200)
    ) transmitter (
        .clk(CLOCK_50),
        .reset_n(1'b1),
        .data(tx_data),
        .start(tx_start),
        .tx(PIN_AF14),
        .busy(tx_busy)
    );

    // Send one 0xAB back whenever any byte is received
    always @(posedge CLOCK_50) begin
        tx_start <= 1'b0;  // default low
        if (rx_ready && !tx_busy) begin
            tx_start <= 1'b1; // send confirmation
        end
    end

endmodule


// uart_rx.v
module uart_rx #(parameter CLK_FREQ=50000000, BAUD_RATE=115200)(
    input  wire clk, reset_n, rx,
    output reg [7:0] data,
    output reg ready
);
    localparam DIV = CLK_FREQ/BAUD_RATE;
    localparam MID = DIV/2;
    reg [15:0] cnt=0; reg [3:0] bit_i=0; reg [1:0] state=0;
    reg rx1=1,rx2=1;
    always @(posedge clk) begin rx1<=rx; rx2<=rx1; end
    always @(posedge clk) begin
        ready<=0;
        case(state)
            0: if(!rx2) begin state<=1; cnt<=0; end
            1: if(cnt==MID) begin cnt<=0; bit_i<=0; state<=2; end else cnt<=cnt+1;
            2: if(cnt==DIV-1) begin
                    cnt<=0; data<={rx2,data[7:1]}; bit_i<=bit_i+1;
                    if(bit_i==7) state<=3;
               end else cnt<=cnt+1;
            3: if(cnt==DIV-1) begin ready<=1; state<=0; end else cnt<=cnt+1;
        endcase
    end
endmodule

// uart_tx.v
module uart_tx #(parameter CLK_FREQ=50000000, BAUD_RATE=115200)(
    input wire clk, reset_n,
    input wire [7:0] data,
    input wire start,
    output reg tx,
    output reg busy
);
    localparam DIV = CLK_FREQ/BAUD_RATE;
    reg [15:0] cnt=0; reg [3:0] bit_i=0;
    reg [9:0] shifter=10'h3FF;
    always @(posedge clk) begin
        if(!busy) begin
            tx<=1; if(start) begin
                shifter<={1'b1,data,1'b0};
                busy<=1; cnt<=0; bit_i<=0;
            end
        end else begin
            if(cnt==DIV-1) begin
                cnt<=0; tx<=shifter[0];
                shifter<={1'b1,shifter[9:1]};
                bit_i<=bit_i+1;
                if(bit_i==9) busy<=0;
            end else cnt<=cnt+1;
        end
    end
endmodule
