function pinv_sens = morse_calc_pinv(ref, PPIparams)
%**************************************************************************
%
%   morse_calc_pinv
%       input   ref: data for sensitivity estimation [RO, PE1, PE2, N_coils]
%               PPIparams: parameters of the acceleration
%
%       output  pinv_sens: image space pseudo inverse of sensitivities
%
%**************************************************************************

%% Reconstruction Parameters, Filenames and Switches
global scaleKsp w N_ref N_order

[RO, PE1, PE2, N_coils] = size(ref);
PAD                 = w*[0 0 0];           % Padding for smoothing

%% Apply constraint: N_order capped at number of references
if length(N_ref) == 1
    % No sensitivity gradients considered => N_order limited by N_ref
    N_order = min(N_ref, N_order);
else
    % Including sensitivity gradients allows for higher N_order so limit increases
    N_order = min(N_ref(1) + 3*N_ref(2), N_order);
end

%% Create two-dimensional apodisation window using Tukey filter
% Tukeywin starts and ends with zeros therefore add and remove
tw1=tukeywin(PPIparams.refPE+2, 0.5);    
tw2=tukeywin(PPIparams.ref3D+2, 0.5);
tw12=tw1(2:end-1).*tw2(2:end-1)';       % [refPE ref3D]

% Apply to reference data to minimise Gibbs ringing
refmask = any(ref,[1 4]);                 % [1 PE1 PE2]
refwin = zeros(size(refmask), 'single');  % [1 PE1 PE2]
refwin(refmask) = tw12;                   % sets non-zero entries
ref = ref.*refwin.*scaleKsp;              % apply the apodising function & scale

%% Calculate phase-corrected sensitivities
[sens, regu] = gadgetron.FIL.utils.morse_estimate_sensitivities(ref, PAD, PPIparams.measID);

%% Compute pseudo-inverse of the sensitivities (pre-allocate for memory efficiency)
pinv_sens = zeros(PPIparams.accPE*PPIparams.acc3D, N_coils, RO, PE1/PPIparams.accPE, PE2/PPIparams.acc3D, 'like', ref); % TO DO: delete?
pinv_sens = gadgetron.FIL.utils.morse_pseudoinvert_sensitivities(sens, regu, PPIparams.accPE, PPIparams.acc3D); % [N_alias N_coil RO PE1_acq PE2_acq]
