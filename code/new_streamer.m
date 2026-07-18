%% new streamer
% 06.03.2026

close all; clear; clc; beep off;

paths.main = '\\smb.uni-oldenburg.de\psychologie$\Neuro\data\projects\alo_alpha_neurofeedback';
paths.in = [paths.main, '\sub-01\eeg']; % participant 1
paths.lib = [paths.main, '\libs'];

% LIBS
addpath(genpath([paths.lib, '\liblsl-Matlab'])); % for send_osc and load_xdf
lib = lsl_loadlib();
addpath([paths.lib]) % for send_osc and load_xdf

% speed
NominalSrate = 250;
chunksize = 1;
stability = chunksize/NominalSrate;

% fetch file
name.file = 'eeg'; 
files.list = dir(fullfile(paths.in, '*.xdf'));
files.which = find(contains({files.list.name}, name.file ),1);

disp(['loading session... ', paths.in, '\' ,files.list(files.which).name])
cd(paths.lib)
eeglab
demo = load_xdf([paths.in, '\' ,files.list(files.which).name]);




%% ORGANIZATION EFFORTS
% NAME DATASETS
paths.eegname = 'EEG';
disp('organizing streams')
for idx = 1:length(demo)
    if strcmp(demo{1, idx}.info.name, 'APStream')
        APS = demo{1, idx};
    elseif strcmp(demo{1, idx}.info.name, 'EMStream')
        EM = demo{1,idx};
    elseif strcmp(demo{1, idx}.info.name, paths.eegname)
        EEG = demo{1,idx};
    end
end
clear idx


figure
plot(EEG.time_series(10,:))
% channel 10 = O2
% double checks 

%% create outlet
% feedback outlet

outlet_name = 'EEG';
outlet_type = 'EEG'; % necessary for load_xdf later
channelCount = size(EEG.time_series,1); % number of channels you want to stream
ChannelFormat = 'cf_double64'; % 'cf_float32', 'cf_double64', 'cf_string', 'cf_int32', 'cf_int16', 'cf_int8'
SourceId = 'sdfwerr33232';
info = lsl_streaminfo(lib, outlet_name,outlet_type,channelCount,NominalSrate, ChannelFormat, SourceId);
eeg_outlet = lsl_outlet(info);

%% push data
duration = length(EEG.time_series) / NominalSrate;
minutes = floor(duration/60);

disp(['duration: ', num2str(duration), ' seconds (', num2str(minutes), ' minutes and ', num2str(duration - minutes*60), ' seconds' ,')'])
disp(['sampling rate: ', num2str(NominalSrate), '; stability value: ', num2str(stability)])
disp(['number of channels: ', num2str(channelCount)])
disp(['streaming ', paths.in])


pause(0.1)
for i = 1: length(EEG.time_series)-1
    eeg_outlet.push_sample(double(EEG.time_series(:,i)))

    pause(stability);
end
disp('gmae over')

%% simple plot
% figure
% timevec = (0: length(EEG.time_series)-1) / NominalSrate;
% 
% for i = 10% 1:size(EEG.time_series,1)
% plot(timevec, EEG.time_series(i,:))
% hold on
% end
% title('raw data,  channel O2')
% xlabel('Time (s)')
% ylabel('Amplitude (μV)')

%% plot magnitude spectrum
% figure
% 
% Y = fft(EEG.time_series(10,:)); % Compute FFT
% L = length(EEG.time_series(10,:)); % Number of samples
% frequencies = (0:L-1) * (NominalSrate / L); % Frequency axis
% plot(frequencies, abs(Y)); % Plot magnitude spectrum
% xlim([1 50]); % Show only 1-50 Hz
% 
% xlabel('Frequency (Hz)');
% ylabel('Amplitude');
% title('Magnitude Spectrum');
% 
% %% plot power spectrum
% figure;
% plot(frequencies, abs(Y).^2); % Square magnitude for power
% xlim([1 50]); % Show only 1-50 Hz
% xlabel('Frequency (Hz)');
% ylabel('Power');
% title('Power Spectrum');

