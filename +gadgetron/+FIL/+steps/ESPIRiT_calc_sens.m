function next = ESPIRiT_calc_sens(input,dimRef)

disp("ESPIRiT Calculate sensitivities setup...")
 
    function data = ESPIRiT_calc_sens(data)
        
        disp("Calculate sensitivities with ESPIRiT.")

        % data.sensitivities initialized as the full k-space of the first 
        % echo and the first set rearranged as [RO, PE1, PE2, N_coils]    
        data.sensitivities = permute(data.data(:,:,:,:,1,1),...
            [2 3 4 1]);
        
        data.sensitivities = gadgetron.FIL.utils.ESPIRiT_calc_sens( ...
            data.sensitivities, dimRef);
    end


next = @() ESPIRiT_calc_sens(input());
end