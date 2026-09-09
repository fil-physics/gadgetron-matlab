%**************************************************************************
%
%   create_ismrmrd_3Dvol_and_send extracts a block of 3D data in ISMRMRD
%   format and sends it back to the host.
%       input:      Structure with fields of data and reference
%       connection: Link with Gadgetron. Required to get global header info
%       scaleFactor:Scale factor for magnitude data to use dynamic range.
%
%**************************************************************************

function next = create_ismrmrd_3Dvol_and_send(input, connection, scaleFactor)

global gadNoiseDir
header  = connection.header;
matrix_size = header.encoding.reconSpace.matrixSize; % [x,y,z]
nEchoes = header.encoding.encodingLimits.contrast.maximum+1;
nSets   = header.encoding.encodingLimits.set.maximum+1;
PPIparams = gadgetron.FIL.utils.get_PPI_params(connection.header);

res = [header.encoding.encodedSpace.fieldOfView_mm.x/header.encoding.encodedSpace.matrixSize.x ...
       header.encoding.encodedSpace.fieldOfView_mm.y/header.encoding.encodedSpace.matrixSize.y ...
       header.encoding.encodedSpace.fieldOfView_mm.z/header.encoding.encodedSpace.matrixSize.z];

disp("create_ismrmrd_3Dvol_and_send setup...")

    function image = create_ismrmrd_3Dvol_and_send(image)

        % What code version was used for the reconstruction? This will be added as a comment.
        [~,git_hash_string] = system('git rev-parse --short HEAD');

        %% send data.data
        for setNum = 1 : nSets
            
            for echoNum = 1 : nEchoes
                disp(['Extracting 3D volume for echo ' num2str(echoNum) ' and set ' num2str(setNum)]);
                image_series_index = 1;

                % Warning! The shifts below are an empirically determined correction
                % to get alignment with ICE reconstruction:
                dataToConvert = circshift(image.data(:,:,:,:,echoNum,setNum), [0,-1,-1,-1]);
                
                ismrmrd_3Dvol = gadgetron.types.Image.from_data(abs(dataToConvert), image.reference);
                
                ismrmrd_3Dvol.header.image_type = gadgetron.types.Image.MAGNITUDE;
                ismrmrd_3Dvol.header.contrast   = echoNum-1;
                ismrmrd_3Dvol.header.set        = setNum-1;                
                ismrmrd_3Dvol.header.image_index = (setNum-1)*nEchoes*matrix_size.z + (echoNum-1)*matrix_size.z + 1;
                ismrmrd_3Dvol.header.image_series_index = image_series_index;
                
                
                vec=[-res(1); -res(2); -res(3)/2];
                Mrot=[(image.reference.read_dir)', (image.reference.phase_dir)', (image.reference.slice_dir)'];
                
                ismrmrd_3Dvol.header.position = image.reference.position + (Mrot*vec)';
                ismrmrd_3Dvol.header.field_of_view = [res(1)*matrix_size.x, res(2)*matrix_size.y, res(3)*matrix_size.z];
                
                disp("Sending scaled image to client.");
                ismrmrd_3Dvol.data = ismrmrd_3Dvol.data.*scaleFactor/(res(1)*res(2)*res(3))/round(header.acquisitionSystemInformation.systemFieldStrength_T);
                ismrmrd_3Dvol.meta('GADGETRON_ImageComment') = ['Magnitude', git_hash_string];
                connection.send(ismrmrd_3Dvol);
                
                if ~isreal(dataToConvert)
                    image_series_index = 2;
                    % Complex data => send phase by default; protocol configuration (i.e. MAGNITUDE / MAGN_PHASE) not checked.
                    
                    ismrmrd_3Dvol = gadgetron.types.Image.from_data(angle(dataToConvert), image.reference);
                    ismrmrd_3Dvol.header.contrast   = echoNum-1;
                    ismrmrd_3Dvol.header.set        = setNum-1;
                    ismrmrd_3Dvol.header.image_index = (setNum-1)*nEchoes*matrix_size.z + (echoNum-1)*matrix_size.z + 1;
                    ismrmrd_3Dvol.header.image_type = gadgetron.types.Image.PHASE; % the conversion from [-pi:pi] to [0 4096] is automatically done when specifying PHASE type
                    ismrmrd_3Dvol.header.image_series_index = image_series_index;
                    
                    vec=[-res(1); -res(2); -res(3)/2];
                    Mrot=[(image.reference.read_dir)', (image.reference.phase_dir)', (image.reference.slice_dir)'];
                    
                    ismrmrd_3Dvol.header.position = image.reference.position + (Mrot*vec)';
                    ismrmrd_3Dvol.header.field_of_view = [res(1)*matrix_size.x, res(2)*matrix_size.y, res(3)*matrix_size.z];
                    
                    disp("Sending phase image to client.");
                    ismrmrd_3Dvol.meta('GADGETRON_ImageComment') = ['Phase ', git_hash_string];
                    connection.send(ismrmrd_3Dvol);
                    
                end % Complex?
            end % Echoes
        end % Sets
        
        %% send optional data.userOutput
        % Send user output, e.g. B1+ map, by looping over the fields
        if isfield(image, 'userOutput')
            fields=fieldnames(image.userOutput);
            
            for f=1:length(fields)
                
                image_series_index = image_series_index + 1;

                % Singleton dimension added (already exists for magnitude and phase data)
                output = zeros([1 size(image.userOutput.(fields{f}))]);
                output(1,:,:,:,:,:) = (image.userOutput.(fields{f}));

                % Warning! The shifts below are an empirically determined correction
                % to get alignment with ICE reconstruction:
                output = single(circshift(output,[0,-1,-1,-1]));
               
                ismrmrd_3Dvol = gadgetron.types.Image.from_data(output, image.reference);
                ismrmrd_3Dvol.header.image_type = gadgetron.types.Image.MAGNITUDE; % set to magnitude if no negative value, e.g. B1 maps 
                ismrmrd_3Dvol.header.image_index = 1;
                ismrmrd_3Dvol.header.image_series_index = image_series_index;
                
                vec=[-res(1); -res(2); -res(3)/2];
                Mrot=[(image.reference.read_dir)', (image.reference.phase_dir)', (image.reference.slice_dir)'];
                
                ismrmrd_3Dvol.header.position = (image.reference.position')+Mrot*vec; 
                ismrmrd_3Dvol.header.field_of_view = [res(1)*matrix_size.x; res(2)*matrix_size.y; res(3)*matrix_size.z];
          
                disp(['Sending ' fields{f} ' to client.']);
                ismrmrd_3Dvol.meta('GADGETRON_ImageComment') = [fields{f}, git_hash_string];
                connection.send(ismrmrd_3Dvol);
            end
        end

        % Remove s-map data from storage
        if PPIparams.delete_smap == 1
            % Find sensitivity information from previous smaps:
            pn = [gadNoiseDir filesep 'database-FIL'];
            MeasID = header.measurementInformation.measurementID;
            MID_parts = split(MeasID, '_');
            targetMID = str2double(MID_parts{4});
            MID_parts = [MID_parts{1} '_' MID_parts{2} '_' MID_parts{3} '_' ];
            % Search for number that is closest (but previous to) to current MID
            for attempt = 1:10
                targetMID = targetMID - 1;
                smap_dataFn = fullfile(pn, [MID_parts num2str(targetMID) '_sensitivity.mat']);
                try
                    if isfile(smap_dataFn)
                        delete(smap_dataFn);
                        disp(['Succesfully deleted s-map data ' smap_dataFn])
                        if attempt > 2
                            disp(['Warning! Deleted s-map data may have originated from previous scan ' smap_dataFn])
                        end
                        break
                    end
                catch
                    if attempt == 10
                        warning('Sensitivity information for deletion not found. If s-map was not acquired, please ignore this warning');
                    end
                end
            end
 
        end
    end

next = @() create_ismrmrd_3Dvol_and_send(input());
end
