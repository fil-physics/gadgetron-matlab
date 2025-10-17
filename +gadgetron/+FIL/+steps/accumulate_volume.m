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

kspace_centre_line_no = [];
matrix_size = header.encoding.encodedSpace.matrixSize; % [x,y,z]
nEchoes     = header.encoding.encodingLimits.contrast.maximum+1;
nSets       = header.encoding.encodingLimits.set.maximum+1;

bEmbedRef = strcmp(header.encoding.parallelImaging.calibrationMode, 'embedded');
if bEmbedRef
    PPIparams = gadgetron.FIL.utils.get_PPI_params(header);
    nRefToCollect = PPIparams.totalRefLines;
else
    % Needed for definition of data and sensitivities field sizes. Set to 1
    % in this case for so that matrices are defined equivalently for back
    % compatibility.
    PPIparams.accPE = 1;
    PPIparams.acc3D = 1;
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
                ceil(matrix_size.y/PPIparams.accPE/2)*PPIparams.accPE*2, ...
                ceil(matrix_size.z/PPIparams.acc3D/2)*PPIparams.acc3D*2, ...
                nEchoes, ...
                nSets, ...
                'like', ...
                single(1i)...
                );

            % data.sensitivities arranged as [RO, PE1, PE2, N_coils]
            data.sensitivities = zeros( ...
                size(bucket.data.data, 1), ...
                ceil(matrix_size.y/PPIparams.accPE/2)*PPIparams.accPE*2, ...
                ceil(matrix_size.z/PPIparams.acc3D/2)*PPIparams.acc3D*2, ...
                size(bucket.data.data, 2), ...
                'like', ...
                single(1i)...
                );
        end

        % Time reversal and potentially online FT in RO direction
        if bucket.data.count > 0
            % Time-reverse even-numbered echoes (note 0-based indexing
            % here) with the preservation of the position of the central
            % k-space line
            to_reverse = mod(bucket.data.header.contrast, 2) == 1;
            bucket.data.data(:,:,to_reverse)= bucket.data.data(end:-1:1,:,to_reverse);

            if onlineROFT
                % Perform first FT
                bucket.data.data = gadgetron.FIL.utils.cifftn(bucket.data.data,1);
            end
        end
        if bucket.ref.count > 0 && onlineROFT
            to_reverse = mod(bucket.ref.header.contrast, 2) == 1;
            bucket.ref.data(:,:,to_reverse)= bucket.ref.data(end:-1:1,:,to_reverse);
            bucket.ref.data = gadgetron.FIL.utils.cifftn(bucket.ref.data,1);
        end
        if isempty(kspace_centre_line_no)
            kspace_centre_line_no = bucket.data.header.user(6);
        end
        for ind = 1:bucket.data.count
            % ensuring k-space centre contains central line in PE1
            % direction also for partial Fourier case
            encode_step_1 = bucket.data.header.kspace_encode_step_1(ind)+matrix_size.y/2-kspace_centre_line_no;
            encode_step_2 = bucket.data.header.kspace_encode_step_2(ind);
            contrast = bucket.data.header.contrast(ind);
            set = bucket.data.header.set(ind);

            data.data(:, :, encode_step_1+1, encode_step_2+1, contrast+1, set+1) = ...
                transpose(squeeze(bucket.data.data(:, :, ind)));

        end % Data buckets

        for ind = 1:bucket.ref.count
            %
            % If reference lines are embedded they need to be gathered.
            % When no more reference lines remain to be collected, the
            % sensitivities are calculated. This is done for echo 1.
            %
            contrast = bucket.ref.header.contrast(ind);

            if contrast == 0
                % ensuring k-space centre contains central line in PE1
                % direction also for partial Fourier case
                encode_step_1 = bucket.ref.header.kspace_encode_step_1(ind)+matrix_size.y/2-kspace_centre_line_no;
                encode_step_2 = bucket.ref.header.kspace_encode_step_2(ind);

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
            subplot 121
            imagesc(squeeze(abs(data.data(1,end/2,:,:,1,1)))) % temp display
            title('Data')
            subplot 122
            imagesc(squeeze(abs(data.sensitivities(end/2,:,:,1)))) % temp display
            title('Sensitivity')
            drawnow;
            data = accumulate_volume(input(), data);
        else

            disp('End of measurement...')
            subplot 121
            imagesc(squeeze(abs(data.data(1,end/2,:,:,1,1)))) % temp display
            title('Final Data')
            subplot 122
            imagesc(squeeze(abs(data.sensitivities(end/2,:,:,1)))) % temp display
            title('Final Sensitivity')
            drawnow
        end

    end

next = @() accumulate_volume(input(), []);
end

