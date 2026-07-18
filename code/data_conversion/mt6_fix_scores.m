%% mt6_fix_scores
% just run a for loop that loads all storage and writes all participants
% fixed scores
% display participant's scores

clear all; close all; clc
paths.main     = '\\daten.w2kroot.uni-oldenburg.de\home\jofo2989\Documents\mt';
paths.in = [paths.main, '\data\participants\'];
list.subj = dir(fullfile(paths.in));


ignore.list = [6, 7, 9, 16, 18, 21, 27]; % only alpha


% trials per condition
test.reg = 32;  
test.disc = 20;

high = 38;
low = 40;

for p = 3:length(list.subj) % 3 ignores the first 2 entrances: . and ..

    %% load participants
    cd([paths.in, '/', list.subj(p).name])
    load([paths.in, '/', list.subj(p).name, '/storage.mat']);

    %% create table
T = table;
T.trial = storage.trial(:);
T.training = storage.training(:);
T.condition  = storage.condition(:);
T.task = storage.task(:); % is it used?

if length(storage.reward) < length(storage.trial)
    diff = length(storage.trial) - length(storage.reward);
    storage.reward(end:end+diff) = 0;
end

% only for regulation
T.success = storage.reward(:);
T.direction = storage.direction(:);

% discrimination
T.state = storage.state(:);
T.response = storage.response(:);

% remove experimental
taskTrials = ~T.training;
T_task = T(taskTrials, :);

% recalculate regulation taks performance
score.exp.up   = sum(T_task.success & T_task.condition == 1 & T_task.direction == 1);
score.exp.down = sum(T_task.success & T_task.condition == 1 & T_task.direction == 0);
score.cntrl.up = sum(T_task.success & T_task.condition == 0 & T_task.direction == 1);
score.cntrl.down = sum(T_task.success & T_task.condition == 0 & T_task.direction == 0);

% recalculate discrimination taks performance
% keycode 38 = key.high & state.high
% keycode 40 = key.low & state.low
score.exp.th = sum(T_task.condition == 1 & T_task.response == high & T_task.state == high);
score.exp.tl = sum(T_task.condition == 1 & T_task.response == low & T_task.state == low);
score.exp.fh = sum(T_task.condition == 1 & T_task.response == high & T_task.state == low);
score.exp.fl = sum(T_task.condition == 1 & T_task.response == low & T_task.state == high);

score.cntrl.th = sum(T_task.condition == 0 & T_task.response == high & T_task.state == high);
score.cntrl.tl = sum(T_task.condition == 0 & T_task.response == low & T_task.state == low);
score.cntrl.fh = sum(T_task.condition == 0 & T_task.response == high & T_task.state == low);
score.cntrl.fl = sum(T_task.condition == 0 & T_task.response == low & T_task.state == high);

%% failsafe
if score.exp.th + score.exp.tl + score.exp.fh + score.exp.fl > 20
    disp(['participant ', num2str(p-2), 'error in discrimination task, experimental block'])
end

if score.cntrl.th + score.cntrl.tl +score.cntrl.fh + score.cntrl.fl > 20
    disp(['participant ', num2str(p-2), 'error in discrimination task, control block'])
end

%% let's look?
% simplify scores
score.up = score.exp.up + score.cntrl.up;
score.down = score.exp.down + score.cntrl.down;

score.th = score.exp.th + score.cntrl.th;
score.tl = score.exp.tl + score.cntrl.tl;
score.fh = score.exp.fh + score.cntrl.fh;
score.fl = score.exp.fl + score.cntrl.fl;


disp([' '])
disp('========================================')
disp('===============SCOREBOARD===============')
disp(['Participant: ', num2str(p-2)])
disp('REGULATION TASK:')
disp(['thresholds reached: ', num2str(sum(score.up + score.down)), ' out of ', num2str(test.reg*2)])
disp(['downregulation: ', num2str(score.down), ' trials'])
disp(['upregulation: ',  num2str(score.up), ' trials'])
disp(['success rate: ', num2str(round((sum(score.up + score.down)/(test.reg*2)*100), 2)), '%'])
disp('========================================')
disp('DISCRIMINATION TASK:')
disp(['total amount of correct answer: ', num2str(sum(score.th+score.tl))])
disp(['total amount of incorrect answer: ', num2str(sum(score.fh+score.fl))])
score.sensitivity = score.th / (score.th + score.fl); % they were i high state
score.specificity = score.tl / (score.tl + score.fh); % they were in low state
score.balanced_accuracy = (score.sensitivity + score.specificity)/2;
disp(['balanced accuracy: ', num2str(round(score.balanced_accuracy*100,2)), '%'])
disp('========================================')

%% save
%save('score_fixed.mat', 'score', '-v7')

end
