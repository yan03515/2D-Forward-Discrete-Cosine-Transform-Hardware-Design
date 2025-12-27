 function [PSNR, MSE] = psnr(X,Y,k)
% function [PSNR,mse]=psnr(X,Y)
% Peak signal to noise ratio of the difference between images and the mean square error
% If the second input Y is missing then the PSNR and MSE of X itself becomes the output (as if Y=0).
if nargin == 3
    if X == Y
        error('Images are identical: PSNR has infinite value')
    end

    max2_A = max(max(X));
    max2_B = max(max(Y));
    min2_A = min(min(X));
    min2_B = min(min(Y));
    
%     if max2_A > 1 || max2_B > 1 || min2_A < 0 || min2_B < 0
%         error('input matrices must have values in the interval [0,1]')
%     end
    D = X - Y;  
    MSE = sum(sum(D.*D)) / prod(size(X));
    PSNR = 10*log10(1/MSE);
else

    if nargin<2
        D = X;
    else
       if any(size(X)~=size(Y))
           error('The input size is not equal to each other!')
       end
       if X == Y
           error('Images are identical: PSNR has infinite value')
       end
       if (max(max(X)) > 255 || max(max(Y)) > 255 ||  min(min(X)) < 0 ||  min(min(Y)) < 0)
           error('input matrices must have values in the interval [0,255]')
       end

       D = X - Y;   
    end

    MSE = sum(sum(D.*D)) / prod(size(X));
    PSNR = 10*log10(255^2/MSE);
end
disp(sprintf('PSNR = + %5.2f dB',PSNR));
disp(sprintf(['MSE =  ',num2str(MSE)]));