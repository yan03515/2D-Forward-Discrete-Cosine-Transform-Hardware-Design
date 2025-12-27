%% ========================================================================
%% 8x8 2D-DCT Hardware Output Verification & Image Reconstruction
%% ========================================================================
%  Project: Forward DCT Circuit Design (FDCT) [cite: 6]
%  Target Image: Lena 256x256 [cite: 29, 30]
%  Algorithm: Row-Column Decomposition [cite: 68, 72]
%% ========================================================================

clear; clc; close all;

%% 1. 參數設定 (Parameters Setup)
% 根據硬體設計規格設定資料寬度與影像尺寸 [cite: 46, 53, 151]
hex_width  = 5;          % 18-bit 至少需要 5 個 Hex 字元 (2^18 = 262144)
bit_depth  = 18;         % Signed 18-bit output [cite: 152]
block_size = 8;          % 8x8 Micro block DCT [cite: 32]
w          = 256;         % 影像寬度 [cite: 30]
h          = 256;         % 影像高度 [cite: 29]

%% 2. 讀取原始影像 (Load Ground Truth)
img_path = 'lena_256.bmp';
if exist(img_path, 'file')
    [lena_gt, ~] = imread(img_path);
    lena_gt      = double(lena_gt);
else
    error('錯誤: 找不到原始影像檔案 %s', img_path);
end

%% 3. 讀取並解析硬體輸出資料 (Parse Hardware Output)
data_path = 'dct_out.txt';
if exist(data_path, 'file')
    fid         = fopen(data_path, 'r');
    raw_content = fscanf(fid, '%c'); 
    fclose(fid);
else
    error('錯誤: 找不到硬體輸出檔案 %s', data_path);
end

% --- 資料清洗 (Data Cleaning) ---
% 移除特定標籤（如源文件標記）與非 Hex 字元，確保資料連續性
raw_content = regexprep(raw_content, '\', ''); 
raw_content = regexprep(raw_content, '[^0-9a-fA-F]', '');

% 檢查資料量是否符合預期影像大小
total_coeffs = w * h;
if length(raw_content) < total_coeffs * hex_width
    warning('警告: dct_out.txt 資料長度不足，重建影像可能不完整。');
end

% --- 解析 Hex 為 Signed Decimal (18-bit Signed) ---
dct_coeffs = zeros(total_coeffs, 1);
max_pos    = 2^(bit_depth - 1) - 1; 
mask_neg   = 2^bit_depth;         

for k = 1:total_coeffs
    idx_start = (k-1) * hex_width + 1;
    idx_end   = idx_start + hex_width - 1;
    
    if idx_end > length(raw_content), break; end
    
    hex_str = raw_content(idx_start:idx_end);
    val     = hex2dec(hex_str);
    
    % 處理 2's Complement 負數轉換
    if val > max_pos
        val = val - mask_neg;
    end
    
    dct_coeffs(k) = val;
end

%% 4. 重建影像 (Block-based IDCT Process)
% 使用軟體 IDCT 進行影像還原以評估硬體精度 [cite: 17]
reconstructed_img = zeros(h, w);
idx               = 1;

for r = 1:block_size:h
    for c = 1:block_size:w
        if idx + 63 > length(dct_coeffs), break; end
        
        % 取出一個 8x8 Block (64 個係數)
        block_data = dct_coeffs(idx : idx+63);
        idx        = idx + 64;
        
        % --- 矩陣方向修正 (Matrix Orientation Fix) ---
        % 硬體輸出採 Row-Major (橫向優先)，MATLAB reshape 採 Column-Major (縱向優先)
        % 因此 reshape 後需執行轉置 (') 以還原正確的空間排列
        dct_block = reshape(block_data, 8, 8).'; 
        
        % 執行 2D IDCT [cite: 15]
        rec_block = idct2(dct_block);
        
        % 將還原後的 Block 填回影像
        reconstructed_img(r:r+7, c:c+7) = rec_block;
    end
end

%% 5. 後處理與 PSNR 評估 (Post-processing & PSNR)
% 限制數值範圍於 8-bit 區間 (0~255)
reconstructed_img(reconstructed_img > 255) = 255;
reconstructed_img(reconstructed_img < 0) = 0;

% 影像顯示對比
figure; 
subplot(1,2,1); imshow(uint8(lena_gt)); title('Original');
subplot(1,2,2); imshow(uint8(reconstructed_img)); title('Reconstructed (Fixed)');

% 計算與顯示結果
fprintf('============================================\n');
fprintf('   DCT Hardware Verification Result\n');
fprintf('============================================\n');
psnr(lena_gt, reconstructed_img); 
fprintf('--------------------------------------------\n');
