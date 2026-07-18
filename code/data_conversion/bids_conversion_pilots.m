%% bids converter - pilots
clear all; close all; clc

paths.in = '\\daten.w2kroot.uni-oldenburg.de\myhome\Documents\mt\data\pilots';
paths.out = '\\smb.uni-oldenburg.de\psychologie$\Neuro\data\projects\alo_alpha_neurofeedback';

list = dir(paths.in);
list = list(3:end);

%% start

for s = 1:length(list)
    % create paths
    paths.raw_folder = fullfile(list(s).folder, list(s).name);
    if s < 10
        paths.bids_folder = fullfile(paths.out, ['sub-pilot0', num2str(s)]);
    else
        paths.bids_folder = fullfile(paths.out, ['sub-pilot', num2str(s)]);
    end

    % create folders
    mkdir(paths.bids_folder) % create subject
    mkdir(fullfile(paths.bids_folder, 'eeg'))

    % rename paths for commodity
    paths.bids_folder = fullfile(paths.bids_folder, 'eeg');
    if s < 10
        name = ['sub-pilot0',  num2str(s), '_task-neurofeedback_'];
    else
        name = ['sub-pilot',  num2str(s), '_task-neurofeedback_'];

    end


    %% copy data
    % chunks = lsl item --> source_data
    paths.raw_file = fullfile(paths.raw_folder, 'chunks.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'chunks.mat']);
    if exist(paths.raw_file)
        copyfile(paths.raw_file, paths.bids_file)
    end

    % chunksize = simple vector --> bids folders
    paths.raw_file = fullfile(paths.raw_folder, 'chunksize.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'chunksize.mat']);
    if exist(paths.raw_file)
        copyfile(paths.raw_file, paths.bids_file)
    end

    % score = score with error --> source_data
    paths.raw_file = fullfile(paths.raw_folder, 'score.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'score.mat']);
    if exist(paths.raw_file)
        copyfile(paths.raw_file, paths.bids_file)
    end

    % score_fixed = score recalculated --> bids folders
    paths.raw_file = fullfile(paths.raw_folder, 'score_fixed.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'score_fixed.mat']);
    if exist(paths.raw_file)
        copyfile(paths.raw_file, paths.bids_file)
    end

    % AAA
    paths.raw_file = fullfile(paths.raw_folder, 'AAA.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'AAA.mat']);
    if exist(paths.raw_file)
        copyfile(paths.raw_file,  paths.bids_file)
    end

    % EM
    paths.raw_file = fullfile(paths.raw_folder, 'EM.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'EM.mat']);
    if exist(paths.raw_file)
        copyfile(paths.raw_file,  paths.bids_file)
    end

    % storage
    paths.raw_file = fullfile(paths.raw_folder, 'storage.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'storage.mat']);
    if exist(paths.raw_file)
        copyfile(paths.raw_file,  paths.bids_file)
    end

    % task
    paths.raw_file = fullfile(paths.raw_folder, 'task.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'task.mat']);
    if exist(paths.raw_file)
        copyfile(paths.raw_file,  paths.bids_file)
    end

    % thres
    paths.raw_file = fullfile(paths.raw_folder, 'thres.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'thres.mat']);
    if exist(paths.raw_file)
        copyfile(paths.raw_file,  paths.bids_file)
    end

    % trial
    paths.raw_file = fullfile(paths.raw_folder, 'trial.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'trial.mat']);
    if exist(paths.raw_file)
        copyfile(paths.raw_file,  paths.bids_file)
    end

    % big boy
    paths.raw_file = fullfile(paths.raw_folder, 'sub-P001_ses-S001_task-Default_run-001_eeg.xdf');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'eeg.xdf']);
    if exist(paths.raw_file)
        copyfile(paths.raw_file,  paths.bids_file)
    end

       % big boy: baseline
    paths.raw_file = fullfile(paths.raw_folder, 'pilot01_Baseline.xdf');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'baseline.xdf']);
    if exist(paths.raw_file)
        copyfile(paths.raw_file,  paths.bids_file)
    end

    % bl: only in some pilots
    paths.raw_file = fullfile(paths.raw_folder, 'bl.mat');
    paths.bids_file = fullfile(paths.bids_folder, [name, 'bl.mat']);
    if exist(paths.raw_file)
        copyfile(paths.raw_file,  paths.bids_file)
    end

    %%
    disp([name(1:11), ' converted'])

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
    if strcmp(list_files(f).name(end-3:end), '.xdf')
        % load(list_files(f).name) this is to test whether it actually works
%    elseif 
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
      if s < 10
        paths.bids_folder = fullfile(paths.out, ['sub-pilot0', num2str(s)], 'eeg');
        name = ['sub-pilot0', num2str(s)];
    else
        paths.bids_folder = fullfile(paths.out, ['sub-pilot', num2str(s)], 'eeg');
        name = ['sub-pilot', num2str(s)];
      end
      cd(paths.bids_folder)

    % save eeg.json
    fid = fopen([name,'_task-neurofeedback_eeg.json'],'w');
    fprintf(fid, '%s', jsonText);
    fclose(fid);

    % save channels.tsv
    writetable(channels.table, [name, '_task-neurofeedback_channels.tsv'], ...
        'FileType','text', 'Delimiter','\t');

    writetable(electrodes.table, [name ,'_task-neurofeedback_electrodes.tsv'], ...
        'FileType','text', 'Delimiter','\t');

end

disp('metadata created')
