%% bids converter
clear all; close all; clc

paths.in = '\\daten.w2kroot.uni-oldenburg.de\myhome\Documents\mt\data\participants';
paths.out = '\\smb.uni-oldenburg.de\psychologie$\Neuro\data\projects\alo_alpha_neurofeedback';

list = dir(paths.in);
list = list(3:end);

knob.pilots = 1; % 0 = work on participants, 1 = work on pilots

%% start

for s = 1:length(list)
    % create paths
    paths.raw_folder = fullfile(list(s).folder, list(s).name);
    paths.bids_folder = fullfile(paths.out, ['sub-', list(s).name(end-1:end)]);

    % create folders
    mkdir(paths.bids_folder) % create subject
    mkdir(fullfile(paths.bids_folder, 'eeg'))
    mkdir(fullfile(paths.bids_folder, 'sourcedata'))

    % rename paths for commodity
    paths.source_data = fullfile(paths.bids_folder, 'sourcedata');
    paths.bids_folder = fullfile(paths.bids_folder, 'eeg');
    name = ['sub-', list(s).name(end-1:end), '_task-neurofeedback_'];



    %% copy source data
    % chunks = lsl item --> source_data
    paths.raw_file = fullfile(paths.raw_folder, 'chunks.mat');
    copyfile(paths.raw_file, paths.source_data)

    % chunksize = simple vector --> bids folders
    paths.raw_file = fullfile(paths.raw_folder, 'chunksize.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'chunksize.mat']);
    copyfile(paths.raw_file, paths.bids_file)

    % score = score with error --> source_data
    paths.raw_file = fullfile(paths.raw_folder, 'score.mat');
    copyfile(paths.raw_file, paths.source_data)

    % score_fixed = score recalculated --> bids folders
    paths.raw_file = fullfile(paths.raw_folder, 'score_fixed.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'score_fixed.mat']);
    copyfile(paths.raw_file, paths.bids_file)

    %% copy list_files

    % AAA
    paths.raw_file = fullfile(paths.raw_folder, 'AAA.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'AAA.mat']);

    copyfile(paths.raw_file,  paths.bids_file)

    % EM
    paths.raw_file = fullfile(paths.raw_folder, 'EM.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'EM.mat']);

    copyfile(paths.raw_file,  paths.bids_file)

    % storage
    paths.raw_file = fullfile(paths.raw_folder, 'storage.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'storage.mat']);

    copyfile(paths.raw_file,  paths.bids_file)

    % task
    paths.raw_file = fullfile(paths.raw_folder, 'task.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'task.mat']);

    copyfile(paths.raw_file,  paths.bids_file)

    % thres
    paths.raw_file = fullfile(paths.raw_folder, 'thres.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'thres.mat']);

    copyfile(paths.raw_file,  paths.bids_file)

    % trial
    paths.raw_file = fullfile(paths.raw_folder, 'trial.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'trial.mat']);

    copyfile(paths.raw_file,  paths.bids_file)

    % big boy
    paths.raw_file = fullfile(paths.raw_folder, 'sub-P001_ses-S001_task-Default_run-001_eeg.xdf');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'eeg.xdf']);

    copyfile(paths.raw_file,  paths.bids_file)

    %% 
    disp([name(1:6), ' converted'])

end





%% metadata
% load an eeg file
eeglab

paths.lib = '\\smb.uni-oldenburg.de\psychologie$\Neuro\data\projects\alo_alpha_neurofeedback\libs';
addpath(paths.lib)

paths.test = '\\smb.uni-oldenburg.de\psychologie$\Neuro\data\projects\alo_alpha_neurofeedback\sub-01\eeg';
list_files = dir(paths.test);
list_files = list_files(3:end);

for f = 1:length(list_files)
    if strcmp(list_files(f).name(end-3:end), '.mat')
        % load(list_files(f).name) this is to test whether it actually works
    else
        %full = loading_xdf(list_files(f).name);

        file = [list_files(f).folder, '\', list_files(f).name];
        EEG = pop_loadxdf(file);

    end
end

paths.chanlocs = '\\daten.w2kroot.uni-oldenburg.de\home\jofo2989\Documents\MATLAB\eeglab_current\eeglab2025.0.0\plugins\dipfit\standard_BEM\elec\standard_1020.elc';
EEG =pop_chanedit(EEG,  'lookup', paths.chanlocs);

% build eeg.json
jsonStruct.TaskName = 'neurofeedback';
jsonStruct.SamplingFrequency = EEG.srate;
jsonStruct.PowerLineFrequency = 50;
jsonStruct.EEGReference = 'FCz';
jsonStruct.SoftwareFilters = 'n/a';

jsonText = jsonencode(jsonStruct);

% build channels.tsv
channels.name = string({EEG.chanlocs.labels})';
channels.types = string({EEG.chanlocs.type})';
channels.units = repmat("uV", length(channels.name), 1);
channels.table = table(channels.name, channels.types, channels.units, 'VariableNames', {'name', 'type', 'units'});

% build electrodes.tsv
channels.x = [EEG.chanlocs.X]';
channels.y = [EEG.chanlocs.Y]';
channels.z = [EEG.chanlocs.Z]';
electrodes.table = table(channels.name, channels.x, channels.y, channels.z, 'VariableNames', {'name', 'X', 'Y', 'Z'});

%% save data


for s = 1:length(list)
    paths.bids_folder = fullfile(paths.out, ['sub-', list(s).name(end-1:end)], 'eeg');
    cd(paths.bids_folder)

    % save eeg.json
    fid = fopen(['sub-',list(s).name(end-1:end),'_task-neurofeedback_eeg.json'],'w');
    fprintf(fid, '%s', jsonText);
    fclose(fid);

    % save channels.tsv
    writetable(channels.table, ['sub-', list(s).name(end-1:end),'_task-neurofeedback_channels.tsv'], ...
        'FileType','text', 'Delimiter','\t');

    writetable(electrodes.table, ['sub-', list(s).name(end-1:end),'_task-neurofeedback_electrodes.tsv'], ...
        'FileType','text', 'Delimiter','\t');

end

disp('metadata created')
