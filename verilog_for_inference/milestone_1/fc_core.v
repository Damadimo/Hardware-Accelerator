// fc_core.v
// Single fully-connected layer: 400 -> 10 + argmax
// Expects memory files in the same directory:
//   - features.mem    : 400 bytes (int8)
//   - fc_w_flat.mem   : 4000 bytes (int8, 10*400 flattened)
//   - fc_b.mem        : 10 words (int16)

module fc_core #(
    parameter N_IN  = 400,  // length of feature vector
    parameter N_OUT = 10    // number of classes
)(
    input  wire       clk,
    input  wire       reset_n,
    input  wire       start,       // 1-cycle pulse

    output reg        done,        // 1-cycle pulse
    output reg [3:0]  pred_digit   // 0..9
);

    // -------- Memories --------

    // Feature vector (int8)
    reg signed [7:0] feats [0:N_IN-1];

    // Flattened weight matrix (int8) : length N_OUT * N_IN
    reg signed [7:0] fc_w_flat [0:N_OUT*N_IN-1];

    // Biases (int16)
    reg signed [15:0] biases [0:N_OUT-1];

    // Scores (int32)
    reg signed [31:0] scores [0:N_OUT-1];

    integer ii;

    initial begin
        // Load feature vector
        $readmemh("features.mem",  feats);
        // Load flattened weights
        $readmemh("fc_w_flat.mem", fc_w_flat);
        // Load biases
        $readmemh("fc_b.mem",      biases);

        // Initialize scores
        for (ii = 0; ii < N_OUT; ii = ii + 1) begin
            scores[ii] = 32'sd0;
        end
    end

    // -------- FSM State Encoding (no typedef) --------
    localparam S_IDLE   = 2'd0;
    localparam S_ACCUM  = 2'd1;
    localparam S_PREP   = 2'd2;
    localparam S_ARGMAX = 2'd3;

    reg [1:0] state;

    // Loop counters
    reg [3:0] j_class;   // 0..9
    reg [9:0] k_feat;    // 0..399

    // Accumulator
    reg signed [31:0] acc;

    // Argmax tracking
    reg [3:0]        best_j;
    reg signed [31:0] best_score;

    // Helper: index into flat weight array
    wire [31:0] w_index;
    assign w_index = j_class * N_IN + k_feat;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state      <= S_IDLE;
            done       <= 1'b0;
            pred_digit <= 4'd0;

            j_class    <= 4'd0;
            k_feat     <= 10'd0;
            acc        <= 32'sd0;

            best_j     <= 4'd0;
            best_score <= 32'sd0;

            for (ii = 0; ii < N_OUT; ii = ii + 1) begin
                scores[ii] <= 32'sd0;
            end
        end else begin
            done <= 1'b0;  // default

            case (state)
                // ----------------------------
                S_IDLE: begin
                    if (start) begin
                        // Clear scores
                        for (ii = 0; ii < N_OUT; ii = ii + 1) begin
                            scores[ii] <= 32'sd0;
                        end

                        j_class <= 4'd0;
                        k_feat  <= 10'd0;
                        // sign-extend bias[0] into 32 bits
                        acc <= {{16{biases[0][15]}}, biases[0]};
                        state <= S_ACCUM;
                    end
                end

                // ----------------------------
                // Accumulate over all features for class j_class
                S_ACCUM: begin
                    acc <= acc + $signed(feats[k_feat]) * $signed(fc_w_flat[w_index]);

                    if (k_feat == (N_IN-1)) begin
                        // Finished all features for this class
                        state <= S_PREP;
                    end else begin
                        // Next feature
                        k_feat <= k_feat + 10'd1;
                    end
                end

                // ----------------------------
                // Store last class's score and either move to next, or argmax stage
                S_PREP: begin
                    scores[j_class] <= acc;

                    if (j_class == (N_OUT-1)) begin
                        // All classes done: prepare for argmax
                        j_class    <= 4'd0;
                        best_j     <= 4'd0;
                        best_score <= scores[0];
                        state      <= S_ARGMAX;
                    end else begin
                        // Next class
                        j_class <= j_class + 4'd1;
                        k_feat  <= 10'd0;
                        acc     <= {{16{biases[j_class+1][15]}}, biases[j_class+1]};
                        state   <= S_ACCUM;
                    end
                end

                // ----------------------------
                // Scan scores to find argmax
                S_ARGMAX: begin
                    if (j_class < N_OUT) begin
                        if (scores[j_class] > best_score) begin
                            best_score <= scores[j_class];
                            best_j     <= j_class;
                        end
                        j_class <= j_class + 4'd1;
                    end else begin
                        pred_digit <= best_j;
                        done       <= 1'b1;
                        state      <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
