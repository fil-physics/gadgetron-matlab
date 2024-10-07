function data = cifftn(data, dims)

% The following code uses less peak memory and is much faster than
% gadgetron.lib.fft.cifft 

% ifind "inverse find" - e.g. ifind([2:3 5], 6) -> [0 1 1 0 1 0]
% Ref: https://uk.mathworks.com/matlabcentral/answers/385217-bed-of-nails-from-vectors-inverse-of-find
ifind = @(indices, length) full(sparse(1, indices, 1, 1, length));

% "ifftshift(data, dims)" (zero freq central point moved to left hand side)
shifts=ceil(size(data)/2) .* ifind(dims, ndims(data));
data=circshift(data, shifts);

for dim = dims
    data = ifft(data, [], dim);
end

% "fftshift(data, dims)" (origin of space moved from left to centre)
shifts=floor(size(data)/2) .* ifind(dims, ndims(data));
data=circshift(data, shifts);

% Match normalisation of original code
data=data.* sqrt(prod(size(data, dims)));
