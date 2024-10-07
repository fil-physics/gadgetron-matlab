% input: structure with a field data arranged as [1 nx ny nz nechoes nsets]
% (output of ESPIRiT_unfold)

function next = BSS_classic_or_GLM_B1map(input,header)

addpath(genpath('/usr/local/romeo_linux_3.2.5/matlab/NIfTI_20140122'))

%%% BSS parameters ( requires the conversion siemens to ismrmrd
%%% with IsmrmrdParameterMap_Siemens_BSS.xml and
%%% IsmrmrdParameterMap_Siemens_BSS.xsl

% double parameters
dname={header.userParameters.userParameterDouble.name};
dvalue=[header.userParameters.userParameterDouble.value];
RefVoltage=dvalue(find(strcmp(dname,'RefVoltage')));
BSPulseVoltage=dvalue(find(strcmp(dname,'BSPulseVoltage')));
OffsetFrequencyHz=dvalue(find(strcmp(dname,'BSPulse_OffsetFrequencyHz')));

% long parameters
lname={header.userParameters.userParameterLong.name};
lvalue=[header.userParameters.userParameterLong.value];
BSPulseDuration=lvalue(find(strcmp(lname,'BSPulseDuration')))*1e-6; %% in sec
NbEchoesBeforeBSPulse=lvalue(find(strcmp(lname,'NbEchoesBeforeBSPulse')));


% Echo times and number of echoes
TE=header.sequenceParameters.TE*1e-3; %[s]
NbEchoes=header.encoding.encodingLimits.contrast.maximum+1;


    function data = BSS_classic_or_GLM_B1map(data)

        % phase difference
        OffsetPos=squeeze(data.data(1,:,:,:,NbEchoesBeforeBSPulse+1,1));
        OffsetNeg=squeeze(data.data(1,:,:,:,NbEchoesBeforeBSPulse+1,2));
        PhaseDiff=angle(OffsetPos.*conj(OffsetNeg));
        % BSS magnitude image after MORSE recon has a strong bias field
        % if pseudo-inverse of coil sensitivities is stored in the data structure 
        % in MORSE coil sensitivity estimate step 
        % it is used to scale magnitude images to remove this strong bias field 
        if isfield(data.reference,'pinv_sens_sos')
            data.data(1,:,:,:,NbEchoesBeforeBSPulse+1,1) = data.data(1,:,:,:,NbEchoesBeforeBSPulse+1,1)./permute(data.reference.pinv_sens_sos,[4 1 2 3]);
            data.data(1,:,:,:,NbEchoesBeforeBSPulse+1,2) = data.data(1,:,:,:,NbEchoesBeforeBSPulse+1,2)./permute(data.reference.pinv_sens_sos,[4 1 2 3]);
        end
        % unwrap phase difference using ROMEO phase uwnrapping
        parameters.output_dir = fullfile(tempdir, 'romeo_tmp'); % temporary ROMEO output folder
        mkdir(parameters.output_dir) ;
        parameters.mask = 'nomask';
        [uwpPhaseDiff] = gadgetron.FIL.utils.ROMEO(PhaseDiff, parameters);
        rmdir(parameters.output_dir, 's') % remove the temporary ROMEO output folder

        % compute B1 map
        [B1classic KBS]=gadgetron.FIL.utils.ComputeBSSB1Map(uwpPhaseDiff/2,RefVoltage,BSPulseVoltage,BSPulseDuration,OffsetFrequencyHz);
        data.userOutput.B1map_BSSClassic=B1classic;

        if NbEchoes>5 % GLM can be used to reconstruct a B1 map

            % create a mask from the first echo of the first set
            Echo1Set1=squeeze(abs(data.data(1,:,:,:,1,1)));
            mask=zeros(size(Echo1Set1));
            mask(Echo1Set1>(0.1*mean(Echo1Set1(:))))=1;

            % remove coil dimension
            Data=squeeze(data.data); % [nx,ny,nz,nEchoes,nSets]


            [beta,err]=gadgetron.FIL.utils.EstimateParameters_GLM_BSS(Data,TE,NbEchoes,NbEchoesBeforeBSPulse,mask);

            % reshape beta parameters
            img_size=[size(Data,1) size(Data,2) size(Data,3)];

            EvenOdd=reshape(beta(1,:),img_size);
            PhaseBSS=reshape(beta(2,:),img_size);
            wB0=reshape(beta(3,:),img_size);
            Phi0_1=reshape(beta(4,:),img_size);
            Phi0_2=reshape(beta(5,:),img_size);


            % compute B1 map
            [B1glm KBS]=gadgetron.FIL.utils.ComputeBSSB1Map(PhaseBSS,RefVoltage,BSPulseVoltage,BSPulseDuration,OffsetFrequencyHz);

            % save resulting B0 and B1 maps in data.userOutput
            data.userOutput.B0map_BSSglm=wB0;
            data.userOutput.B1map_BSSglm=B1glm;
        end

    end

next = @() BSS_classic_or_GLM_B1map(input());
end
