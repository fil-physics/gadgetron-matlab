function v=mysmooth(v,k,p)
%Fast convolution Gaussian smoothing in 3D
%   k: Scalar smoothing kernel for eigencoil calculation in image domain
%    specified in voxels.
%   p: Padding for eigencoil calculation in image space [voxels]; for no
%   padding supply [0,0,0]
% Assumes even padded dimensions

dims=size(v);

% Fourier Transform with padding in all 3 dims:
v=fft(v,dims(1)+p(1),1); % Must include ,1 otherwise might skip singleton dimension
v=fft(v,dims(2)+p(2),2);
v=fft(v,dims(3)+p(3),3);

pad_dims=size(v);

% Gaussian smoothing kernel:
% (ifftshift moves origin of k space from centre (or right of centre for
% even length) to the left-most point
ga=exp(ifftshift(single(-(((1:pad_dims(1))-pad_dims(1)/2-1)'.^2+...
    ((1:pad_dims(2))-pad_dims(2)/2-1).^2+...
    shiftdim(((1:pad_dims(3))-pad_dims(3)/2-1),-1).^2)/k.^2)));
ga=fftn(ga);

% Unit kernel volume in image space <=> unit amplitude at "dc point" in k space
ga=ga/ga(1);

% Apply smoothing kernel via efficient multiplication in k-space:
v=v.*ga;

% Return to image space:
v=ifft(v,[],1);
v=ifft(v,[],2);
v=ifft(v,[],3);

% Extract original dimensions:
if any(p > 0)
    v=v(1:dims(1),1:dims(2),1:dims(3),:,:); % Slow memory access so only once.
end
end