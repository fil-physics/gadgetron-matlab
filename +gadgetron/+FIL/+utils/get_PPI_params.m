function PPIparams = get_PPI_params(header)

PPIparams.measID = header.measurementInformation.measurementID;
PPIparams.accPE =  header.encoding.parallelImaging.accelerationFactor.kspace_encoding_step_1;
PPIparams.acc3D =  header.encoding.parallelImaging.accelerationFactor.kspace_encoding_step_2;

lUserParamValues = [header.userParameters.userParameterLong.value];
lUserParamNames = {header.userParameters.userParameterLong.name};

if (PPIparams.accPE > 1) || (PPIparams.acc3D > 1)
    PPIparams.refPE = lUserParamValues(strcmp(lUserParamNames, 'EmbeddedRefLinesE1'));
    PPIparams.ref3D = lUserParamValues(strcmp(lUserParamNames, 'EmbeddedRefLinesE2'));
    PPIparams.totalRefLines = PPIparams.refPE * PPIparams.ref3D;
end
if any(strcmp(lUserParamNames, 'caipiFactor'))
    PPIparams.caipiFactor = lUserParamValues(strcmp(lUserParamNames, 'caipiFactor'));
else
    PPIparams.caipiFactor = 0;
end

end