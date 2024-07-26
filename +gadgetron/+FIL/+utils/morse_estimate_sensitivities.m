function [sens, regu] = morse_estimate_sensitivities(ref, PAD, measID)
%**************************************************************************
%
%   morse_estimate_sensitivities
%       input   ref: data for sensitivity estimation post apodisation
%                       [RO, PE1, PE2, N_coils]
%               PAD: amount of padding when smoothing E = w*[x, y, z] voxels
%               measID: measurement ID for noise adjustment
%
%       output  sens: image space sensitivities [RO, PE1, PE2, N_order, N_coils]
%               regu: regularisation maps [RO, PE1, PE2, N_order]
%
%**************************************************************************
global gadNoiseDir scaleNoiseCov vrc_mask_thr noise_cov_power ph_correction w N_ref N_order sens_grad_scale lambda

%% Josephs et al. 2.2.1 Reduced voxel-wise computation
% Extract only the reference data for computational efficiency
[RO, PE1, PE2, N_coils] = size(ref);
ref = reshape(ref, [], N_coils);      %[RO*PE1*PE2, N_coils]
mask = any(ref~=0, 2);
smallref = ref(mask, :);            % [RO*nRefPE*nRef3D N_coils]

% Transform to virtual coil space
disp('coil svd');
[U,S,V] = svd(smallref, 'econ');

% smallref still has full coil dimensions, but with ever-decreasing variance across columns.
smallref = U*S;

% Return non-zero elements to original positions in full ref matrix:
ref(mask, :) = smallref;
ref = reshape(ref, [RO, PE1, PE2, N_coils]);

% Apply iFFT to image space
% Note: assumes iFFT already applied in the RO direction at the time of RO oversampling removal
ref = gadgetron.FIL.utils.cifftn(ref, 2:3);

% Introducing singleton dimension allows eigen outer product to be formed by simple multiplication:
% i.e. [RO, PE1, PE2, N_coils] .* [RO, PE1, PE2, 1, N_coils]
% Note: now we retain all target coils but only N_ref(1) reference coils
E = conj(ref(:,:,:,1:N_ref(1))).*permute(ref,[1 2 3 5 4]); % TO DO: REverse conjugate order to match paper?


%% Josephs et al. 2.2.2 Weighted Least Squares
% Apply smoothing in all three spatial dimensions (Eq. 8):
% Note: E is reused for memory efficiency.
E = gadgetron.FIL.utils.mysmooth(E, w, PAD);


%% Josephs et al. 2.2.5 Incorporating sensitivity gradients
if length(N_ref) > 1
    disp('Appending sensitivity gradients')
    % Append centred, finite-difference estimate(s) of sensitivity gradients in each spatial direction.
    E_subset = sens_grad_scale * E(:,:,:,1:N_ref(2),:);
    E=cat(4,E,circshift(E_subset,1,1)-circshift(E_subset,-1,1),...
        circshift(E_subset,1,2)-circshift(E_subset,-1,2),...
        circshift(E_subset,1,3)-circshift(E_subset,-1,3));
end


%% Josephs et al. 2.2.3 Higher-order sensitivity estimation
disp('E svd');
% Voxel-wise SVD of E^w (Eq. 9)
% Permute to bring (eigen) targets-by-refs dimensions to beginning:
E = permute(E,[5 4 1 2 3]);           % [N_coils, N_ref, RO, PE1, PE2]

% Voxel-wise (economy) SVD and computation of U*S for subsequent sensitivity estimation via normalisation:
% Note: E is reused and S from first SVD is overwritten, both for memory efficiency.
% Compute for all voxels at once.
[E, S, ~] = pagesvd(E, 'econ');

% Restore to original coil space from virtual coil space:
sens = pagemtimes(conj(V), E); % TO DO: why no transpose?

% Restore previous dimension ordering:
sens = ipermute(sens,[5 4 1 2 3]);            % [RO, PE1, PE2, N_ref, N_coils]
S = ipermute(S,[5 4 1 2 3]);                  % [RO, PE1, PE2, N_ref, N_ref]

% selecting diagonal elements from S principal value matrix
S = squeeze(S(:,:,:,1:N_ref+1:end));
% truncating sensitivities up to N_order
sens = sens(:,:,:,1:N_order,:);
% N_order regularisation terms from S principal value maps, (Eq. 13):
regu = lambda ./ (S(:,:,:,1:N_order) + eps);          % [RO, PE1, PE2, N_ref, N_coils]


%% Dymerska et al. Virtual Reference Coil phase correction to obtain phase data
% free from open-ended fringe lines
if strcmp(ph_correction, 'VRC')
    ref_mag = sqrt(sum(abs(ref).^2,4));
    sens = gadgetron.FIL.utils.vrc_phase_correction(sens, ref_mag, measID, N_coils, gadNoiseDir, scaleNoiseCov, vrc_mask_thr, noise_cov_power);
end