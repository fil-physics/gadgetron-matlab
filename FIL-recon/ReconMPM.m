
function ReconMPM(connection)
    disp("Matlab MPM Recon launched...")
    
    recon_type = 'MORSE' ; % 'MORSE' or 'ESPIRiT', 'ESPIRiT' recquires installation of the Berkeley Advanced Reconstruction Toolbox (BART) toolbox
    
    % Hard-coded reconstruction parameters:
    global onlineROFT scaleKsp gadNoiseDir scaleNoiseCov vrc_mask_thr noise_cov_power ph_correction w N_ref N_order sens_grad_scale lambda  

    % for numerical stability, used in morse_calc_pinv & morse_unfold, with noise adjust 1e-2, without 1e3:
    scaleKsp = 1e-2;
    gadNoiseDir = '~/.gadgetron/storage';       % gadgetron noise_cov storage directory, default is '~/.gadgetron/storage', can be changed with gadgetron -S option
    scaleNoiseCov       = 10^11;                % Noise covariance scaling factor - for numerical stability
    ph_correction = 'VRC';                      % 'VRC' - Virtual Reference Coil, i.e. subtraction of phase-matched sum of coil sensitivities
    vrc_mask_thr    = 0.8;                      % for VRC phase correction: threshold used to create a mask, centroid of this mask is a seed voxel for VRC phase correction, smaller values = bigger mask
    noise_cov_power = 2;                        % for VRC phase correction: exponent applied to noise covariance matrix to correlate coils and establish good VRC support over entire ROI, higher values more correlation

    w                  = 6;                    % Smoothing kernel for eigencoil calculation in image domain [voxels]
    N_ref            = 6; %[6 1]             % Number of eigen outer products to use for svd to estimate sensitivity
    
    sens_grad_scale     = 1;                    % Sensitivity gradient scaling -- relative contribution to 2nd SVD
    lambda              = 3e-4;                 % Regularisation factor for pseudo inversion

    % Reconstruction settings
    
    if strcmp(recon_type, 'MORSE')    
        N_order         = 4;                    % Sensitivity estimates per voxel
        scaleFactor         = 5e3; 
        onlineROFT          = true;
        sensitivity_function = @gadgetron.FIL.utils.morse_calc_pinv;
    elseif strcmp(recon_type, 'ESPIRiT')
        N_order         = 2;                    % Sensitivity estimates per voxel
        scaleFactor         = 6;
        onlineROFT          = false;
        sensitivity_function = @gadgetron.FIL.utils.ESPIRiT_calc_sens;
    else
        error('specify recon_type as MORSE or ESPIRiT in ReconMPM.m')
    end
    
    % Set up parallel thread pool for use by parfor in functions
    if isempty(gcp('nocreate')); parpool('threads'); end
  
    % Specified reconstruction steps
    next = gadgetron.FIL.steps.accumulate_volume(@connection.next, connection.header, sensitivity_function, onlineROFT);
    if strcmp(recon_type, 'MORSE')
        next = gadgetron.FIL.steps.morse_unfold(next, connection.header);
    elseif strcmp(recon_type, 'ESPIRiT')
        next = gadgetron.FIL.steps.ESPIRiT_unfold(next, connection.header);
    end
    next = gadgetron.FIL.steps.create_ismrmrd_3Dvol_and_send(next, connection, scaleFactor);
    tic, gadgetron.consume(next); toc
end
