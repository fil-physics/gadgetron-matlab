function PPIparams = get_PPI_params(header)

PPIparams.measID = header.measurementInformation.measurementID;
PPIparams.accPE =  header.encoding.parallelImaging.accelerationFactor.kspace_encoding_step_1;
PPIparams.acc3D =  header.encoding.parallelImaging.accelerationFactor.kspace_encoding_step_2;

lUserParamValues = [header.userParameters.userParameterLong.value];
lUserParamNames = {header.userParameters.userParameterLong.name};

if (PPIparams.accPE > 1) || (PPIparams.acc3D > 1)
    PPIparams.refPE = lUserParamValues(strcmp(lUserParamNames, 'EmbeddedRefLinesE1'));
    PPIparams.ref3D = lUserParamValues(strcmp(lUserParamNames, 'EmbeddedRefLinesE2'));
    % Siemens omits EmbeddedRefLinesE2 when there is no acceleration in 3D:
    % then the reference lines span all partitions.
    if isempty(PPIparams.ref3D)
        PPIparams.ref3D = double(header.encoding.encodingLimits.kspace_encoding_step_2.maximum) ...
                        - double(header.encoding.encodingLimits.kspace_encoding_step_2.minimum) + 1;
    end
    PPIparams.totalRefLines = PPIparams.refPE * PPIparams.ref3D;
end
if any(strcmp(lUserParamNames, 'caipiFactor'))
    PPIparams.caipiFactor = lUserParamValues(strcmp(lUserParamNames, 'caipiFactor'));
else
    PPIparams.caipiFactor = 0;
end

% separate/embedded/other flag for unfolding reference
PPIparams.refType = header.encoding.parallelImaging.calibrationMode;
% Some VIBE protocols report calibrationMode=separate although the reference
% lines are in the same measurement (Siemens ucRefScanMode=4). Treat them as embedded.
if strcmp(PPIparams.refType, 'separate') && any(strcmp(lUserParamNames, 'EmbeddedRefLinesE1'))
    disp('get_PPI_params: overriding calibrationMode separate -> embedded (EmbeddedRefLines present)');
    PPIparams.refType = 'embedded';
end
PPIparams.kmin_PE1 = header.encoding.encodingLimits.kspace_encoding_step_1.minimum + 1 ; % from 0-indexed c++ to matlab
PPIparams.kmax_PE1 = header.encoding.encodingLimits.kspace_encoding_step_1.maximum + 1 ; % from 0-indexed c++ to matlab

PPIparams.kmin_PE2 = header.encoding.encodingLimits.kspace_encoding_step_2.minimum + 1 ; % from 0-indexed c++ to matlab
PPIparams.kmax_PE2 = header.encoding.encodingLimits.kspace_encoding_step_2.maximum + 1 ; % from 0-indexed c++ to matlab

% Calculating smoothing kernel and removal of slab oversampling
PPIparams.FoV = header.encoding.encodedSpace.fieldOfView_mm;
PPIparams.matSize = header.encoding.encodedSpace.matrixSize;
PPIparams.reconMatSize = header.encoding.reconSpace.matrixSize;

% To check if we deal with postmortem protocol
PPIparams.protocolName = header.measurementInformation.protocolName ; 

% Check for delete s-map boolean
if any(strcmp(lUserParamNames, 'delete_smap'))
    PPIparams.delete_smap = lUserParamValues(strcmp(lUserParamNames, 'delete_smap'));
else
    PPIparams.delete_smap = 0;
end

end
