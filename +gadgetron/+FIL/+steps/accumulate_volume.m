%%
%**************************************************************************
%
%   accumulate_volume collects blocks of [ADC, N_coils] acquisitions.
%       input:  bucket of data from AcquisitionAccumulateTriggerGadget
%               when no trigger dimension is specified => full volume.
%       header: header structure used to get info about over-sampling
%       onlineROFT: optional FT along RO direction, defaults to false for
%                   back-compatibility.
%
%       output "data" contains:
%               a global header in .reference
%               k-space in .data as [N_coils, RO, PE1, PE2, echoes, sets]
%
%       Optional Output:
%               If integrated reference data & sensitivity_function = MORSE
%                   image domain regularised pseudo-invserse of sensitivities in .sensitivities
%               If integreated reference data & sensitivity_function = ESPIRiT
%                   image domain sensitivities in .sensitivities
%
%**************************************************************************

function next = accumulate_volume(input, header, sensitivity_function, onlineROFT)

arguments
    input
    header

    % These parameters are given defaults for back-compatibility, e.g.
    % ReconBSS, in that case only false for onlineROFT is relevant.
    sensitivity_function = @gadgetron.FIL.utils.morse_calc_pinv;
    onlineROFT = false;
end
global gadNoiseDir smap_noise_cov
ACQ_IS_REVERSE = bitshift(uint64(1), 21);
kspace_centre_line_no_y = [];
kspace_centre_line_no_z = [];
matrix_size = header.encoding.encodedSpace.matrixSize; % [x,y,z]
nEchoes     = header.encoding.encodingLimits.contrast.maximum+1;
nSets       = header.encoding.encodingLimits.set.maximum+1;

PPIparams = gadgetron.FIL.utils.get_PPI_params(header);
if strcmp(header.encoding.parallelImaging.calibrationMode, 'embedded')
    nRefToCollect = PPIparams.totalRefLines;
end

% Zero-pad k-space for odd acceleration factors or matrix sizes to ensure matrix divisibility.
if mod(matrix_size.y,PPIparams.accPE)>0
    matrix_size.y_padded = ceil(matrix_size.y/PPIparams.accPE/2)*PPIparams.accPE*2;
else
    matrix_size.y_padded = matrix_size.y;
end
if mod(matrix_size.z,PPIparams.acc3D)>0
    matrix_size.z_padded = ceil(matrix_size.z/PPIparams.acc3D/2)*PPIparams.acc3D*2;
else
    matrix_size.z_padded = matrix_size.z;
end

disp('accumulate_volume setup...')

    function data = accumulate_volume(bucket, data)

        disp("Assembling buffer from bucket containing " + num2str(bucket.data.count + bucket.ref.count) + " acquisitions...");

        if isempty(data)

            % Only declare data on its first call, otherwise it will be
            % over-written.
            disp('data empty => first call, creating structure')

            % Single data header for reference (used elsewhere in Gadgetron, e.g. create_ismrmrd_image)
            data.reference = structfun(@(arr) arr(:, 1)', bucket.data.header, 'UniformOutput', false);

            % data.data arranged as [N_coils, RO, PE1, PE2, echoes, sets]
            data.data = zeros( ...
                size(bucket.data.data, 2), ...
                size(bucket.data.data, 1), ...
                matrix_size.y_padded, ...
                matrix_size.z_padded, ...
                nEchoes, ...
                nSets, ...
                'like', ...
                single(1i)...
                );

            if strcmp(PPIparams.refType, 'embedded') % MPM's v1 - Int. References

                disp('Recon of undersampled data with embedded references')

                % data.sensitivities arranged as [RO, PE1, PE2, N_coils]
                data.sensitivities = zeros( ...
                    size(bucket.data.data, 1), ...
                    matrix_size.y_padded, ...
                    matrix_size.z_padded, ...
                    size(bucket.data.data, 2), ...
                    'like', ...
                    single(1i)...
                    );

                nRefToCollect = PPIparams.totalRefLines;

            elseif strcmp(PPIparams.refType, 'separate') % MPM's v2 - Separate Reference

                disp('Reading in sensitivity data for subsequent unfolding')

                % data.sensitivities arranged as [RO, PE1, PE2, N_coils]
                data.sensitivities = zeros( ...
                    size(bucket.data.data, 1), ...
                    matrix_size.y_padded, ...
                    matrix_size.z_padded, ...
                    size(bucket.data.data, 2), ...
                    'like', ...
                    single(1i)...
                    );

                % Read in sensitivity information from previous smaps:
                pn = [gadNoiseDir filesep 'database-FIL'];
                MeasID = header.measurementInformation.measurementID;
                MID_parts = split(MeasID, '_');
                targetMID = str2double(MID_parts{4});
                MID_parts = [MID_parts{1} '_' MID_parts{2} '_' MID_parts{3} '_' ];
                % Search for number that is closest to current MID
                attempt = 1;
                while ~exist('smap_data','var')
                    targetMID = targetMID - 1;
                    smap_dataFn = fullfile(pn, [MID_parts num2str(targetMID) '_sensitivity.mat']);
                    try
                        smap_data = load(smap_dataFn).data;
                        disp(['Succesfully read in ' smap_dataFn])
                        if attempt > 2
                            disp(['Warning! s-map data may originate from previous scan ' smap_dataFn])
                        end
                    catch
                        if attempt < 10
                            attempt = attempt + 1;
                        else
                            error('Failed: Could not find sensitivity information');
                        end
                    end
                end

                % Sensitivity data found => insert into target matrix and estimate
                % sensitivities, and regularisation factor.
                [sRO, sPE1, sPE2, ~] = size(smap_data.ref); % k-space

                % smap_data.ref stored by morse_unfold_unaccelerated as [RO, PE1, PE2,
                % N_coils], in k-space.
                % Pad this ref k-space data to match the dimensions of the
                % undersampled data it is going to unfold. If morse_sense_one is
                % preceeded by tukey_filter step it will have been filtered to zero
                % at the k-space periphery so this should not introduce Gibbs ringing.
                cRO = sRO/2; cPE1 = sPE1/2; cPE2 = sPE2/2; % k-space centre
                data.sensitivities(end/2-cRO+1:end/2+cRO,end/2-cPE1+1:end/2+cPE1,end/2-cPE2+1:end/2+cPE2,:,:) = smap_data.ref;

                % Fill noise covariance matrix
                smap_noise_cov = smap_data.noise_cov;%; % used in utilities
                data.noise_cov = smap_data.noise_cov;%; % used in steps

                % For whitening on entry
                L = chol(smap_noise_cov,'upper');
                data.L_inv = inv(L);

                % Compute regularised pseudo-inverse of sensitivities. Reference data passed on full target matrix.
                data.sensitivities = sensitivity_function(data.sensitivities, PPIparams);

            elseif strcmp(PPIparams.refType, 'other') % s-maps
                disp('No acceleration. No sensitivities being retrieved')
            end

        end

        % Time reversal and potentially online FT in RO direction
        if bucket.data.count > 0
            % Time-reverse acquisitions marked with ACQ_IS_REVERSE flag.
            % Only check odd echoes (0-based) to avoid unnecessary bitand
            % operations on echoes that are never reversed.
            odd_echo = mod(bucket.data.header.contrast, 2) == 1;
            to_reverse = odd_echo & bitand(bucket.data.header.flags, ACQ_IS_REVERSE) > 0;
            bucket.data.data(:,:,to_reverse)= bucket.data.data(end:-1:1,:,to_reverse);

            if onlineROFT
                % Perform first FT
                bucket.data.data = gadgetron.FIL.utils.cifftn(bucket.data.data,1);
            end
        end
        if bucket.ref.count > 0 && onlineROFT
            odd_echo = mod(bucket.ref.header.contrast, 2) == 1;
            to_reverse = odd_echo & bitand(bucket.ref.header.flags, ACQ_IS_REVERSE) > 0;
            bucket.ref.data(:,:,to_reverse)= bucket.ref.data(end:-1:1,:,to_reverse);
            bucket.ref.data = gadgetron.FIL.utils.cifftn(bucket.ref.data,1);
        end
        if isempty(kspace_centre_line_no_y)
            kspace_centre_line_no_y = bucket.data.header.user(6);
            kspace_centre_line_no_z = bucket.data.header.user(7);
        end

        % Ensure k-space center includes the central line in PE and 3D directions for odd acceleration with padding and partial Fourier cases.
        encode_step_1 = bucket.data.header.kspace_encode_step_1+matrix_size.y_padded/2-kspace_centre_line_no_y;
        encode_step_2 = bucket.data.header.kspace_encode_step_2+matrix_size.z_padded/2-kspace_centre_line_no_z;
        contrast = bucket.data.header.contrast;
        set = bucket.data.header.set;
        idx = sub2ind(size(data.data, 3:6), encode_step_1+1, encode_step_2+1, contrast+1, set+1) ;
        % whitening data upon accumulation when using separate reference
        if strcmp(PPIparams.refType, 'separate') && size(data.noise_cov,1)~= 0  % s-maps with noise adjust data
            data.data(:, :, idx) = permute(pagemtimes(bucket.data.data,data.L_inv),[2 1 3]);
        else
            data.data(:, :, idx) = permute(bucket.data.data,[2 1 3]);
        end

        for ind = 1:bucket.ref.count

            % If reference lines are embedded they need to be gathered.
            % When no more reference lines remain to be collected, the
            % sensitivities are calculated. This is done for echo 1.

            contrast = bucket.ref.header.contrast(ind);

            if contrast == 0
                % Ensure k-space center includes the central line in PE and 3D directions for odd acceleration with padding and partial Fourier cases.
                encode_step_1 = bucket.ref.header.kspace_encode_step_1(ind)+matrix_size.y_padded/2-kspace_centre_line_no_y;
                encode_step_2 = bucket.ref.header.kspace_encode_step_2(ind)+matrix_size.z_padded/2-kspace_centre_line_no_z;

                data.sensitivities(:, encode_step_1+1, encode_step_2+1, :) = bucket.ref.data(:,:,ind);

                nRefToCollect = nRefToCollect - 1; % decrement until 0
                if nRefToCollect == 0
                    disp('Calculating sensitivities and regularised pseudo-inverse...')

                    % Compute regularised pseudo-inverse of sensitivities. Reference data passed on full target matrix.
                    data.sensitivities = sensitivity_function(data.sensitivities, PPIparams);

                end % Calc sensitivities

            end % Echoes

        end % Reference buckets

        if ~isempty(bucket.data.header.flags)
            % There is data...
            lastHeader = structfun(@(arr) arr(:, end)', bucket.data.header, 'UniformOutput', false);
            acq = gadgetron.types.Acquisition(lastHeader, bucket.data.data(:,:,end), []);
        else
            % Must be reference only lines...
            lastHeader = structfun(@(arr) arr(:, end)', bucket.ref.header, 'UniformOutput', false);
            acq = gadgetron.types.Acquisition(lastHeader, bucket.ref.data(:,:,end), []);
        end

        if ~acq.is_flag_set(acq.ACQ_LAST_IN_MEASUREMENT)
            disp('Not end of measurement, accumulating...')
            if strcmp(PPIparams.refType, 'embedded')
                subplot 121
                imagesc(squeeze(abs(data.data(1,end/2,:,:,1,1)))) % temp display
                title('Data')

                subplot 122
                imagesc(squeeze(abs(data.sensitivities(end/2,:,:,1)))) % temp display
                title('Final Sensitivity')
                drawnow
            else
                imagesc(squeeze(abs(data.data(1,end/2,:,:,1,1))))
            end
            drawnow;
            data = accumulate_volume(input(), data);
        else
            disp('End of measurement...')
            if strcmp(PPIparams.refType, 'embedded')
                subplot 121
                imagesc(squeeze(abs(data.data(1,end/2,:,:,1,1)))) % temp display
                title('Final Data')
                subplot 122
                imagesc(squeeze(abs(data.sensitivities(end/2,:,:,1)))) % temp display
                title('Final Sensitivity')
            else
                imagesc(squeeze(abs(data.data(1,end/2,:,:,1,1))))
                title('Final Data')
            end
            drawnow
        end

    end

next = @() accumulate_volume(input(), []);
end
