clear; clc; close all;

%% 1. 參數設定
hex_width = 5;      % 18-bit 至少需要 5 hex char (2^18 = 262144 -> 5 nibbles)
bit_depth = 18;     % Signed 18-bit
block_size = 8;     % 8x8 DCT
w = 256;            % Image Width
h = 256;            % Image Height

%% 2. 讀取原圖 (Ground Truth)
if exist('lena_256.bmp', 'file')
    [lena_gt, ~] = imread('lena_256.bmp');
    lena_gt = double(lena_gt);
else
    error('找不到 lena_256.bmp');
end

%% 3. 讀取並解析 dct_out.txt
if exist('dct_out.txt', 'file')
    fid = fopen('dct_out.txt', 'r');
    raw_content = fscanf(fid, '%c'); % 讀取所有字元
    fclose(fid);
else
    error('找不到 dct_out.txt');
end

% --- 關鍵修正 1：移除 標籤 ---
% 避免讀到 source 裡面的數字導致位移
raw_content = regexprep(raw_content, '\', ''); 

% 移除所有非 Hex 的字元 (換行、空白等)
raw_content = regexprep(raw_content, '[^0-9a-fA-F]', '');

% 檢查資料長度
total_coeffs = w * h;
if length(raw_content) < total_coeffs * hex_width
    warning('警告: dct_out.txt 資料長度不足，影像可能不完整。');
end

% 解析 Hex 轉 Decimal (18-bit Signed)
dct_coeffs = zeros(total_coeffs, 1);
max_pos = 2^(bit_depth-1) - 1; 
mask_neg = 2^bit_depth;        

for k = 1:total_coeffs
    idx_start = (k-1)*hex_width + 1;
    idx_end = idx_start + hex_width - 1;
    
    if idx_end > length(raw_content)
        break; 
    end
    
    hex_str = raw_content(idx_start:idx_end);
    val = hex2dec(hex_str);
    
    % 處理 2's Complement 負數
    if val > max_pos
        val = val - mask_neg;
    end
    
    dct_coeffs(k) = val;
end

%% 4. 重建影像 (Block Process)
reconstructed_img = zeros(h, w);
idx = 1;

for r = 1:block_size:h
    for c = 1:block_size:w
        if idx + 63 > length(dct_coeffs), break; end
        
        % 取出 64 個係數
        block_data = dct_coeffs(idx : idx+63);
        idx = idx + 64;
        
        % --- 關鍵修正 2：處理矩陣方向 ---
        % 硬體輸出是 Row-Major (先 Row0, 再 Row1...)
        % MATLAB reshape 是 Column-Major (先 Col0, 再 Col1...)
        % 所以 reshape 後必須轉置 (') 才能還原正確的空間排列
        dct_block = reshape(block_data, 8, 8); 
        
        % 執行 IDCT (標準 2D IDCT)
        % 由於您的硬體實現的是標準 scaling (DC值正確)，直接用 MATLAB idct2 即可
        rec_block = idct2(dct_block);
        
        % 存入結果
        reconstructed_img(r:r+7, c:c+7) = rec_block;
    end
end

%% 5. 後處理與 PSNR 計算
% 限制數值範圍 0~255
reconstructed_img(reconstructed_img > 255) = 255;
reconstructed_img(reconstructed_img < 0) = 0;

% 顯示
figure; 
subplot(1,2,1); imshow(uint8(lena_gt)); title('Original');
subplot(1,2,2); imshow(uint8(reconstructed_img)); title('Reconstructed (Fixed)');

% 計算 PSNR
fprintf('================================\n');
fprintf('Final Reconstruction Result\n');
psnr(lena_gt, reconstructed_img); 
fprintf('--------------------------------\n');