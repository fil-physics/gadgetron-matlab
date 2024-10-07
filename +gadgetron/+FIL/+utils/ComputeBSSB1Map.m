%%*******************************************************%%
%%% B1 map calculation
%%% 
%%% Parameters of the Fermi pulse are based on mfc_bloch_siegert_v3e
%%%     - PhaseDat: phase encoding the B1 amplitude
%%%     - dwrf: off-resonance frequency in Hz
%%%     - DurPulse: Fermi pulse duration in sec 
%%%
%%% NC 03.01.20
%%%********************************************************



function [B1 KBS]=ComputeBSSB1Map (PhaseDat,Vref,Vpulse,DurPulse,dwrf)

gamma = 2.*pi.*42.57e6; % rad Hz / T

% Pulse parameters:

dwRF = 2.*pi.*(1*dwrf);

CorrFactor=DurPulse*1e6/8192; %% based on Sequence code
t0 = 3e-3*CorrFactor;          % pulse width, s, as per sequence
a = 0.16e-3*CorrFactor;        % timing parameter s.t. as a -> 0 Fermi -> Hard pulse

% time vector
dt=0.01e-3;
t = -(DurPulse/2):dt:(DurPulse/2);


% Fermi pulse centred at time t = 0:
B1Envelope = 1 ./ (1 + exp( (abs(t) - t0) ./ a));


% Conversion factor (Sacolick 2010)
KBS = sum(dt*((gamma .* B1Envelope).^2 ./ (2*(-dwRF))));

% compute B1 map in percentage of the nominal flip angle
B1nom = 11.7454e-6;      %  (pi=gamma*B1*1e-3s -> B1=pi/(gamma*1e-3)  -> B1=11.75e-6 T  B1 for 180 deg of 1ms )

B1pk = sqrt( (PhaseDat) ./ (KBS) ) ./Vpulse .*Vref ./ B1nom .* 100;
B1=10*real(B1pk); % scaled for dynamic range
