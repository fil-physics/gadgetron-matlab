function pinv_sens = morse_pseudoinvert_sensitivities(sens, regu, accPE, acc3D)

%**************************************************************************
%
%   morse_pseudoinvert_sensitivities
%       input   sens: sensitivity estimates [RO, PE1, PE2, N_order, N_coils]
%               regu: regularisation maps [RO, PE1, PE2, N_order]
%
%       output  pinv_sens: Unfolding matrix for each position in reduced fov image 
%                           [accPE*acc3D N_coils RO PE1/accPE PE2/acc3D]
%
%**************************************************************************

%% Joesphs et al. 2.2.4 Unfolding in a regularised SENSE framework

% Size info:
[RO, PE1, PE2, N_order, N_coils] = size(sens);

% Reshape into unfolding blocks:
sens = reshape(sens, RO, PE1/accPE, accPE, PE2/acc3D, acc3D, N_order, N_coils);
regu = reshape(regu, RO, PE1/accPE, accPE, PE2/acc3D, acc3D, N_order);

% Collect coils and aliased voxel dimensions to front:
sens = permute(sens,[7 3 5 6 1 2 4]); % [N_coils accPE acc3D N_order RO PE1/accPE PE2/acc3D]
regu = permute(regu,[  3 5 6 1 2 4]); % [      accPE acc3D N_order RO PE1/accPE PE2/acc3D]

% Rearrange sensitivities into N_coil x N_alias*N_order matrix per voxel in aliased space:
sens = reshape(sens, N_coils, accPE*acc3D*N_order, RO*PE1/accPE*PE2/acc3D);

% Rearrange regularisation map into N_alias*N_order vector per voxel in aliased space:
regu = reshape(regu,        accPE*acc3D*N_order, RO*PE1/accPE*PE2/acc3D);

% Diagonalise regularisation values:
regu_diag = zeros(size(regu,1)^2, size(regu,2), 'like',regu);
regu_diag(1:sqrt(end)+1:end, :) = regu;
regu_diag = reshape(regu_diag, size(regu,1), size(regu,1), []);

% Append regularisation to sensitivities:
s = cat(1, sens, regu_diag);

% Copmute pseudo-inverse as inv(S' S)S' 
pinv_sens = pagemtimes(s, 'ctranspose', s, 'none') ; 
pinv_sens = pageinv(pinv_sens);
pinv_sens = pagemtimes(pinv_sens, 'none', s, 'ctranspose');

% Retain only the first N_alias rows of the pseudo-inverse:
pinv_sens = pinv_sens(1:end/N_order,1:N_coils,:);
pinv_sens = reshape(pinv_sens, accPE*acc3D, N_coils, RO, PE1/accPE, PE2/acc3D);