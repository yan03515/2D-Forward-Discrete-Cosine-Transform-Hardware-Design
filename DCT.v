/**
 * @file DCTD.v
 * @brief 8x8 2D Discrete Cosine Transform (DCT) Module using Row-Column Decomposition.
 *
 * Implements a 2D DCT by performing 1D DCTs first on rows,
 * transposing the result, and then performing 1D DCTs on columns.
 *
 * The design uses a 5-stage pipeline with Ping-Pong memories for efficient
 * data transposition and reordering.
 */
`timescale 1 ns / 10 ps

module DCT #(
    // --- Data Width Parameters ---
    parameter INPUT_WIDTH      = 9,
    parameter INTERNAL_WIDTH   = 12,   // Width after Stage 1 (Input Extension)
    parameter MID_WIDTH        = 18,   // Width after Stage 2 (Row DCT Output)
    parameter OUTPUT_WIDTH     = 18    // Final Output Width
)(
    // --- Clock and Reset ---
    input wire clk,
    input wire rst_n,

    // --- Input Data (9-bit Signed) ---
    input wire signed [INPUT_WIDTH-1:0] x0, x1, x2, x3, x4, x5, x6, x7,

    // --- Output Data (18-bit Signed) ---
    output wire signed [OUTPUT_WIDTH-1:0] z0, z1, z2, z3, z4, z5, z6, z7,

    // --- Status Output ---
    output reg ready
);


    // =========================================================
    // Stage 1: Input Extension (9-bit -> 12-bit)
    // =========================================================
    //The width difference (12 - 9 = 3) bits are padded with the sign bit.
    wire signed [INTERNAL_WIDTH-1:0] row_in [0:7];

    assign row_in[0] = {{(INTERNAL_WIDTH-INPUT_WIDTH){x0[INPUT_WIDTH-1]}}, x0};
    assign row_in[1] = {{(INTERNAL_WIDTH-INPUT_WIDTH){x1[INPUT_WIDTH-1]}}, x1};
    assign row_in[2] = {{(INTERNAL_WIDTH-INPUT_WIDTH){x2[INPUT_WIDTH-1]}}, x2};
    assign row_in[3] = {{(INTERNAL_WIDTH-INPUT_WIDTH){x3[INPUT_WIDTH-1]}}, x3};
    assign row_in[4] = {{(INTERNAL_WIDTH-INPUT_WIDTH){x4[INPUT_WIDTH-1]}}, x4};
    assign row_in[5] = {{(INTERNAL_WIDTH-INPUT_WIDTH){x5[INPUT_WIDTH-1]}}, x5};
    assign row_in[6] = {{(INTERNAL_WIDTH-INPUT_WIDTH){x6[INPUT_WIDTH-1]}}, x6};
    assign row_in[7] = {{(INTERNAL_WIDTH-INPUT_WIDTH){x7[INPUT_WIDTH-1]}}, x7};


    // =========================================================
    // Stage 2: Row DCT Logic (DCT1D Instance)
    // =========================================================
    wire signed [MID_WIDTH-1:0] row_out [0:7];

    DCT1D #(
        .INPUT_WIDTH (INTERNAL_WIDTH),
        .OUTPUT_WIDTH(MID_WIDTH)
    ) ROW_DCT (
        .clk(clk), 
        .rst_n(rst_n),
        .valid_in(1'b1),   // Assuming continuous stream or always valid input

        .x0(row_in[0]), .x1(row_in[1]), .x2(row_in[2]), .x3(row_in[3]),
        .x4(row_in[4]), .x5(row_in[5]), .x6(row_in[6]), .x7(row_in[7]),

        .z0(row_out[0]), .z1(row_out[1]), .z2(row_out[2]), .z3(row_out[3]),
        .z4(row_out[4]), .z5(row_out[5]), .z6(row_out[6]), .z7(row_out[7]),

        .ready() 
    );

    // ---------------------------------------------------------
    // Pipeline Control (Timer)
    // ---------------------------------------------------------
    // Time constants determine when each stage's output is ready.
    // These must be fine-tuned based on the actual DCT1D implementation.
    // Pipeline_Latency for DCT1D = L_DCT1D
    localparam TIME_ROW_START  = 14;   // (Testbench_Delay = 10) + L_DCT1D
    localparam TIME_COL_START  = 26;   // TIME_ROW_START + (Buffer_1 = 8) + L_DCT1D
    localparam TIME_READY      = 33;   // TIME_COL_START + (Buffer_2 = 8) - 1

    reg [45:0] timer;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            timer <= 46'd0;
        else       
            timer <= {timer[44:0], 1'b1};
    end

    // Enable signals derived from specific timer bits
    wire en_buf1     = timer[TIME_ROW_START];   // Starts Buffer_1 write
    wire en_buf2     = timer[TIME_COL_START];   // Starts Buffer_2 write
    wire ready_pulse = timer[TIME_READY];       // Final output ready signal


    // =========================================================
    // Stage 3: Buffer_1 & Transpose (Ping-Pong Memory)
    // =========================================================
    // Memory stores Row DCT output (18-bit) and enables column-wise read.
    reg signed [MID_WIDTH-1:0] mem1 [0:1][0:7][0:7];   //[Bank: 0/1][Row: 0..7][Col: 0..7]
    reg [2:0] cnt1;   // Write address counter (0..7)
    reg bank1;        // Write bank selector (0/1)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            cnt1 <= 3'd0;
            bank1 <= 1'b0; 
        end else if (en_buf1) begin
            // Write the entire row_out vector into one row of the current bank
            mem1[bank1][cnt1][0] <= row_out[0];
            mem1[bank1][cnt1][1] <= row_out[1];
            mem1[bank1][cnt1][2] <= row_out[2];
            mem1[bank1][cnt1][3] <= row_out[3];
            mem1[bank1][cnt1][4] <= row_out[4];
            mem1[bank1][cnt1][5] <= row_out[5];
            mem1[bank1][cnt1][6] <= row_out[6];
            mem1[bank1][cnt1][7] <= row_out[7];

            if (cnt1 == 3'd7) begin
                cnt1 <= 3'd0;
                bank1 <= ~bank1;   // Switch bank after writing a full 8x8 block
            end
            else cnt1 <= cnt1 + 3'd1;
        end
    end

    // ---------------------------------------------------------
    // Transposed Read (Combinational)
    // ---------------------------------------------------------
    // Reads a column from the *other* bank (~bank1) using cnt1 as the column index.
    reg signed [17:0] col_in [0:7];

    always @(*) begin
        col_in[0] = mem1[~bank1][0][cnt1];
        col_in[1] = mem1[~bank1][1][cnt1];
        col_in[2] = mem1[~bank1][2][cnt1];
        col_in[3] = mem1[~bank1][3][cnt1];
        col_in[4] = mem1[~bank1][4][cnt1];
        col_in[5] = mem1[~bank1][5][cnt1];
        col_in[6] = mem1[~bank1][6][cnt1];
        col_in[7] = mem1[~bank1][7][cnt1];
    end


    // =========================================================
    // Stage 4: Col DCT Logic (DCT1D Instance)
    // =========================================================
    wire signed [OUTPUT_WIDTH-1:0] col_out [0:7];

    DCT1D #(
        .INPUT_WIDTH (MID_WIDTH),      
        .OUTPUT_WIDTH(OUTPUT_WIDTH)   
    ) COL_DCT (
        .clk(clk), 
        .rst_n(rst_n),
        .valid_in(1'b1),   // Assuming continuous stream or always valid input

        .x0(col_in[0]), .x1(col_in[1]), .x2(col_in[2]), .x3(col_in[3]),
        .x4(col_in[4]), .x5(col_in[5]), .x6(col_in[6]), .x7(col_in[7]),

        .z0(col_out[0]), .z1(col_out[1]), .z2(col_out[2]), .z3(col_out[3]),
        .z4(col_out[4]), .z5(col_out[5]), .z6(col_out[6]), .z7(col_out[7]),

        .ready()
    );


    // =========================================================
    // Stage 5: Buffer_2 (Output Reorder)
    // =========================================================
    // Memory stores Col DCT output (18-bit) for synchronous output.
    reg signed [OUTPUT_WIDTH-1:0] mem2 [0:1][0:7][0:7];   //[Bank: 0/1][Row: 0..7][Col: 0..7]
    reg [2:0] cnt2;   // Write address counter (0..7)
    reg bank2;        // Write bank selector (0/1)

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin 
            cnt2 <= 3'd0; 
            bank2 <= 1'b0; 
        end else if (en_buf2) begin
            // Write the entire col_out vector into one row of the current bank
            mem2[bank2][cnt2][0] <= col_out[0];
            mem2[bank2][cnt2][1] <= col_out[1];
            mem2[bank2][cnt2][2] <= col_out[2];
            mem2[bank2][cnt2][3] <= col_out[3];
            mem2[bank2][cnt2][4] <= col_out[4];
            mem2[bank2][cnt2][5] <= col_out[5];
            mem2[bank2][cnt2][6] <= col_out[6];
            mem2[bank2][cnt2][7] <= col_out[7];

            if (cnt2 == 3'd7) begin
                cnt2 <= 3'd0;
                bank2 <= ~bank2;   // Switch bank after writing a full 8x8 block
            end else 
                cnt2 <= cnt2 + 3'd1;
        end
    end


    // =========================================================
    // Stage 6: Output Assignment & Ready Signal
    // =========================================================
    // Read final output from the non-writing bank (~bank2)
    // The read address cnt2 is the next write address.
    assign z0 = mem2[~bank2][0][cnt2];
    assign z1 = mem2[~bank2][1][cnt2];
    assign z2 = mem2[~bank2][2][cnt2];
    assign z3 = mem2[~bank2][3][cnt2];
    assign z4 = mem2[~bank2][4][cnt2];
    assign z5 = mem2[~bank2][5][cnt2];
    assign z6 = mem2[~bank2][6][cnt2];
    assign z7 = mem2[~bank2][7][cnt2];

    // Ready signal generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            ready <= 1'b0;
        else      
            ready <= ready_pulse;
    end

endmodule
