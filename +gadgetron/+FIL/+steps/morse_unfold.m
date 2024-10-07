%**************************************************************************
%
%   morse_unfold unfolds aliased images given pinv of sensitivities.
%       input "data" contains:
%               a global header in .reference
%               acquired, aliased k-space in .data as [N_coils, RO, PE1, PE2, echoes, sets]
%               If sensitivity_function = MORSE, image domain regularised
%                   pseudo-invserse of sensitivities in .sensitivities
%                   stored as [accPE*acc3D, N_coils, RO, PE1/accPE, PE2/acc3D]
%               If sensitivity_function = ESPIRiT image domain sensitivities in .sensitivities
%
%       output "data" contains:
%               a global header in .reference
%               unfolded images in .data as [1, RO, PE1, PE2, echoes, sets]
%               pre-calculated sensitivities in .sensitivities stored as
%                                   [RO, PE1, PE2, N_coils]
%
%**************************************************************************

function next = morse_unfold(input, header)

disp("MORSE unfolding setup...")

global scaleKsp

matrix_size = header.encoding.reconSpace.matrixSize; % [x,y,z]
nEchoes     = header.encoding.encodingLimits.contrast.maximum+1;
nSets       = header.encoding.encodingLimits.set.maximum+1;

bEmbedRef = strcmp(header.encoding.parallelImaging.calibrationMode, 'embedded');
if bEmbedRef
    PPIparams = gadgetron.FIL.utils.get_PPI_params(header);
end


    function data = morse_unfold(data)

        disp("MORSE unfolding execution...")

        disp("2DFT...")
        % Apply iFFT to image space
        % Note: assumes iFFT already applied in the RO direction at the time of RO oversampling removal
        data.data = gadgetron.FIL.utils.cifftn(data.data,3:4) .* scaleKsp;
        toc

        disp("Unfolding...") % TO DO: Why is singleton dimension required?
        [~, ~, ~, PE1_over_accPE, PE2_over_acc3D] = size(data.sensitivities);
        [~, RO, PE1, PE2, ~] = size(data.data);
        accPE = PE1/PE1_over_accPE;
        acc3D = PE2/PE2_over_acc3D;
        
        % Select one aliased segment
        data.data = data.data(:,:, 1:PE1/accPE, 1:PE2/acc3D,:);

        % Add singleton dimension so pagemtimes opterates as required
        data.data = permute(data.data, [1 6 2 3 4 5]);

        % Unfold
        outputData = pagemtimes(data.sensitivities, data.data);

        % Separate dimensions
        outputData = reshape(outputData, accPE, acc3D, RO, PE1_over_accPE, PE2_over_acc3D, []);

        % Reorder to bring aliases and acquired PEs together
        outputData = permute(outputData, [3 4 1 5 2 6]); % [RO PE1_over_accPE accPE PE2_over_acc3D acc3D]
        
        % Collect and update data.data with expected size
        data.data = reshape(outputData, 1, RO, PE1, PE2, nEchoes, nSets);

        if PPIparams.caipiFactor > 0  %%% position of aliased pixels are shifted compared to a conventional acquisition
            
            k = PE1/PPIparams.accPE*PPIparams.caipiFactor/PPIparams.acc3D; % shifts in image alias position in PE direction are multiples of k
            
            for ind = 1 : PPIparams.acc3D-1
                extentInPE2 = ind * PE2/PPIparams.acc3D + (1:PE2/PPIparams.acc3D);
                shiftInPE1 = ind * k;
                
                data.data(1,:,:,extentInPE2,:,:) = circshift(data.data(1,:,:,extentInPE2,:,:), shiftInPE1, 3);
            end
            
        end

        % Display
        clf
        montage(permute(abs(squeeze(data.data(1,1:16:end,:,:,1))),[2 3 1])*2); drawnow;

    end
next = @() morse_unfold(input());
end
