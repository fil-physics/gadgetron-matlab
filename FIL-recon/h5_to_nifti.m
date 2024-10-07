% this script allows to convert .h5 to .nii files
% dependencies: spm
% @FIL UCL
% written by Oliver Josephs
% modifications for extra contrasts: Barbara Dymerska

% select nr of contrasts to convert
% 1 - magnitude, 2 - magnitude + phase, 3 - magnitude, phase, B1+ map
nr_of_contrasts = 3 ;

% select your h5 directories:
dirs = spm_select(Inf,'dir') ;

%%%% END OF USER PARAMETERS %%%%
for f = 1 : size(dirs,1)
cd(strtrim(dirs(f,:)))
files = spm_select('FPList', '', '^.*.(h5)$');
fname=strtrim(files(1,:));


i=h5info(fname);
groupnum=1;
headerScan=h5read(i.Filename,[i.Groups.Groups(groupnum).Name '/header']);
headerScan=structfun(@(arr) arr(:, 1)', headerScan, 'UniformOutput', false);
headerScan.position=headerScan.position';
headerScan.read_dir=headerScan.read_dir';
headerScan.phase_dir=headerScan.phase_dir';

for run = 1:nr_of_contrasts
    volume=h5read(i.Filename,[i.Groups.Groups(run).Name '/data']);
    switch run
        case 1            
            niftiname = 'mag';            
        case 2            
            niftiname = 'ph';
        case 3                        
            niftiname = 'B1';
    end
    mkdir(niftiname)
    for e = 1 : size(volume,5)
        volume_1TE=squeeze(volume(:,:,:,:, e));
        if run ==2
            volume_1TE = 2*pi*single(volume_1TE - min(vector(volume_1TE)))/single(max(vector(volume_1TE))-min(vector(volume_1TE))) ;
        end
        % Adapted from spm_dicom_convert mosaic-to-nifti conversion
        % LR Flip to match image formed by spm_dicom_convert from ice recon
        volume_1TE=volume_1TE([end end:-1:2],[2:end 1],:);
        dim=size(volume_1TE);
        AnalyzeToDicom = [diag([1 -1 1]) [0 (dim(2)-1) 0]'; 0 0 0 1]*[eye(4,3) [-1 -1 -1 1]'];
        pos            = headerScan.position(:,1);
        orient         = [headerScan.read_dir(:,1), headerScan.phase_dir(:,1)];
        orient(:,3)    = null(orient');
        if det(orient)<0, orient(:,3) = -orient(:,3); end
        vox=headerScan.field_of_view./single(headerScan.matrix_size);
        DicomToPatient = [orient*diag(vox) pos ; 0 0 0 1];
        truepos        = DicomToPatient *[-dim/2 1]';
        DicomToPatient = [orient*diag(vox) truepos(1:3) ; 0 0 0 1];
        PatientToTal   = diag([-1 -1 1 1]);
        mat            = PatientToTal*DicomToPatient*AnalyzeToDicom;
        fa=file_array;
        fa.dim  = size(volume_1TE);
        fa.dtype='FLOAT32';
        [folder, ~, ~] = fileparts(fname);
               
        
        % Make sure the folder is prepended (if it has one).
        nifti_fullname = fullfile(folder, niftiname, sprintf('%s_TE%04.0f.nii', niftiname, e));
        
        fa.fname=char(nifti_fullname);
        % Nifti header
        N=nifti;
        N.dat=fa;
        N.mat = mat;
        N.mat0 = mat;
        N.descrip='Converted from h5';
        create(N); % Writes nifti header
        
        
        N.dat(:,:,:)=volume_1TE; % Writes Nifti data
    end
end

end