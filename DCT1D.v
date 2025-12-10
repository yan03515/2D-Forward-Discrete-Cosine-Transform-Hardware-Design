/**
 * @file DCT1D.v
 * @brief 8-Point 1D Discrete Cosine Transform (DCT) using Fast Algorithm.
 *
 * Implements the 1D DCT using a 4-stage pipeline structure (Butterfly -> Multiply -> Add -> Output).
 * The constants are pre-scaled by 2^SHIFT_BITS for fixed-point arithmetic.
 */
module DCT1D #(
    // --- Data Width Parameters ---
    parameter INPUT_WIDTH    = 9,      
    parameter OUTPUT_WIDTH   = 18,   // Final output width
    parameter SHIFT_BITS     = 14    // Scaling factor
)(
    // --- Clock and Reset ---
    input clk,
    input rst_n,
    input valid_in,   // Input data valid signal

    // --- Input Data (9-bit Signed) ---
    input wire signed [INPUT_WIDTH-1:0] x0, x1, x2, x3, x4, x5, x6, x7,

    // --- Output Data (18-bit Signed) ---
    output reg signed [OUTPUT_WIDTH-1:0] z0, z1, z2, z3, z4, z5, z6, z7,

    // --- Status Output ---
    output ready   // Output data ready signal (Latency = 4 cycles)
);

    // ==========================================================
    // Fixed-Point Constant Definitions (Scaled by 2^14 = 16384)
    // ==========================================================
    localparam COEFF_W = 16;   // Coefficient width is 16 bits (including 1 sign bit)

    localparam signed [15:0] C1 = 16'sd8035;  // 0.4903926402 = 1/2*cos(1π/16)
    localparam signed [15:0] C2 = 16'sd7571;  // 0.4619397663 = 1/2*cos(2π/16)
    localparam signed [15:0] C3 = 16'sd6816;  // 0.4157348062 = 1/2*cos(3π/16)
    localparam signed [15:0] C4 = 16'sd5793;  // 0.3535533906 = 1/2*cos(4π/16)
    localparam signed [15:0] C5 = 16'sd4548;  // 0.2777851165 = 1/2*cos(5π/16)
    localparam signed [15:0] C6 = 16'sd3140;  // 0.1913417162 = 1/2*cos(6π/16)
    localparam signed [15:0] C7 = 16'sd1597;  // 0.0975451610 = 1/2*cos(7π/16)

    // =======================================================
    // Stage 1: Butterfly Structures
    // =======================================================
    localparam S1_W = INPUT_WIDTH + 2;
    localparam S1_D = INPUT_WIDTH + 1;
    
    reg signed [S1_W-1:0] e0, e1, e2, e3;
    reg signed [S1_D-1:0] d07, d16, d25, d34;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            e0 <= 0; e1 <= 0; e2 <= 0; e3 <= 0;
            d07 <= 0; d16 <= 0; d25 <= 0; d34 <= 0;
        end else if (valid_in) begin
            // even part
            e0 <= (x0 + x7) + (x3 + x4);
            e1 <= (x1 + x6) + (x2 + x5);
            e2 <= (x0 + x7) - (x3 + x4);
            e3 <= (x1 + x6) - (x2 + x5);
            
            // odd part
            d07  <= x0 - x7;
            d16  <= x1 - x6;
            d25  <= x2 - x5;
            d34  <= x3 - x4;
        end
    end

    // =======================================================
    // Stage 2: Constant Multipliers
    // =======================================================
    localparam S2_W = COEFF_W + S1_W;

    reg signed [S2_W-1:0] a0, a1, a2, a3, a4, a5;
    reg signed [S2_W-1:0] b0, b1, b2, b3, b4, b5, b6, b7;
    reg signed [S2_W-1:0] b8, b9, b10, b11, b12, b13, b14, b15;


    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            a0 <= 0; a1 <= 0; a2 <= 0; a3 <= 0;
            b0 <= 0; b1 <= 0; b2 <= 0; b3 <= 0;
            b4 <= 0; b5 <= 0; b6 <= 0; b7 <= 0;
            b8 <= 0; b9 <= 0; b10 <= 0; b11 <= 0;
            b12 <= 0; b13 <= 0; b14 <= 0; b15 <= 0;
        end else begin
            // even part
            a0 <= e0 * C4;
            a1 <= e1 * C4;
            a2 <= e2 * C2;
            a3 <= e3 * C6;
            a4 <= e2 * C6;
            a5 <= e3 * C2;
    
            // odd part
            b0 <= d07 * C1;
            b1 <= d16 * C3;
            b2 <= d25 * C5;
            b3 <= d34 * C7;
            b4 <= d07 * C3;
            b5 <= d16 * C7;
            b6 <= d25 * C1;
            b7 <= d34 * C5;
            b8 <= d07 * C5;
            b9 <= d16 * C1;
            b10 <= d25 * C7;
            b11 <= d34 * C3;
            b12 <= d07 * C7;
            b13 <= d16 * C5;
            b14 <= d25 * C3;
            b15 <= d34 * C1;
        end
    end

    // =======================================================
    // Stage 3 : Final Adders
    // =======================================================
    localparam S3_W = S2_W + 2;
    
    reg signed [S3_W-1:0] m0, m2, m4, m6;
    reg signed [S3_W-1:0] m1, m3, m5, m7;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m0 <= 0; m4 <= 0; m2 <= 0; m6 <= 0;
            m1 <= 0; m3 <= 0; m5 <= 0; m7 <= 0;
        end else begin
            // even part
            m0 <= a0 + a1;
            m2 <= a2 + a3;
            m4 <= a0 - a1;
            m6 <= a4 - a5;
    
            // odd part
            m1 <= b0 + b1 + b2 + b3;
            m3 <= b4 - b5 - b6 - b7;
            m5 <= b8 - b9 + b10 + b11;
            m7 <= b12 - b13 + b14 - b15;
        end
    end

    // =======================================================
    // Stage 4: Shifter & Output Registers
    // =======================================================
    // Arithmetic shift right (>>>) maintains the sign bit
    // even part
    wire signed [OUTPUT_WIDTH-1:0] w0 = m0 >>> SHIFT_BITS;
    wire signed [OUTPUT_WIDTH-1:0] w4 = m4 >>> SHIFT_BITS;
    wire signed [OUTPUT_WIDTH-1:0] w2 = m2 >>> SHIFT_BITS;
    wire signed [OUTPUT_WIDTH-1:0] w6 = m6 >>> SHIFT_BITS;

    // odd part
    wire signed [OUTPUT_WIDTH-1:0] w1 = m1 >>> SHIFT_BITS;
    wire signed [OUTPUT_WIDTH-1:0] w3 = m3 >>> SHIFT_BITS;
    wire signed [OUTPUT_WIDTH-1:0] w5 = m5 >>> SHIFT_BITS;
    wire signed [OUTPUT_WIDTH-1:0] w7 = m7 >>> SHIFT_BITS;

    // Output Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z0 <= 0; z1 <= 0; z2 <= 0; z3 <= 0;
            z4 <= 0; z5 <= 0; z6 <= 0; z7 <= 0;
        end else begin
            z0 <= w0;
            z1 <= w1;
            z2 <= w2;
            z3 <= w3;
            z4 <= w4;
            z5 <= w5;
            z6 <= w6;
            z7 <= w7;
        end
    end

// =======================================================
// Valid Pipeline Control (Latency = 4 cycles)
// =======================================================
reg [3:0] vpipe;   // 4-bit shift register tracks valid signal through 4 stages
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        vpipe <= 4'b0000;
    else
        vpipe <= {vpipe[2:0], valid_in};   // Shift valid_in through the pipeline
end
// ready is asserted when valid_in reaches the final stage
assign ready = vpipe[3];

endmodule
