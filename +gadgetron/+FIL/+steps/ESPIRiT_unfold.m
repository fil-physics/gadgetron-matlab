
function next = ESPIRiT_unfold(input, header)

 disp("ESPIRiT unfolding setup...")
global N_order 
matrix_size = header.encoding.reconSpace.matrixSize; % [x,y,z]
nEchoes     = header.encoding.encodingLimits.contrast.maximum+1;
nSets       = header.encoding.encodingLimits.set.maximum+1;

    function data = ESPIRiT_unfold(data)
        
        disp("ESPIRiT unfolding execution...")
        
        outputData = zeros([1, matrix_size.x, matrix_size.y, matrix_size.z, nEchoes, nSets, N_order], 'like', single(1i));
        % data.data in k-space arranged as [N_coils, RO, PE1, PE2, echoes, sets]
        % data.sensitivities in image domain arranged as [RO, PE1, PE2, N_coils]
        for echoNum = 1 : nEchoes
            for setNum = 1 : nSets                
                outputData(1,:,:,:,echoNum,setNum,:) =  gadgetron.FIL.utils.ESPIRiT(...
                    'pics', permute(data.data(:,:,:,:,echoNum,setNum), [2 3 4 1]), data.sensitivities);
            end
        end
        
        data.data = outputData(1,:,:,:,:,:,1);
        
    end
next = @() ESPIRiT_unfold(input());
end