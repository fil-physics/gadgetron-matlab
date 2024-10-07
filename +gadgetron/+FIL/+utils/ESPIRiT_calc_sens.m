function sens = ESPIRiT_calc_sens(dat, dimRef)
% FORMAT sens = ESPIRiT_calc_sens(dat, dimref)
% dat       - k-space [ro p1 p2 cl]
% dimRef - either a vector with reference vol dimentions (epi) or a structure of PPIparams (MPM) - parameters describing the acceleration
global N_order

if isstruct(dimRef)
    % PPIparams structure has been passed
    dimRef = [max(dimRef.refPE, dimRef.ref3D), dimRef.refPE, dimRef.ref3D];
end

func = sprintf('ecalib -r %d %d %d -m %i -d 3 -c 0.01', dimRef, N_order);
sens = gadgetron.FIL.utils.ESPIRiT(func, dat);