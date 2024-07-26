function sens = vrc_phase_correction(sens, ref_mag, measID, N_coils, gadNoiseDir, scaleNoiseCov, vrc_mask_thr, noise_cov_power)

%**************************************************************************
%
%   vrc_phase_correction
%
%       input   sens: image space sensitivities [RO, PE1, PE2, N_order, N_coils]
%               ref_mag: root sum of squares of separate channel reference magnitude data
%               measID: measurement ID for noise adjustment
%               N_coils: number of coils
%               gadNoiseDir: location of noise covariance matrix
%               scaleNoiseCov: empirical scaling for numerical stability
%
%       output  sens: image space sensitivities after VRC correction [RO, PE1, PE2, N_order, N_coils]
%
%**************************************************************************

%% Loading noise covariance matrix from a serialised file saved by NoiseAdjustGadget:

% create a structure with directory content:
dirc = dir(gadNoiseDir);

% if no noise pre-whitening was performed, no correlation operation is performed:
sens_corr = sens(:,:,:,1,:);

% Need to be able to find a file in gadNoiseDir and for it to have the same ID as measID.
if ~isempty(dirc)
    % filtering out all folders to get only file names:
    dirc = dirc(find(~cellfun(@isfolder,cellfun(@fullfile, {dirc(:).folder},{dirc(:).name}, 'UniformOutput', false))));
    
    % dirc.datenum field increases in chronological order and we need the last one:
    [~,LatestFileIndex] = max([dirc(:).datenum]);
    if ~isempty(LatestFileIndex)
        noise_cov_latestfile = fullfile(dirc(LatestFileIndex).folder,dirc(LatestFileIndex).name);

        noise_cov_measID = textread(noise_cov_latestfile, '%c');
        noise_cov_measID = extractBetween(noise_cov_measID(:)', '<measurementID>','</measurementID>') ;

        % Siemens-specific allowance for retro recon on VE11c
        % noise_cov_measID will have two cell entries: the original meadID and the retro-recon measID 
        % starting with 300000.  Retain only the first to match what is passed to this function.
        if strcmp(measID, noise_cov_measID(1))

                disp('loading noise covariance')
                fid = fopen(noise_cov_latestfile);
                % below 8 = 2*4, 2 is for real and imaginary and 4 is for byte single data type
                % and this is per element of covariance matrix with N_coils*N_coils elements:
                fseek(fid, -N_coils*N_coils*8, 1);
                noise_cov = fread(fid, 'single=>single');
                noise_cov = reshape(noise_cov, [2 N_coils N_coils]);
                noise_cov = squeeze(noise_cov(1,:,:) + 1i*noise_cov(2,:,:));
                noise_cov = noise_cov*scaleNoiseCov;
                fclose(fid);
                
                disp('correlating (i.e. unwhitening) the sensitivities (necessary for robust VRC estimation)')
                sz = size(sens);
                sens_corr = reshape(sens(:,:,:,1,:), [], N_coils);
                sens_corr = sens_corr*chol(noise_cov,'upper')^noise_cov_power;
                sens_corr = reshape(sens_corr, sz(1), sz(2), sz(3), [], N_coils);
        else
            warning('meas ID for data and noise covariance file are different')
            warning('correlation of the sensitivities for robust VRC astimation will not be performed')
        end
    else
        warning('no noise covariance matrix available in the storage directory')
        warning('correlation of the sensitivities for robust VRC astimation will not be performed')        
    end
end

% VRC phase correction is performed (regardless of whether noise pre-whitening was performed):
disp('VRC phase correction')
sens_diff = zeros(size(sens(:,:,:,1,:))); % correct only the first N_order

% selection of a seed voxel for phase matching
% seed voxel defined as a weighted centroid of a masked ROI
mask = imbinarize(ref_mag,mean(ref_mag(:))*vrc_mask_thr) ;
props = regionprops3(mask,ref_mag, 'WeightedCentroid', 'Volume', 'VoxelIdxList');
[~, idx_maxvol] = max(props.Volume);
centroid = round(props.WeightedCentroid(idx_maxvol, :));
centroid = centroid([2 1 3]); % in MATLAB centroid's 1st and 2nd dimentions are swapped - this reverses the process


for ch = 1 : N_coils
    % Coil-wise phasing at seed voxel location:
    sens_diff(:,:,:,1,ch) = sens_corr(:,:,:,1,ch).*exp(-1i*angle(sens_corr(centroid(1),centroid(2), centroid(3),1,ch)));
end

% Sum over coils to get virtual reference coil (VRC) phase, which is then removed:
sens_sum = sum(sens_diff, 5);

sens(:,:,:,1,:) = sens(:,:,:,1,:).*exp(-1i*angle(sens_sum)) ;




