function next = accumulate_slice(input, header)

    matrix_size = header.encoding.encodedSpace.matrixSize;

    function slice = slice_from_acquisitions(acquisitions)
        disp("Assembling buffer from " + num2str(length(acquisitions)) + " acquisitions");

        acquisition = head(acquisitions);
        
        slice.reference = acquisition.header;        
        slice.data = complex(zeros( ...
            size(acquisition.data, 2), ...
            size(acquisition.data, 1), ...
            matrix_size.y,             ...
            matrix_size.z,             ...
            'single'                   ...
        ));
    
        for acq = acquisitions.asarray
            enc_step_1 = acq.header.kspace_encode_step_1 + 1;
            enc_step_2 = acq.header.kspace_encode_step_2 + 1;
            slice.data(:, :, enc_step_1, enc_step_2) = transpose(acq.data);
        end
    end

    function slice = accumulate()
        
        acquisitions = gadgetron.lib.list();
        
        while true
            acquisition = input();
            acquisitions = cons(acquisitions, acquisition);
            if acquisition.is_flag_set(acquisition.ACQ_LAST_IN_SLICE), break; end
        end
        
        slice = slice_from_acquisitions(acquisitions);
    end

    next = @accumulate;
end
