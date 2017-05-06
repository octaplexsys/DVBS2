close all;
clear all;
clc;

%% Parameters
modOrd = 16; % Modulation order
bitPerSymbol = log2(modOrd); % Nombre de bits par symbole 
frameSize = 64800; % Dvbs2 frame size (bits)
nbSymb = 2000; %Nombre de symboles � g�n�rer
roff = 0.35; % Rolloff shape filter
nbsamples = 8; % Samples per symbols
LDPCRate = 3/4;
nbFrame = 10; % number of frame to send
EbNo = 2; % Eb/No
RowInterleave = 16200;
ColumnInterleave = 4;

%% BCH encoder
[k, n] = BCHCoeffs(LDPCRate);
BCHEncoder = comm.BCHEncoder(k, n);

%% LDPC encoder
parityCheckMatrix = dvbs2ldpc(LDPCRate);
LDPCEncoder = comm.LDPCEncoder('ParityCheckMatrix', parityCheckMatrix);


%% Modulation
gamma = gamma_dvbs2(LDPCRate);

%% shape filter emetter
txfilter = comm.RaisedCosineTransmitFilter('RolloffFactor', roff);
delay = txfilter.FilterSpanInSymbols; % Delay of the filter

%% Canal
channel = comm.AWGNChannel('EbNo', EbNo,'BitsPerSymbol', bitPerSymbol);

%% shape filter receiver
rxfilter = comm.RaisedCosineReceiveFilter('RolloffFactor', roff);

%% Demodulator
demodulator = comm.PSKDemodulator(modOrd, 'BitOutput',true, 'DecisionMethod','Approximate log-likelihood ratio', 'Variance', 1/10^(channel.SNR/10));

%% LDPC decoder
LDPCDecoder = comm.LDPCDecoder('ParityCheckMatrix', parityCheckMatrix);

%% Error rate
errorRate = comm.ErrorRate;

%% Simulation
for frame = 1:nbFrame
    data                = randi([0 1], LDPCRate*frameSize,1);
    encodedData         = step(LDPCEncoder, data);
    interleavedData     = matintrlv(encodedData, ColumnInterleave, RowInterleave);
    modData             = mod_16apsk(interleavedData, gamma);
    %modDataZP          = [modData; zeros(delay, 1)];
    %filterData         = step(txfilter, modDataZP);
    channelOutput       = step(channel, modData);
    %filterDataReceiver = step(rxfilter, channelOutput);
    demodulatedData     = demod_16apskllr(channelOutput, gamma);
    deinterleavedData   = matintrlv(demodulatedData, RowInterleave, ColumnInterleave);
    receivedBits        = step(LDPCDecoder, deinterleavedData);
    errorStats          = step(errorRate, logical(data), receivedBits);
end

%% View
%scatterplot(modData)
%scatterplot(filterDataReceiver(delay+1:end))
fprintf('Error rate       = %1.2f\nNumber of errors = %d\n', errorStats(1), errorStats(2))