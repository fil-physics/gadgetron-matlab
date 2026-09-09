function next = morse_unfold_unaccelerated(input, PPIparams)

%% %**************************************************************************
%
%   morse_unfold_unaccelerated computes sensitivities using MORSE and compute SENSE-1
%   recon via S^H * data
%       input "data" contains:
%               a global header in .reference
%               filtered k-space in .data as [N_coils, RO, PE1, PE2, echoes, sets]
%
%       output "data" contains:
%               a global header in .reference
%               image domain SENSE-1 recon [1 RO, PE1, PE2, echoes, sets]
%               (singleton dimension needed to send to database)
%
%**************************************************************************

%% Reconstruction Parameters, Filenames and Switches
global w N_ref N_order onlineROFT scaleKsp

if strcmp(w, 'auto')
    % Smoothing for sensitiviy calculation in physical units (4 mm)
    % adapts "w" to the resolution ~0.6 mm (res) -> 6 voxels and 1.2 mm (res) -> 3 voxels
    w = 6 * 0.8 / geomean([PPIparams.FoV.y/PPIparams.matSize.y, PPIparams.FoV.z/PPIparams.matSize.z]);
end
disp("w = " + w + " voxels.");
PAD                 = w*[0 0 0];           % Padding for smoothing

% Apply constraint: N_order capped at number of references
if length(N_ref) == 1
    % No sensitivity gradients considered
    N_order = min(N_ref, N_order);
else
    % Including sensitivity gradients
    N_order = min(N_ref(1) + 3*N_ref(2), N_order);
end

    function data = morse_unfold_unaccelerated(data)

        if (PPIparams.accPE > 1) || (PPIparams.acc3D > 1)
            error('Expecting fully sampled acquisition')
        else
            % k-space Separate reference data => use to compute sensitivities
            data.data = permute(data.data, [2 3 4 1 5 6]).*scaleKsp;
            
            if ~onlineROFT
                % RO in k-space.
                
                % Prepare to save k-space reference
                data.ref = data.data(:,:,:,:,1,1);
                
                % FT RO to image domain
                data.data = gadgetron.FIL.utils.cifftn(data.data, 1);
            else 
                % RO in image space

                % Prepare to save k-space reference
                data.ref = gadgetron.FIL.utils.cifftn(data.data(:,:,:,:,1,1), 1);
            end

            [RO, PE1, PE2, N_coils, nEchoes, nSets] = size(data.data);
        end

        %% Calculate Sensitivities
        % We assume readout oversampling has been removed:
        % Output (sens) is [RO, PE1, PE2, N_order, N_coils]
        tic
        [sens, regu, data.noise_cov] = gadgetron.FIL.utils.morse_estimate_sensitivities(data.data(:,:,:,:,1,1), PAD, PPIparams);
                    
        % FFT along PE dimensions (this happens to ref in
        % morse_estimates_sensitivities) (into image domain)
        data.data = gadgetron.FIL.utils.cifftn(data.data, 2:3);

        % Remove partition (slab) oversampling in image domain
        reconZ = PPIparams.reconMatSize.z;
        if reconZ < PE2
            zStart = floor((PE2 - reconZ) / 2) + 1;
            zEnd = zStart + reconZ - 1;
            data.data = data.data(:, :, zStart:zEnd, :, :, :);
            sens = sens(:, :, zStart:zEnd, :, :);
            regu = regu(:, :, zStart:zEnd, :);
        end

        % SENSE combination (should match the order)
        % because it should be fully sampled:
        accPE = 1; acc3D = 1;
        % Calculate psuedo-inverse
        pinv_sens = gadgetron.FIL.utils.morse_pseudoinvert_sensitivities(sens, regu, accPE, acc3D); % [N_alias N_coil RO PE1_acq PE2_acq]
        [~, ~, ~, PE1_over_accPE, PE2_over_acc3D] = size(pinv_sens);
        
        % Permute data for pagemtimes configuration
        [RO, PE1, PE2, ~,~] = size(data.data);
        % Permute and add singleton dimension so pagemtimes operates as required
        data.data = permute(data.data, [4 6 1 2 3 5]);

        % Unfold
        outputData = pagemtimes(pinv_sens, data.data);
       
        % Separate dimensions
        outputData = reshape(outputData, accPE, acc3D, RO, PE1_over_accPE, PE2_over_acc3D, []);
        % Reorder to bring aliases and acquired PEs together
        outputData = permute(outputData, [3 4 1 5 2 6]); % [RO PE1_over_accPE accPE PE2_over_acc3D acc3D]
        % Collect and update data.data with expected size
        outputData = reshape(outputData, 1,RO, PE1, PE2, nEchoes,nSets);
        
        data.data = outputData;
        % data.sensitivities = sens;

        toc

    end
    next = @() morse_unfold_unaccelerated(input());
end

