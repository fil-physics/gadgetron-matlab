function next = morse_calc_sens(input, PPIparams)
% FORMAT sens = morse_calc_sens(dat)
% ref    - k-space [RO PE1 PE2 N_coils]

%% Reconstruction Parameters, Filenames and Switches
global scaleKsp w N_ref N_order onlineROFT

PAD                 = w*[0 0 0];           % Padding for smoothing

% Apply constraint: N_order capped at number of references
if length(N_ref) == 1
    % No sensitivity gradients considered
    N_order = min(N_ref, N_order);
else
    % Including sensitivity gradients
    N_order = min(N_ref(1) + 3*N_ref(2), N_order);
end

    function data = morse_calc_sens(data)

        if (PPIparams.accPE == 1) && (PPIparams.acc3D == 1)
            ref = data.data ;
            ref = permute(ref(:,:,:,:,1,1), [2 3 4 1]) ;
            if ~onlineROFT
                ref = gadgetron.FIL.utils.cifftn(ref,1);
                data.data = gadgetron.FIL.utils.cifftn(data.data,2);
            end
            [RO, PE1, PE2, N_coils, ~] = size(ref);
        else
            ref = data.sensitivities ;
            if ~onlineROFT
                ref = gadgetron.FIL.utils.cifftn(ref,1);
            end
            [RO, PE1, PE2, N_coils, ~] = size(ref);

            %% Apodise the reference data (in hybrid space)
            % Define a two-dimensional apodisation window
            tw1=tukeywin(PPIparams.refPE+2,0.5);    % NB tukeywin starts and ends with zeros
            tw2=tukeywin(PPIparams.ref3D+2,0.5);
            tw12=tw1(2:end-1).*tw2(2:end-1)';       % [1 refPE ref3D]
            % Apodise reference data (TE1)
            refmask=any(ref,[1 4]);                 % [1 pe1 pe2]
            refwin=zeros(size(refmask),'single');   % [1 refPE ref3D]
            refwin(refmask)=tw12;                   % sets non-zero entries
            ref=ref.*refwin.*scaleKsp;              % apply the apodising function & scale

        end

        %% Calculate Sensitivities
        % Don't do 3D FT here because data are sparsest in the projection domain.
        % This allows significant speed-up of the slab-specific coil svd in
        % morse_estimate_sensitivities().
        % We assume readout oversampling has been removed:
        tic
        pinv_sens = zeros(PPIparams.accPE*PPIparams.acc3D, N_coils, RO, PE1/PPIparams.accPE, PE2/PPIparams.acc3D, 'like', ref);
        [sens, regu] = gadgetron.FIL.utils.morse_estimate_sensitivities(ref, PAD, PPIparams.measID);
        toc
        %% Compute pseudo-inverse of sensitivities
        pinv_sens(:,:,:,:,:) = gadgetron.FIL.utils.morse_pseudoinvert_sensitivities(sens(:,:,:,1:N_order,:), regu, PPIparams.accPE, PPIparams.acc3D);

        % Calculating image scaling factor to remove bias field
        pinv_sens_sos = sqrt(sum(abs(pinv_sens).^2,2)) ;
        data.reference.pinv_sens_sos = squeeze(pinv_sens_sos);
        data.sensitivities = pinv_sens;
        toc

    end

next = @() morse_calc_sens(input());
end