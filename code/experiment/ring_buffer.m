%% online analysis
% 06.03.2026

close all; clear; clc; beep off;

knob.save = 1; %1 save the chunksize
knob.debugging = 0; % heavy plotting

% PATHS
paths.main = '\\smb.uni-oldenburg.de\psychologie$\Neuro\data\projects\alo_alpha_neurofeedback';

% to save the chunksize at the end of the experiment
paths.chunksize = fullfile(paths.main, '\data\recordings\chunks'); % the last part is just the name of the file, not directory

% LIBS
paths.lib = [paths.main, '\libs'];
addpath(genpath([paths.lib, '\liblsl-Matlab'])); % for lsl
lib = lsl_loadlib();

% EEGLAB
disp('initaliting eeglab')
paths.eeglab = [paths.main, '\libs\eeglab_current\eeglab2025.0.0'];
addpath(paths.eeglab);
eeglab;
clc


% ring buffer
channels.list = {'Fp1', 'Fp2', 'F3', 'F4', 'C3', 'C4', 'P3', 'P4', 'O1', 'O2', 'F7','F8', 'T7', 'T8', 'P7', 'P8', 'Fz', 'Cz', 'Pz', 'VEOG', 'Fc1', 'Fc2', 'Cp1', 'Cp2' 'Fc5', 'Fc6', 'Cp5', 'Cp6', 'Ft9', 'Ft10', 'TP9', 'Tp10'};
channels.ROI = {'O2'};
[~, channels.idx]= ismember(channels.ROI, channels.list); % ROI index
disp(['Channel to annalyze: ', char(channels.ROI)]) % only works for 1
disp(['index: ' num2str(channels.idx)])

% stream thing
stream = struct();
stream.name = {'EEG'};
stream.srate = 250; % amplifier


% ring variables
ring.chunksize = 100; % desired amount of samples per chunk
ring.stability = ring.chunksize / stream.srate; % for pauses
ring.window = 4; % seconds for sliding window; fredercik = 150
ring.buffnum = floor(ring.window* stream.srate / ring.chunksize); % number of chunks per buffer for the window
ring.buffsize = ring.window* stream.srate; % number of chunks per buffer for the window
ring.nhb = round(4 / ring.stability); % neighbours for the weighted average
ring.weights = linspace(1,2, ring.nhb); % create a linear weight vector
ring.weights = ring.weights/sum(ring.weights); % normalize the weights

disp(['Sampling rate of: ' , num2str(stream.srate)])
disp(['Buffersize of: ', num2str(ring.buffsize), ' samples'])

% filter design
filtro.hco = 12; % 12
filtro.lco = 8; % 8
filtro.order = 104;
filtro.causal = 1;
message = (['eeglab filter, filter order: ', num2str(filtro.order)]);


disp(' ')

% dummy structure to avoid issues with EEGLAB
EEG.srate = stream.srate;
EEG.nbchan = numel(channels.idx); % i will select the channel
EEG.pnts = ring.buffsize;
EEG.trials = 1; % Single trial / segment
EEG.xmin   = 0; % Start time in seconds
EEG.xmax   = (EEG.pnts) / EEG.srate; % 4 seconds
EEG.times  = linspace(EEG.xmin * 1000, EEG.xmax * 1000, EEG.pnts);
EEG.chanlocs = struct('labels', 'Alpha');  % Minimal chanlocs

disp(message)


disp(' ')

tdex = 1; % THE counter
switch knob.save
    case 1
        disp(['chunksize will be saved in: ', paths.main])
    case 0
        disp('chunksize won´t be saved')
end

disp(' ')


%% PROLOGUE: CONNECTIONS

% EEG INLET
stream.resolve = {};
while isempty(stream.resolve)
    stream.resolve = lsl_resolve_byprop(lib, 'name', stream.name{1}); % might create an infinite loop
    disp('resolving EEG inlet...')
end
stream.inlet = lsl_inlet(stream.resolve{1}); % even if it works, it's empty

% AAA OUTLET
outlet.name = 'AAAStream';
outlet.type = ['Alpha Amplitude Values. ', message];
outlet.channelCount = 1; % keep updating
outlet.NominalSrate = 1 / ring.stability; % sampling rate corresponds to pause at the end
outlet.ChannelFormat = 'cf_double64'; % 'cf_float32', 'cf_double64', 'cf_string', 'cf_int32', 'cf_int16', 'cf_int8'
outlet.SourceId = 'sdfwerr33232';

outlet.info = lsl_streaminfo(lib, outlet.name, outlet.type, outlet.channelCount, outlet.NominalSrate, outlet.ChannelFormat, outlet.SourceId);
outlet.aaa = lsl_outlet(outlet.info);



%%



























%% PART TWO: FILLING BUFFER ONCE

EEG.data = [];
stream.chunk = [];
stream.smpl = []; % the real chunksize, usually the first one is strange
stream.issues = [];
stream.all = [];
%stream.alpha = [];


disp(['filling buffer, ETA: ', num2str(ring.window), ' secs']);
while size(EEG.data,2) <= ring.buffsize
    pause(ring.stability);

    [stream.chunk, ts] = stream.inlet.pull_chunk();

    if isempty(stream.chunk) % failsafe
        pause(ring.stability);
        disp('>> connection issues <<')
        [stream.chunk, ts] = stream.inlet.pull_chunk();
    end

    stream.smpl(end+1) = size(stream.chunk, 2); % x = 1:buffsize

    % channel select
    stream.chunk = stream.chunk(channels.idx, :);
    EEG.data = [EEG.data, stream.chunk];

end

% trimming
ring.remove = size(EEG.data,2) - ring.buffsize+1;
% if there are more samples than the conservative buffersize
switch ring.remove > 0
    case 1
        EEG.data = EEG.data(:, ring.remove:end);
end

disp('ready to start')


%% Run ring buffer:

pause(ring.stability);
while true %
    [stream.chunk, ts] = stream.inlet.pull_chunk(); % chunk keeps rewritting itself

    %% failsafe in case of temporal disconnections
    if isempty(stream.chunk)  % failsafe: rety mechanism
        %pause(ring.stability);
        disp('>> connection issues <<')
        [stream.chunk, ts] = stream.inlet.pull_chunk();

        if isempty(stream.chunk) % still empty: carry on mechanism
            disp('>> connection issues (emergency protocol) <<')
            pause(ring.stability);
            [stream.chunk, ts] = stream.inlet.pull_chunk(); % retry with pause

            if isempty(stream.chunk) % still empty: close
                break;
            end
        end
    end % end of the failsafe



    %% ring buffer

    stream.chunk = stream.chunk(channels.idx, :); % select_channel
    stream.smpl(end+1) = size(stream.chunk, 2); % we save the chunksize
    EEG.data = [EEG.data(:, stream.smpl(end)+1:end), stream.chunk]; % conservative


    % filtering
    alpha.filtered = pop_eegfiltnew(EEG, 'locutoff',filtro.lco,'hicutoff',filtro.hco,'filtorder',filtro.order,'minphase',filtro.causal,'plotfreqz',0);


    % envelope and average: alpha
    alpha.envelope = abs(hilbert(alpha.filtered.data));
    alpha.state = mean(alpha.envelope);



    switch knob.debugging
        case 1
            %%
            timevector = (0:999)/stream.srate;

            figure;
            subplot(3,1,1)
            plot(timevector, EEG.data, 'Color' ,  [0.5   0.5    0.5])
            title('Raw EEG (O2 channel)')
            xlabel('Time (s)')
            ylabel('Amplitude (μV)')

            subplot(3,1,2)
            plot(timevector, alpha.filtered.data)
            title('Filtered alpha-band signal (8–12 Hz)')
            xlabel('Time (s)')
            ylabel('Amplitude (μV)')


            subplot(3,1,3)
            plot(timevector, alpha.filtered.data)
            hold on
            plot(timevector, alpha.envelope)
            title('Filtered signal with envelope')
            xlabel('Time (s)')
            ylabel('Amplitude (μV)')
            %paths.save = ['\\daten.w2kroot.uni-oldenburg.de\home\jofo2989\Documents\mt\figure\ring_buffer']
            %           print(gcf, [paths.save, '\online_analysis'], '-dpng', '-r300');

            %%
    end



    %% Weighted average
    % fake ring buffer

    switch true
        case tdex <= ring.nhb % fill wonder wheel once
            ring.wheel(tdex) = alpha.state;

        case tdex > ring.nhb % run wonder wheel when tdex = ring.nhb+1
            ring.wheel = [ring.wheel(2:ring.nhb), alpha.state]; % ring buffer structure
            ring.wheel_final = sum(ring.wheel .* ring.weights); % apply wieghted average
            alpha.state = ring.wheel_final;
    end

    %% push out

    outlet.aaa.push_sample(alpha.state);

    %%
    tdex = tdex + 1;
    pause(ring.stability);

end
clear outlet

switch knob.save
    case 1
        save(paths.chunksize, 'stream');  % Use '-v7.3' if the variable is large, otherwise you can omit it)
        disp('chunksize saved in: ')
        disp(paths.chunksize)
end

disp('game over')

timevector = (0:999)/stream.srate;

figure;
subplot(3,1,1)
plot(timevector, EEG.data, 'Color' ,  [0.5   0.5    0.5])
title('Raw EEG (O2 channel)')
xlabel('Time (s)')
ylabel('Amplitude (μV)')

subplot(3,1,2)
plot(timevector, alpha.filtered.data)
title('Filtered alpha-band signal (8–12 Hz)')
xlabel('Time (s)')
ylabel('Amplitude (μV)')


subplot(3,1,3)
plot(timevector, alpha.filtered.data)
hold on
plot(timevector, alpha.envelope)
title('Filtered signal with envelope')
xlabel('Time (s)')
ylabel('Amplitude (μV)')
