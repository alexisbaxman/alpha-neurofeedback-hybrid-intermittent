%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fix chunks
clear all; close all; clc

for i = 33

paths.main     = '\\daten.w2kroot.uni-oldenburg.de\home\jofo2989\Documents\mt';
paths.in = [paths.main, '\data\participants\participant_', num2str(i)];
paths.out = paths.in;

name.chunks = 'chunks.mat';
    cd(paths.in)


%% load participants
% just run a for loop for a function that loads and rewrites all participants
% load chunksize
if exist([paths.in, '\', name.chunks ], 'file')
    load([paths.in, '\', name.chunks ])
    disp(['size stream samples = ', num2str(size(stream.smpl,2))])
end

%% save


chunks = stream.smpl;
save('chunksize.mat', 'chunks', '-v7')

disp('chunk are fixed!')
disp(['size = ', num2str(size(chunks,2))])

end
