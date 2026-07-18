%% separate streams


clear all; close all; clc
paths.main     = '\\daten.w2kroot.uni-oldenburg.de\home\jofo2989\Documents\mt';
paths.in = [paths.main, '\data\participants'];
paths.script = [paths.main, '\scripts\analysis'];

% libs (for loading_xdf)
paths.lib = [paths.main, '\libs'];


% subjects
list.subj = dir(fullfile(paths.in));

for p = 3:length(list.subj) % 3 ignores the first 2 entrances: . and ..


    %% load participants
    cd([paths.in, '/', list.subj(p).name])
    load([paths.in, '/', list.subj(p).name, '/storage.mat']);
    load([paths.in, '/', list.subj(p).name, '/trial.mat']);
    load([paths.in, '/', list.subj(p).name, '/task.mat']);

    %% load xdf
    name.file = 'Default';

    files.list = dir(fullfile([paths.in, '\', list.subj(p).name], '*.xdf'));
    files.which = find(contains({files.list.name}, name.file ),1);
    disp(['loading session... ', paths.in, '\' , list.subj(p).name, '\' , files.list(files.which).name])
    cd(paths.lib) % for load_xdf

    demo = loading_xdf([paths.in, '\' , list.subj(p).name, '\' , files.list(files.which).name]);


    %% ORGANIZATION EFFORTS
    % NAME DATASETS
    disp('organizing streams')
    for idx = 1:length(demo)
        if strcmp(demo{1, idx}.info.name, 'AAAStream')
            AAA = demo{1, idx};
        elseif strcmp(demo{1, idx}.info.name, 'EMStream')
            EM = demo{1,idx};
        elseif strcmp(demo{1, idx}.info.name, 'EEG')
            EEG = demo{1,idx};
        elseif strcmp(demo{1, idx}.info.name, 'NFBStream')
            SONIC = demo{1,idx};
        end
    end
    clear idx

    %% save
     cd([paths.in, '\' , list.subj(p).name])
    save('AAA.mat', 'AAA', '-v7')
end
