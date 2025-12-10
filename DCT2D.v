module DCT2D (
    input wire clk,
    input wire rst_n,
    // 輸入: 9-bit 有號數
    input wire signed [8:0] x0, x1, x2, x3, x4, x5, x6, x7,
    // 輸出: 改為 18-bit 有號數
    output wire signed [17:0] z0, z1, z2, z3, z4, z5, z6, z7,
    output reg ready
);

    // =========================================================
    // 1. 輸入處理 (Input Extension)
    // =========================================================
    wire signed [11:0] row_in [0:7];
    // 補 3 個符號位，擴展至 12-bit 給第一級輸入
    assign row_in[0] = {{3{x0[8]}}, x0};
    assign row_in[1] = {{3{x1[8]}}, x1};
    assign row_in[2] = {{3{x2[8]}}, x2};
    assign row_in[3] = {{3{x3[8]}}, x3};
    assign row_in[4] = {{3{x4[8]}}, x4};
    assign row_in[5] = {{3{x5[8]}}, x5};
    assign row_in[6] = {{3{x6[8]}}, x6};
    assign row_in[7] = {{3{x7[8]}}, x7};

    // =========================================================
    // 2. Row DCT (Stage 1)
    // =========================================================
    // 第一級輸出改為 18-bit
    wire signed [17:0] row_out [0:7];

    DCT1D #(
        .INPUT_WIDTH(12),   // 輸入維持 12
        .OUTPUT_WIDTH(18)   // 輸出擴展為 18
    ) ROW_DCT (
        .clk(clk), 
        .rst_n(rst_n),
        .valid_in(1'b1),
        .x0(row_in[0]), .x1(row_in[1]), .x2(row_in[2]), .x3(row_in[3]),
        .x4(row_in[4]), .x5(row_in[5]), .x6(row_in[6]), .x7(row_in[7]),
        .z0(row_out[0]), .z1(row_out[1]), .z2(row_out[2]), .z3(row_out[3]),
        .z4(row_out[4]), .z5(row_out[5]), .z6(row_out[6]), .z7(row_out[7]),
        .ready() 
    );

    // =========================================================
    // 時序控制 (Timer)
    // =========================================================
    // 參數建議依據模擬波形調整，此處假設 DCT1D Latency = 4
    localparam TIME_ROW_START = 14; 
    localparam TIME_COL_START = 26;
    localparam TIME_READY     = 33;

    reg [45:0] timer;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) timer <= 0;
        else       timer <= {timer[44:0], 1'b1};
    end

    wire en_buf1 = timer[TIME_ROW_START];
    wire en_buf2 = timer[TIME_COL_START];
    wire ready_pulse = timer[TIME_READY];

    // =========================================================
    // 3. Buffer 1 + Transpose
    // =========================================================
    // 記憶體加寬至 18-bit 以儲存 Row DCT 的結果
    reg signed [17:0] mem1 [0:1][0:7][0:7];
    reg [2:0] cnt1;
    reg bank1;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin cnt1<=0; bank1<=0; end
        else if (en_buf1) begin
            mem1[bank1][cnt1][0] <= row_out[0];
            mem1[bank1][cnt1][1] <= row_out[1];
            mem1[bank1][cnt1][2] <= row_out[2];
            mem1[bank1][cnt1][3] <= row_out[3];
            mem1[bank1][cnt1][4] <= row_out[4];
            mem1[bank1][cnt1][5] <= row_out[5];
            mem1[bank1][cnt1][6] <= row_out[6];
            mem1[bank1][cnt1][7] <= row_out[7];
            if(cnt1==7) begin
                cnt1<=0;
                bank1<=~bank1;
            end
            else cnt1<=cnt1+1;
        end
    end

    // 讀出轉置：col_in 也定義為 18-bit
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
    // 4. Col DCT (Stage 2)
    // =========================================================
    wire signed [17:0] col_out [0:7];

    DCT1D #(
        .INPUT_WIDTH(18),   // 這裡接收 18-bit 的資料
        .OUTPUT_WIDTH(18)   // 輸出也是 18-bit
    ) COL_DCT (
        .clk(clk), 
        .rst_n(rst_n),
        .valid_in(1'b1),
        .x0(col_in[0]), .x1(col_in[1]), .x2(col_in[2]), .x3(col_in[3]),
        .x4(col_in[4]), .x5(col_in[5]), .x6(col_in[6]), .x7(col_in[7]),
        .z0(col_out[0]), .z1(col_out[1]), .z2(col_out[2]), .z3(col_out[3]),
        .z4(col_out[4]), .z5(col_out[5]), .z6(col_out[6]), .z7(col_out[7]),
        .ready()
    );

    // =========================================================
    // 5. Buffer 2 + Transpose
    // =========================================================
    // 記憶體加寬至 18-bit
    reg signed [17:0] mem2 [0:1][0:7][0:7];
    reg [2:0] cnt2;
    reg bank2;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin cnt2<=0; bank2<=0; end
        else if (en_buf2) begin
            mem2[bank2][cnt2][0] <= col_out[0];
            mem2[bank2][cnt2][1] <= col_out[1];
            mem2[bank2][cnt2][2] <= col_out[2];
            mem2[bank2][cnt2][3] <= col_out[3];
            mem2[bank2][cnt2][4] <= col_out[4];
            mem2[bank2][cnt2][5] <= col_out[5];
            mem2[bank2][cnt2][6] <= col_out[6];
            mem2[bank2][cnt2][7] <= col_out[7];

            if(cnt2==7) begin
                cnt2<=0;
                bank2<=~bank2;
            end
            else cnt2<=cnt2+1;
        end
    end

    // =========================================================
    // 6. 輸出 Assignment
    // =========================================================
    assign z0 = mem2[~bank2][0][cnt2];
    assign z1 = mem2[~bank2][1][cnt2];
    assign z2 = mem2[~bank2][2][cnt2];
    assign z3 = mem2[~bank2][3][cnt2];
    assign z4 = mem2[~bank2][4][cnt2];
    assign z5 = mem2[~bank2][5][cnt2];
    assign z6 = mem2[~bank2][6][cnt2];
    assign z7 = mem2[~bank2][7][cnt2];

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) ready <= 0;
        else       ready <= ready_pulse;
    end

endmodule
