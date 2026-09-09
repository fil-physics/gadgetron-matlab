function ReconMPM(connection)
disp("Matlab MPM Recon launched...")
recon_type = 'MORSE' ; % 'MORSE' or 'ESPIRiT', 'ESPIRiT' recquires installation of the Berkeley Advanced Reconstruction Toolbox (BART) toolbox
disp(['Reconstructing with ', recon_type]);

% Hard-coded reconstruction parameters:
global onlineROFT scaleKsp gadNoiseDir scaleNoiseCov vrc_mask_thr noise_cov_power ph_correction w N_ref N_order sens_grad_scale lambda

gadNoiseDir     = '~/.gadgetron/storage';     % gadgetron noise_cov storage directory, default is '~/.gadgetron/storage', can be changed with gadgetron -S option

PPIparams = gadgetron.FIL.utils.get_PPI_params(connection.header);

% Set up parallel thread pool for use by parfor in functions
if isempty(gcp('nocreate')); parpool('threads'); end

% Reconstruction settings
if strcmp(recon_type, 'MORSE')
    scaleFactor         = 7581.43512;         % empirically established for 0.6 mm isotropic MPMs at 7T, that exact value for back-compatibility, gets scaled by the voxel volume and field strength in create_ismrmrd_3Dvol_and_send
    sensitivity_function = @gadgetron.FIL.utils.morse_calc_pinv;

    % General MORSE settings, can be overwritten by case-specific config settings:
    N_order         = 4;                          % Sensitivity estimates per voxel
    N_ref           = 6; %[6 1]                   % Number of eigen outer products to use for svd to estimate sensitivity
    lambda          = 3e-4; %'auto';              % Regularisation factor for pseudo inversion. Use 'auto' if unsure; this will display a suggested lambda during image reconstruction, which can then be fixed here or modified during optimisation process.
    w = 6;                                        % Smoothing Kernel Size. Use 'auto' if unsure; this will display a suggested 'w' during image reconstruction, which can then be fixed here or modified during optimisation process.

    scaleNoiseCov   = 10^11;                      % Noise covariance scaling factor - for numerical stability
    ph_correction   = 'VRC';                      % 'VRC' - Virtual Reference Coil, i.e. subtraction of phase-matched sum of coil sensitivities
    vrc_mask_thr    = 0.8;                        % for VRC phase correction: threshold used to create a mask, centroid of this mask is a seed voxel for VRC phase correction, smaller values = bigger mask
    noise_cov_power = 2;                          % for VRC phase correction: exponent applied to noise covariance matrix to correlate coils and establish good VRC support over entire ROI, higher values more correlation    
    sens_grad_scale = 1;                          % Sensitivity gradient scaling -- relative contribution to 2nd SVD
    onlineROFT          = true;                   % Fourier Transform done prior ReconMPM.m
    scaleKsp            = 1e-2;                   % for numerical stability, used in morse_calc_pinv & morse_unfold, with noise adjust 1e-2, without 1e3:



    %% Case-specific MORSE configuration and reconstruction steps
    if strcmp(PPIparams.refType, 'embedded')    % MPM's v1 - Int. References
        disp('Recon of undersampled data with embedded references')

        % Case-specific config settings:
        % here none
        
        % Specified reconstruction steps
        next = gadgetron.FIL.steps.accumulate_volume(@connection.next, connection.header, sensitivity_function, onlineROFT);
        next = gadgetron.FIL.steps.morse_unfold(next, connection.header);
        next = gadgetron.FIL.steps.create_ismrmrd_3Dvol_and_send(next, connection, scaleFactor);
        tic, gadgetron.consume(next); toc

    elseif strcmp(PPIparams.refType, 'other') && ~contains(PPIparams.protocolName, 't1_FLASH_0.4iso_PM')    % Unaccelerated data, such as s-maps
        disp('Recon of fully sampled data, and sensitivity export')

        % Case-specific config settings:
        onlineROFT      = false;
        windowFactor    = 0.4;                     % for cosine filter 0.2, for Tukey filter 0.4
        w = 1;                                     % Smoothing Kernel Size. Use 'auto' if unsure; this will display a suggested 'w' during image reconstruction, which can then be fixed here or modified during optimisation process.

        % Specified reconstruction steps
        next = gadgetron.FIL.steps.accumulate_volume(@connection.next, connection.header);
        next = gadgetron.FIL.steps.tukey_filter(next, windowFactor, PPIparams);
        next = gadgetron.FIL.steps.morse_unfold_unaccelerated(next, PPIparams);
        next = gadgetron.FIL.steps.create_ismrmrd_3Dvol_and_send(next, connection, scaleFactor);
        next = gadgetron.FIL.steps.write_to_disk(next, gadNoiseDir, connection.header);
        tic, gadgetron.consume(next); toc

    elseif strcmp(PPIparams.refType, 'separate') % MPM's v2 - Separate Reference
        disp('Recon of undersampled data with sensitivity import')

        % Case-specific config settings:
        scaleKsp            = 1e3;                % for numerical stability, used in morse_calc_pinv & morse_unfold, with noise adjust 1e-2, without 1e3:

        % Specified reconstruction steps
        next = gadgetron.FIL.steps.accumulate_volume(@connection.next, connection.header, sensitivity_function, onlineROFT);
        next = gadgetron.FIL.steps.morse_unfold(next, connection.header);
        next = gadgetron.FIL.steps.create_ismrmrd_3Dvol_and_send(next, connection, scaleFactor);
        tic, gadgetron.consume(next); toc

    elseif strcmp(PPIparams.refType, 'other') && contains(PPIparams.protocolName, 't1_FLASH_0.4iso_PM')  
        disp('Recon of fully sampled postmortem data from Siemens T1-weighted FLASH sequence')
        
        % Case-specific config settings:
        N_order         = 1;                      
        scaleFactor         = 7581.43512*0.5; % unaccelerated data, hence 1/sqrt(2*2) with respect to our reference 2x2 accelerated data
        scaleKsp            = 1e3;

        % Specified reconstruction steps
        next = gadgetron.FIL.steps.accumulate_volume(@connection.next, connection.header, sensitivity_function, onlineROFT);
        next = gadgetron.FIL.steps.morse_unfold_unaccelerated(next, PPIparams);
        next = gadgetron.FIL.steps.create_ismrmrd_3Dvol_and_send(next, connection, scaleFactor);
        tic, gadgetron.consume(next); toc

    end

elseif strcmp(recon_type, 'ESPIRiT')
    sensitivity_function = @gadgetron.FIL.utils.ESPIRiT_calc_sens;

    N_order         = 2;                    % Sensitivity estimates per voxel
    scaleFactor         = 6;
    onlineROFT          = false;
    
    next = gadgetron.FIL.steps.accumulate_volume(@connection.next, connection.header, sensitivity_function, onlineROFT);
    next = gadgetron.FIL.steps.morse_unfold(next, connection.header);
    next = gadgetron.FIL.steps.create_ismrmrd_3Dvol_and_send(next, connection, scaleFactor);
    tic, gadgetron.consume(next); toc

else
    error('specify recon_type as MORSE or ESPIRiT in ReconMPM.m')
end

end
