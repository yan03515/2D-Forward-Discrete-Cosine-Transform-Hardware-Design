%% ========================================================================
%% 8x8 2D-DCT Hardware Output Verification & Image Reconstruction
%% ========================================================================
%  Project: Forward DCT Circuit Design (FDCT) [cite: 6]
%  Target Image: Lena 256x256 [cite: 29, 30]
%  Algorithm: Row-Column Decomposition [cite: 68, 72]
%% ========================================================================

clear; clc; close all;

%% Parameters Setup
hex_width  = 5;          % Minimum 5 hex chars for 18-bit data (2^18 = 262144)
bit_depth  = 18;         % Signed 18-bit output 
block_size = 8;          % 8x8 Micro block DCT
w          = 256;        % Image Width
h          = 256;        % Image Height

%% Load Original Image (Ground Truth)
img_path = 'lena_256.bmp';
if exist(img_path, 'file')
    [lena_gt, ~] = imread(img_path);
    lena_gt      = double(lena_gt);
else
    error('Error: Could not find original image file: %s', img_path);
end

%% Read and Parse Hardware Output
data_path = 'dct_out.txt';
if exist(data_path, 'file')
    fid         = fopen(data_path, 'r');
    raw_content = fscanf(fid, '%c'); 
    fclose(fid);
else
    error('Error: Could not find hardware output file: %s', data_path);
end

% --- Data Cleaning ---
% Remove specific labels/tags and non-hex characters to ensure data continuity
raw_content = regexprep(raw_content, '\', ''); 
raw_content = regexprep(raw_content, '[^0-9a-fA-F]', '');

% Check if the data length matches the expected image size
total_coeffs = w * h;
if length(raw_content) < total_coeffs * hex_width
    warning('Warning: Insufficient data length in dct_out.txt. Image may be incomplete.');
end

% --- Parse Hex to Signed Decimal (18-bit Signed) ---
dct_coeffs = zeros(total_coeffs, 1);
max_pos    = 2^(bit_depth - 1) - 1; 
mask_neg   = 2^bit_depth;         

for k = 1:total_coeffs
    idx_start = (k-1) * hex_width + 1;
    idx_end   = idx_start + hex_width - 1;
    
    if idx_end > length(raw_content), break; end
    
    hex_str = raw_content(idx_start:idx_end);
    val     = hex2dec(hex_str);
    
    % Handle 2's Complement for negative values
    if val > max_pos
        val = val - mask_neg;
    end
    
    dct_coeffs(k) = val;
end

%% Image Reconstruction (Block-based IDCT Processing)
% Perform software-based IDCT to verify hardware precision
reconstructed_img = zeros(h, w);
idx               = 1;

for r = 1:block_size:h
    for c = 1:block_size:w
        if idx + 63 > length(dct_coeffs), break; end
        
        % Extract a 64-coefficient block (8x8)
        block_data = dct_coeffs(idx : idx+63);
        idx        = idx + 64;
        
        % --- Matrix Orientation Fix ---
        % Hardware outputs in Row-Major order. MATLAB reshape uses Column-Major. 
        % Transpose (.') is required after reshape to restore correct spatial alignment.
        dct_block = reshape(block_data, 8, 8).'; 
        
        % Execute 2D IDCT (Standard Software IDCT)
        rec_block = idct2(dct_block);
        
        % Store the reconstructed block back into the image array
        reconstructed_img(r:r+7, c:c+7) = rec_block;
    end
end

%% Post-processing and PSNR Evaluation
% Clip values to valid 8-bit range (0-255)
reconstructed_img(reconstructed_img > 255) = 255;
reconstructed_img(reconstructed_img < 0) = 0;

% Display Comparison
figure; 
subplot(1,2,1); imshow(uint8(lena_gt)); title('Original');
subplot(1,2,2); imshow(uint8(reconstructed_img)); title('Reconstructed (Fixed)');

% Print Results to Command Window
fprintf('============================================\n');
fprintf('   DCT Hardware Verification Result\n');
fprintf('============================================\n');
psnr(lena_gt, reconstructed_img); 
fprintf('--------------------------------------------\n');

