%% experiment control script
% 06.03.2023
close all; clear; clc; beep off;

knob.PC = 3; % 1 PC, 2 server, 3 LAB
knob.debugging = 0; % 0 no, 1 yes = automatic space and H click, save sonification
  
% to counter balance order across participants
%cond.order = [1,2,2,1];
cond.order = [2,1,1,2];

% not editable:
knob.training = 1; %  0 no, 1 yes; not easy to debug
knob.task = 1; % 0 discrimination, 1 regulation; it starts with regulation, leave it at 1
knob.cond = 1; % 1 experimental first, 0 contrl first; it doesn't matter, it will follow cond.order
tdex = 1; % index for overall progress

% PATHS
paths.main     = '\\smb.uni-oldenburg.de\psychologie$\Neuro\data\projects\alo_alpha_neurofeedback';
paths.in = [paths.main, '\stimuli'];

% LIBS
paths.lib = [paths.main, '\libs'];
addpath([paths.lib]) % for send_osc and load_xdf
paths.ptb = ['C:\toolbox\Psychtoolbox'];
addpath([paths.ptb]) % never never use genpath
addpath(genpath([paths.lib, '\liblsl-Matlab'])); % inlet
lib = lsl_loadlib();
javaaddpath([paths.lib, '\netutil-1.0.0.jar']); % outlet

% ring bufer variables
ring.chunksize = 100; % desired amount of samples per chunk;
ring.srate = 250             ; % 512 cattan
% information only necessary for stability calculation
ring.stability = ring.chunksize/ring.srate;

% time variables
time.short = 3; % for waiting
time.threshold = 4; % seconds necessary above or below the threshold
time.break = 60; % 1 minute break
time.refractory = time.threshold+1;
time.max = time.threshold * 4; % maximun amount of seconds the participant is in theshold calculation
knob.refractory = 1; % switch to deactivate it
% amount of iterations the participant has to fullfill the condition; 4 seconds
thres.limit = ceil(time.threshold/ring.stability);

% baseline variables
bl.num = 10; % number of baseline recordings (alternate both conditions)
bl.time = 21; % duration of each baseline
% for the pilot data = 29.673s per baselines (if 6 bl.num)
bl.cnt = 1; % baseline counter, it starts at 0
thres.z(1) = 0; % how the std modifeis the threshold
thres.z(2) = 1; % how thr std modifies sonic edge values
bl.aaa = []; % to store baseline aaa values
thres.trial = []; % to store the trial
bl.open = [];


% alpha exploration variables
exploration.cnt = 1; % to decide which instructions to show, we start with 1
exploration.instructions = 1; % kind of toggle
time.exploration = 60;

% TASKS INDEX CALCULATOR
training.reg = 16; % training trials: 4 up, 4 down, 4 up, 4 down
training.disc = 5;
test.reg = 32;  % it has to be an even number for the amount of scenarios
test.disc = 20;
tasks.total = 10; % total number of tasks, not counting training
tasks.trials.value = [test.reg/2 test.disc/2];

tasks.index = zeros(1, tasks.total-1); % it creates te empty array for pre-location
tasks.index(1) = training.reg+training.disc;


% this is the final product, we wantt an array with the value for the trials for swtich case tdex
tasks.toggle = 1;
for i = 1:tasks.total-2 % -2 of the training
    tasks.toggle = 1-tasks.toggle;
    tasks.index(i+1) = tasks.index(i) + tasks.trials.value(tasks.toggle+1); % +2 of the training
end


% for trial control
cond.counter = 1; % counter to move within te order
tasks.counter = 1;
tasks.toggle = 0; % a toggle for switching among blocks, the first time has to be 0 so it results in 1
knob.instructions = 0; % 0 for pre-location
knob.reward = 0; % to activate the reward

% regulation thrshold change
change.counter = 0; % decides when to change
change.often = [4, 8]; %how often does the regualtion threshold change
% 1 for training, 2 for experiment
change.direction = 1; % 1 is up 0 is down; it has to be 0 to be 1 in the first loop

% for threshold control?
trial.aaa = [];
trial.average = [];
trial.std = [];
task.aaa = [];
task.average = [];
tasks.std = [];
trial.counter = 1;

switch knob.debugging
    case 1
        disp('Debugging mode: activated')
        disp('>> automatic space and H keypress')
        bl.time = 10; % duration of each baseline
        time.max = 10;


    case 0
        disp('Debugging mode: deactivated')

end

%% EEG MARKERS
knob.event = 1; % so the regulation event gets activated
EM.issues = 9;

EM.screen = 11; % everytime there's something on the screen
EM.next = 12; % everytime the participant press space
EM.end = 13; % end of the experiment

EM.blon = 14; % start of the baseline
EM.open = 15; % open eyes
EM.close = 16; % clsoed eyes
EM.bloff = 17; % baseline off

EM.exploration = 18; % start of alpha training
EM.exploratioff = 19; % end of alpha traing

EM.trial = 20; % new trial = we summed up tdex, and then on the markers calculation we reduce 200
EM.experimental = 21; % experimental condition
EM.control = 22; % control condition
EM.break = 23; % signals the break
EM.trainingon = 24; % starts the training
EM.trainingoff = 25; % the training ends
EM.refractoff = 29; % refractory time is over

EM.son_on = 30;  % sonification on
EM.son_off = 31; % sonification off

EM.reg = 40; % regulation task
EM.upreg_on = 41; % evaluation starts: up-regulation
EM.doreg_on = 42; % evaluation starts: down-regulation
EM.upreg_off = 43; %   threshold reached: upregulation
EM.doreg_off = 44; %   threshold reached: downregulation
EM.reg_timeout = 45; % timeout regulation task, not specialized

EM.disc = 50; % discrimination task
EM.disc_on = 51; % evaluation starts: discrimination
EM.disc_high = 52; % threshold reached: high alpha state
EM.disc_low = 53; % threshold reached: low alpha state
EM.disc_timeout = 54; % timeout discrimination task

EM.prompt = 60; % prompt jumps
EM.response = 65; % participant press a key
EM.th = 61; % correct answer: true high
EM.tl = 62; % correct answer: true low
EM.fh = 63; %incorrect answer: false high
EM.fl = 64; %incorrect answer: false low


% score system
score.exp.up = 0; % upregulation
score.cntrl.up = 0;
score.exp.down = 0; % downregulation
score.cntrl.down = 0; % downregulation

score.exp.th = 0; % discrimination true high
score.cntrl.th = 0; % discrimination true high
score.exp.tl = 0; % dsicrimination true low
score.cntrl.tl = 0; % dsicrimination true low
score.exp.fh = 0; % discrimination false high
score.cntrl.fh = 0; % discrimination false high
score.exp.fl = 0; % discrimination false low
score.cntrl.fl = 0; % discrimination false low

% pre-creating storage
storage.state = []; % saves participant current state to compare with ....
storage.response = [];
storage.trial = [];
storage.condition = [];
storage.training = [];
storage.task = [];
storage.direction = [];


%% FOR SONIFICATION

% for values capping
sonic.cap.val = 0.5; % cap value, define maximum difference between single interval; high values allows big difference
sonic.cap.start = [0, 0.25];  % starting values for the capping so it fades in
sonic.cap.down = sonic.cap.start(1); % starting value, it will get updated through the experiment
sonic.cap.up = sonic.cap.start(2); % highest value capping, they get updated through the experiment
sonic.floor = 0.1; % minimun amplitude, slightly increased for normalization
sonic.ceiling = 0.999; % maximun amplitude for normalitazion
sonic.mute = 0.01;% to push out to silence purr data patch
sonic.steps = 5; % for muting

% for send_osc
osc.host = '127.0.0.1';
osc.port = 3000;
osc.addr = '/SUB1';

% AUDIO WORK
% don't use sound(audio.y{1}, audio.Fs{1}); but playblocking to avoid memory issues
audio = [];
audio.files = {'\bell.ogg','\tada.ogv'};
for index = 1:length(audio.files)
    [audio.y{index}, audio.Fs{index}] = audioread(fullfile(paths.in, audio.files{index}));
    % Calculate the RMS value of the current audio
    audio.rmsValue{index} = rms(audio.y{index});
end

% NORMALIZE VOLUME
audio.averagerms = mean(cell2mat(audio.rmsValue));
audio.attenuation = 0.8; % make it less loud

for index = 1:length(audio.files)
    % Calculate volume adjustment based on the ratio of the average RMS to the current sound's RMS
    audio.volume{index} = audio.averagerms / mean(audio.rmsValue{index}) * audio.attenuation;
    audio.y{index} = audio.y{index} * audio.volume{index};
end

% transform into playerObj for playblocking
sounds = [];
for index = 1:length(audio.files)
    audio.sound{index} = audioplayer(audio.y{index}, audio.Fs{index});
end

% VOICES
voices = [];
voices.files = {'\01_close.mp3','\01_open.mp3', '\02_decrease.mp3', '\02_increase.mp3', '\03_sonon.mp3', '03_sonoff.mp3', '04_disc.mp3'};
for index = 1:length(voices.files)
    [voices.y{index}, voices.Fs{index}] = audioread(fullfile([paths.in, '\voices'], voices.files{index}));
    voices.sound{index} = audioplayer(voices.y{index}, voices.Fs{index});
end


%% PTB ROUTINE

% KEYS
key.escape = ('ESCAPE');
key.next = ('SPACE');
key.high = ('UpArrow'); % keycode 38
key.low = ('DownArrow'); % keycode 40
key.state.high = 38;
key.state.low = 40;


% ptb variables
ptb = [];
ptb.font.small = 45;
ptb.font.big = 110; % 80 --> 110, shari's feedback

%sca; % clean screen
PsychDefaultSetup(2);

Screen('Preference', 'SkipSyncTests', 1); 

%Screen('Preference','SyncTestSettings' ,0.002,50,0.1,5);
% For synchronicity issues, raise the precision from 0.001s standard deviation to 0.002
Screen('Preference', 'SyncTestSettings', 0.005, 50, 0.1, 5);
% Try reducing the strictness of the VBL sync tests. You can adjust the sync test settings by lowering the precision requirement:

% screens
screens = Screen('Screens');
ptb.screen = max(screens); % this control the display
% screenNumber = 2 (right one or big one)

% Define black, white and grey
ptb.black = BlackIndex(ptb.screen);
ptb.white = WhiteIndex(ptb.screen)/1.5; % grey colour?


% starts ptb properly in screenNumber
[ptb.window, ~] = PsychImaging('OpenWindow', ptb.screen, ptb.black);
Screen('BlendFunction', ptb.window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA'); % blend funciton for the screen

%%

% displays

disp(['Condition order: ', num2str(cond.order(1:end))])
disp(' ')
disp(['pause value: ', num2str(ring.stability)])


disp(' ')

















%% PROLOGUE: CONNECTIONS


% AAA INLET
stream_name = {'AAAStream'};
resolve = {};
while isempty(resolve)
    resolve = lsl_resolve_byprop(lib, 'name', stream_name{1}); % might create an infinite loop
    disp('resolving AAA inlet...')
end
aaainlet = lsl_inlet(resolve{1}); % even if it works, it's empty
clear stream_name resolve

% EEG MARKERS OUTLET
outlet.name = 'EMStream';
outlet.type = 'EEG Markers';
outlet.channelCount = 1;
outlet.NominalSrate = 0; %& irregular
outlet.ChannelFormat = 'cf_double64'; % 'cf_float32', 'cf_double64', 'cf_string', 'cf_int32', 'cf_int16', 'cf_int8'
outlet.SourceId = 'sdfwerr33232';
outlet.info = lsl_streaminfo(lib, outlet.name, outlet.type, outlet.channelCount, outlet.NominalSrate, outlet.ChannelFormat, outlet.SourceId);
outlet.em = lsl_outlet(outlet.info);


% SONIFICATION OUTLET
outlet.name = 'NFBStream'
outlet.type = 'Sonification';

outlet.info = lsl_streaminfo(lib, outlet.name, outlet.type, outlet.channelCount, outlet.NominalSrate, outlet.ChannelFormat, outlet.SourceId);
outlet.nfb = lsl_outlet(outlet.info);

disp(' ')

disp('start lab recorder: EEG, AAA, EM, NFB')


%% EPISODE 0: Welcome!
Screen('TextSize', ptb.window, ptb.font.small);
Screen('TextFont', ptb.window, 'Times');
DrawFormattedText(ptb.window, ['Welcome!\n',...
    'Thank you for your participation. \n',...
    ' ',...
    'Please wait until we tell you to proceed.'], 'center', 'center', ptb.white, [], [], [], 1.5);
Screen('Flip', ptb.window);

WaitSecs(time.short);


% Wait for the space bar keypress
while 1
    [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
    if keyIsDown
        if keyCode(KbName(key.next))
            outlet.em.push_sample(EM.next)
            break;  % Exit the loop when the space bar is pressed
        elseif keyCode(KbName(key.escape))
            sca;  % Close the Psychtoolbox window and exit the program
            return;  % Exit the script
        else
        end
    end

end % while 1

disp(' ')

%% EPISODE 1: BASELINE INSTRUCTIONS

Screen('TextSize', ptb.window, ptb.font.small);
Screen('TextFont', ptb.window, 'Times');
DrawFormattedText(ptb.window, ['Now we will record your brain waves in 2 \n' ...
    'conditions: eyes closed and eyes open. \n' ...
    ' \n',...
    'You will hear a voice instructing you to either \n',...
    ' close or open your eyes \n' ...
    ' \n',...
    'This phase will last a couple of minutes. \n',...
    'Please, relax and remain as still as possible. \n',...
    ' \n',...
    ' [press space to continue]'], 'center', 'center', ptb.white, [], [], [], 1.5);

% Flip to the screen
Screen('Flip', ptb.window);

WaitSecs(time.short);


% Wait for the space bar keypress
while 1
    switch knob.debugging
        case 1
            WaitSecs(time.short);
            outlet.em.push_sample(EM.next)
            break; % breaks this while loop
        case 0
            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
            if keyIsDown
                if keyCode(KbName(key.next))
                    outlet.em.push_sample(EM.next)
                    break;  % Exit the loop when the space bar is pressed
                elseif keyCode(KbName(key.escape))
                    sca;  % Close the Psychtoolbox window and exit the program
                    return;  % Exit the script
                else
                end
            end
    end % switch knob.dbugging
end % while 1

disp(' ')


%% EPISODE 1: BASELINE RECORDING

outlet.em.push_sample(EM.blon);

bl.instructions = 1;
while bl.cnt <= bl.num % the while loop ends when the total amount of baselines are over

    switch bl.instructions
        case 1
            bl.instructions = 0;
            disp(['baseline ', num2str(bl.cnt), ' of ', num2str(bl.num)])

            % screen 1: instruction
            Screen('TextSize', ptb.window, ptb.font.small);
            Screen('TextFont', ptb.window, 'Times');
            switch rem(bl.cnt,2)
                case 1 % EYES CLOSED BASELINE: we start here
                    DrawFormattedText(ptb.window, ['Please close your eyes.\n'], 'center', 'center', ptb.white, [], [], [], 1.5);
                    Screen('Flip', ptb.window);
                    playblocking(voices.sound{1}); % close your eyes
                    WaitSecs(time.refractory); % for them to read and close their eyes

                    Screen('FillRect', ptb.window, ptb.black);
                    Screen('Flip', ptb.window);
                    [aaachunk, ts] = aaainlet.pull_chunk();
                    outlet.em.push_sample(EM.close);
                    startTime = GetSecs;

                case 0 % EYES OPEN BASELINE: we end here
                    DrawFormattedText(ptb.window, ['Please, focus on the cross in the \n',...
                        ' middle of the screen and avoid blinking as \n'...,
                        ' much as possible during this time.\n'], 'center', 'center', ptb.white, [], [], [], 1.5);
                    Screen('Flip', ptb.window);
                    playblocking(voices.sound{2}); % open your eyes
                    % it WaitSecss the code: makes sense after the instruction is displayed
                    WaitSecs(time.short); % for them to read: accumulates with the bell sound

                    % screen 2: cross
                    Screen('TextSize', ptb.window, ptb.font.big);
                    Screen('TextFont', ptb.window, 'Times');
                    DrawFormattedText(ptb.window, '+', 'center', 'center', ptb.white, [], [], [], 1.5);  % fixation cross
                    Screen('Flip', ptb.window);
                    [aaachunk, ts] = aaainlet.pull_chunk();
                    outlet.em.push_sample(EM.open);
                    startTime = GetSecs;
            end % switch rem(bl.cnt,2) for eyes opening and closing

        case 0 % no instructions
            WaitSecs(ring.stability);
            [aaachunk, ts] = aaainlet.pull_chunk();

            % failsafe: in case of temporal disconnections
            if isempty(aaachunk) % retry mechanism
                %outlet.em.push_sample(EM.issues)
                %WaitSecs(ring.stability);
                %disp('>> connection issues <<')
                [aaachunk, ts] = aaainlet.pull_chunk();
                if isempty(aaachunk) % carry on mechanism
                    outlet.em.push_sample(EM.issues)
                    disp('>> connection issues (carry on protocol) <<')

                    WaitSecs(ring.stability);
                    [aaachunk, ts] = aaainlet.pull_chunk();
                    if isempty(aaachunk) % still empty: close
                        sca;
                        disp('>> connection issues (break) <<')
                        break
                    end
                end % for carry on mechanism if loop
            end % for retry mechanism if loop

            switch rem(bl.cnt,2)
                case 1 % EYES CLOSED BASELINE: we start here
                    bl.aaa = [bl.aaa, aaachunk]; % fills-up alpha current state: baseline
                case 0 % eyes open: we end here
                    bl.open = [bl.open, aaachunk];
            end

            switch floor(GetSecs - startTime)
                case bl.time
                    bl.instructions = 1;
                    bl.cnt = bl.cnt+1; % it grows so the next if loop won't be fulllfill until the next bl.time

            end % floor(GetSecs - startTime
    end % bl.instruction

end % baseline recording
outlet.em.push_sample(EM.bloff);
WaitSecs(time.short);
%playblocking(voices.sound{2}); % open your eyes after the baseline recording
% not necessary bc he last baseline is open eyes

%% EPISODE 1: BASELINE ANALYSIS
Screen('FillRect', ptb.window, ptb.black);
Screen('Flip', ptb.window);

disp('=========================================')

bl.average = mean(bl.aaa);
bl.std = std(bl.aaa);
thres.trial = tdex;
thres.new = bl.average;
thres.std = bl.std;
task.average = bl.average; % we need to start task.average somewhere
task.std = bl.std; % we need to start somewhere


disp(['baseline average: ', num2str(bl.average), ' — standard deviation:', num2str(bl.std)])

% define the threshold values: discrimination
thres.disc.low = thres.new(end) - thres.z(1)*thres.std(end);
thres.disc.high = thres.new(end) + thres.z(1)*thres.std(end);

% define the threshold values: regulation
thres.reg.low = thres.new(end) - thres.z(1)*thres.std(end); % the threshold participants
thres.reg.high = thres.new(end) + thres.z(1)*thres.std(end);

% baseline edges for feedback normalization: a full standard deviation
% first iteration, thres.new and bl.average are the same
[sonic.lowest] = thres.new - thres.z(2)*thres.std;
[sonic.highest] = thres.new + thres.z(2)*thres.std;


% to end the analysis, we empty bl.aaa
bl.aaa = [];


disp('=========================================')


disp(' ')


























%%  EPISODE 2: ALPHA EXPLORATION - INSTRUCTIONS

outlet.em.push_sample(EM.exploration);


disp('alpha exploration - instruction')



% SCREEN 1
Screen('TextSize', ptb.window, ptb.font.small);
Screen('TextFont', ptb.window, 'Times');
DrawFormattedText(ptb.window, ['Alpha Waves: \n',...
    ' \n',...
    'When you are calm, relaxed and your mind quiet \n' ...
    'your alpha brain activity increases. \n' ...
    ' \n',...
    'When your mind is more active, such as when you are doing \n',...
    'mental calculations, imagining scenarios or feeling stressed, \n',...
    'your alpha activity becomes lower. \n',...
    ' \n',...
    '[press space to continue]'], 'center', 'center', ptb.white, [], [], [], 1.5);
Screen('Flip', ptb.window);
WaitSecs(time.short); % pls, don't fly away

% Wait for the space bar keypress
while 1
    switch knob.debugging
        case 1
            WaitSecs(time.short);
            outlet.em.push_sample(EM.next)
            break; % breaks this while loop
        case 0
            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
            if keyIsDown
                if keyCode(KbName(key.next))
                    outlet.em.push_sample(EM.next)
                    break;  % Exit the loop when the space bar is pressed
                elseif keyCode(KbName(key.escape))
                    sca;  % Close the Psychtoolbox window and exit the program
                    return;  % Exit the script
                else
                end
            end
    end % switch knob.dbugging
end % while 1



% SCREEN 2
Screen('TextSize', ptb.window, ptb.font.small);
Screen('TextFont', ptb.window, 'Times');
DrawFormattedText(ptb.window, ['Alpha Sonification:  \n',...
    ' \n',...
    'In this experiment we will turn your alpha waves into sound.\n',...
    '\n',...
    'The louder the sound, the stronger your alpha waves. \n',...
    ' \n',...
    'If you increase your alpha waves (keeping a calm mind) \n',...
    'You will  notice that the sound becomes louder.  \n',...
    ' \n',...
    'If you decrease your alpha waves (more busy mind) \n',...
    'The volume of the sonification will go down. \n',...
    ' \n',...
    '[press space to continue]'], 'center', 'center', ptb.white, [], [], [], 1.5);
Screen('Flip', ptb.window);
WaitSecs(time.short); % pls, don't fly away


% Wait for the space bar keypress
while 1
    switch knob.debugging
        case 1
            WaitSecs(time.short);
            outlet.em.push_sample(EM.next)
            break; % breaks this while loop
        case 0
            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
            if keyIsDown
                if keyCode(KbName(key.next))
                    outlet.em.push_sample(EM.next)
                    break;  % Exit the loop when the space bar is pressed
                elseif keyCode(KbName(key.escape))
                    sca;  % Close the Psychtoolbox window and exit the program
                    return;  % Exit the script
                else
                end
            end
    end % switch knob.dbugging
end % while 1


% SCREEN 3
Screen('TextSize', ptb.window, ptb.font.small);
Screen('TextFont', ptb.window, 'Times');
DrawFormattedText(ptb.window, ['Artifacts: \n',...
    ' \n',... 
    'Physical movements, such as jaw tension, head shifts, \n', ...
    'or opening your eyes during the experiment \n', ...
    'can heavily affect the calculation and distort the sonification.\n', ...
    ' \n',...
    'These changes do not reflect your true mental state. \n', ...
    'Try to remain still and keep your eyes closed.',...
    ' \n',...
    '[press space to continue]'], 'center', 'center', ptb.white, [], [], [], 1.5);
Screen('Flip', ptb.window);
WaitSecs(time.short); % pls, don't fly away

% Wait for the space bar keypress
while 1
    switch knob.debugging
        case 1
            WaitSecs(time.short);
            outlet.em.push_sample(EM.next)
            break; % breaks this while loop
        case 0
            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
            if keyIsDown
                if keyCode(KbName(key.next))
                    outlet.em.push_sample(EM.next)
                    break;  % Exit the loop when the space bar is pressed
                elseif keyCode(KbName(key.escape))
                    sca;  % Close the Psychtoolbox window and exit the program
                    return;  % Exit the script
                else
                end
            end
    end % switch knob.dbugging
end % while 1

% SCREEN 4
Screen('TextSize', ptb.window, ptb.font.small);
Screen('TextFont', ptb.window, 'Times');
DrawFormattedText(ptb.window, ['Exploration: \n',...
    ' \n',...
    'Before we begin the training, you will listen\n',...
    'to the sonification for one minute.\n',...
    ' \n', ...
    'The sonification is calibrated to your brain activity with eyes closed, \n', ...
    'so please keep your eyes closed during this phase.\n',...
    ' \n', ...
    'Focus on how you feel and how the sound responds. \n',...
    'Keep in mind that the sound does not change instantly, \n',...
    'there is a delay of about 4 seconds. \n',...
    ' \n',...
    '[press space to continue]'], 'center', 'center', ptb.white, [], [], [], 1.5);
Screen('Flip', ptb.window);
WaitSecs(time.short); % pls, don't fly away

% Wait for the space bar keypress
while 1
    switch knob.debugging
        case 1
            WaitSecs(time.short);
            outlet.em.push_sample(EM.next)
            break; % breaks this while loop
        case 0
            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
            if keyIsDown
                if keyCode(KbName(key.next))
                    outlet.em.push_sample(EM.next)
                    break;  % Exit the loop when the space bar is pressed
                elseif keyCode(KbName(key.escape))
                    sca;  % Close the Psychtoolbox window and exit the program
                    return;  % Exit the script
                else
                end
            end
    end % switch knob.dbugging
end % while 1


% black screen
Screen('FillRect', ptb.window, ptb.black);
Screen('Flip', ptb.window);
playblocking(voices.sound{5}); % sonification activated


%% EPISODE 2: ALPHA EXPLORATION - SONIFICATION


outlet.em.push_sample(EM.exploration);


disp('alpha exploration - sonification')

[aaachunk, ts] = aaainlet.pull_chunk(); % let's get rid off aaa in the network
startTime = GetSecs;

while 1
    pause(ring.stability);

    [aaachunk, ts] = aaainlet.pull_chunk();

    % failsafe: in case of temporal disconnections
    if isempty(aaachunk) % retry mechanism
        %outlet.em.push_sample(EM.issues)
        %disp('>> connection issues <<')
        [aaachunk, ts] = aaainlet.pull_chunk();
        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck; % just in case

        if isempty(aaachunk) % carry on mechanism
            outlet.em.push_sample(EM.issues)
            disp('>> connection issues (carry on protocol) <<')
            pause(ring.stability);
            [aaachunk, ts] = aaainlet.pull_chunk();
            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck; % just in case

            if isempty(aaachunk) % still empty: close
                sca;
                disp('>> connection issues (break) <<')
                break
            end
        end % for carry on mechanism if loop
    end % for retry mechanism if loop


    % SONIFICATION: alpha training
    % Normalize AAA value
    sonic.fb = max(sonic.floor, min(sonic.ceiling, (aaachunk - sonic.lowest) / (sonic.highest - sonic.lowest)));
    % floor is usually 0.01, ceiling is 0.999

    % Apply capping
    sonic.fb = min(sonic.cap.up, max(sonic.cap.down, sonic.fb));

    % in case aaachunk was more than a vlaue
    sonic.fb = mean(sonic.fb);

    % update capping values
    sonic.cap.up = sonic.fb + sonic.fb*sonic.cap.val; % defined for the next loop
    sonic.cap.down = sonic.fb - sonic.fb*sonic.cap.val;

    % send osc
    send_osc(osc.host, osc.port, osc.addr, sonic.fb);
    outlet.nfb.push_sample(sonic.fb)

    switch floor(GetSecs - startTime)
        case time.exploration
            break
    end
end % while loop exploration - sonification


outlet.em.push_sample(EM.exploratioff); % end of the exploration

% mute sonification
sonic.decrease = linspace(sonic.fb, sonic.mute, sonic.steps);

for k = 1:sonic.steps
    sonic.fb = sonic.decrease(k);

    send_osc(osc.host, osc.port, osc.addr, sonic.fb);
    outlet.nfb.push_sample(sonic.fb)

    pause(ring.stability)

end
send_osc(osc.host, osc.port, osc.addr, 0);
outlet.nfb.push_sample(sonic.fb)


disp('sonification off')

playblocking(voices.sound{6}); % sonification deactivated

WaitSecs(time.short); % pls, don't fly away

%%
disp(' ')



















% playblocking(audio.sound{3}); % transition sound


%% EPISODE 3: INSTRUCTIONS REGULATION TRAINING - WITH SONIFICATION
disp('=========================================')
disp('instructions regulation training - with sonification')

% screen 1: intro
Screen('TextSize', ptb.window, ptb.font.small);
Screen('TextFont', ptb.window, 'Times');
DrawFormattedText(ptb.window,...
    ['This experiment consist of two tasks: \n' ...
    'the regulation task and the discrimination task. \n',...
    ' \n',...
    'You will repeat these two tasks several times, \n',...
    'always in the same order: \n',...
    'first regulation, then discrimination.  \n',...
    ' \n',...
    'Now you´ll do a few trials of both tasks \n' ...
    'to help you get familiar with the process.\n',...
    ' \n',...
    '[press space to continue]'], 'center', 'center', ptb.white, [], [], [], 1.5);
Screen('Flip', ptb.window);
outlet.em.push_sample(EM.screen);
playblocking(voices.sound{2}); % open your eyes


while 1 % keypress while loop
    switch knob.debugging
        case 1
            WaitSecs(time.short);
            outlet.em.push_sample(EM.next)
            break; % breaks this while loop
        case 0

            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
            if keyIsDown
                if keyCode(KbName(key.next))
                    outlet.em.push_sample(EM.next)
                    KbReleaseWait; % Ensures key is fully released before continuing
                    break;  % Exit the loop when the space bar is pressed
                elseif keyCode(KbName(key.escape))
                    sca;  % Close the Psychtoolbox window and exit the program
                    return;  % Exit the script
                else
                end
            end % if keyisdown
    end % knob.debug
end % while loop

playblocking(voices.sound{4}); % increase alpha waves

% screen 2: regulation
Screen('TextSize', ptb.window, ptb.font.small);
Screen('TextFont', ptb.window, 'Times');
DrawFormattedText(ptb.window,...
    ['The previous message indicates you will soon start \n', ...
    'the Regulation Task. \n',...
    ' \n',...
    'In the regulation task, your goal is to \n',...
    'manipulate your alpha waves.\n',...
    ' \n',...
    'Initially, you will focus on increasing your alpha state \n',...
    'by relaxing and maintaining a calm mind. \n',...
    ' \n', ...
    'If you reach the desired level, you will hear \n',...
    ' a short fanfare (Ta-da!).\n',...
    ' \n', ...
    '[press space to continue]'], 'center', 'center', ptb.white, [], [], [], 1.5);
Screen('Flip', ptb.window);
outlet.em.push_sample(EM.screen);


while 1 % keypress while loop
    switch knob.debugging
        case 1
            WaitSecs(time.short);
            outlet.em.push_sample(EM.next)
            break; % breaks this while loop
        case 0
            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
            if keyIsDown
                if keyCode(KbName(key.next))
                    outlet.em.push_sample(EM.next)
                    KbReleaseWait; % Ensures key is fully released before continuing
                    break;  % Exit the loop when the space bar is pressed
                elseif keyCode(KbName(key.escape))
                    sca;  % Close the Psychtoolbox window and exit the program
                    return;  % Exit the script
                else
                end
            end % if keyisdown
    end % knob.debug
end % while loop



playblocking(audio.sound{2}) % reward



% screen 3:



Screen('TextSize', ptb.window, ptb.font.small);
Screen('TextFont', ptb.window, 'Times');
DrawFormattedText(ptb.window,...
    ['After a while, you will hear the voice instructing \n',...
    'you to decrease your alpha state.\n',...
    ' \n',...
    'You can try this by thinking about something stressful, \n', ...
    'remembering a tense moment, or imagining physical activity. \n', ...
    ' \n',...
    'You will also be informed if you will hear the sonification \n',...
    'or not during the upcoming task. \n',...
    ' \n',...
    '[press space to continue]'], 'center', 'center', ptb.white, [], [], [], 1.5);
Screen('Flip', ptb.window);
outlet.em.push_sample(EM.screen);



while 1 % keypress while loop
    switch knob.debugging
        case 1
            WaitSecs(time.short);
            outlet.em.push_sample(EM.next)
            break; % breaks this while loop
        case 0
            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
            if keyIsDown
                if keyCode(KbName(key.next))
                    outlet.em.push_sample(EM.next)
                    KbReleaseWait; % Ensures key is fully released before continuing
                    break;  % Exit the loop when the space bar is pressed
                elseif keyCode(KbName(key.escape))
                    sca;  % Close the Psychtoolbox window and exit the program
                    return;  % Exit the script
                else
                end
            end % if keyisdown
    end % knob.debug
end % while loop

playblocking(voices.sound{5}); % sonic on


% screen 4: sonification & start
Screen('TextSize', ptb.window, ptb.font.small);
Screen('TextFont', ptb.window, 'Times');
DrawFormattedText(ptb.window,...
    ['You will now repeat this exercise several times for practice.\n',...
    ' \n',...
    'Please don´t feel frustrated if \n',...
    'you are not initially able to reach the goal. \n',...
    ' \n',...udi
    'For some people it´s not so easy to keep their mind quiet \n',...
    'and the code needs sometime to calibrate to your brain activity. \n',...
    ' \n',...
    '[press space to continue]'], 'center', 'center', ptb.white, [], [], [], 1.5);
Screen('Flip', ptb.window);
outlet.em.push_sample(EM.screen);

while 1 % keypress while loop
    switch knob.debugging
        case 1
            WaitSecs(time.short);
            outlet.em.push_sample(EM.next)
            break; % breaks this while loop
        case 0

            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
            if keyIsDown
                if keyCode(KbName(key.next))
                    outlet.em.push_sample(EM.next)
                    KbReleaseWait; % Ensures key is fully released before continuing
                    break;  % Exit the loop when the space bar is pressed
                elseif keyCode(KbName(key.escape))
                    sca;  % Close the Psychtoolbox window and exit the program
                    return;  % Exit the script
                else
                end
            end % if keyisdown
    end % knob.debug
end % while loop


% screen 5: start
Screen('TextSize', ptb.window, ptb.font.small);
Screen('TextFont', ptb.window, 'Times');
DrawFormattedText(ptb.window,...
    ['During this first training phase, you will start increasing \n' ...
    'your alpha waves and you will be able to hear \n',...
    'the sonification of your alpha waves. \n',...
    ' \n',...
    'Think of it as a rehearsal of the real experiment. \n',...
    ' \n',...
    'Please, keep your eyes closed and avoid unnecessary movements. \n',...
    ' \n',...
    '[press space to start]'], 'center', 'center', ptb.white, [], [], [], 1.5);
Screen('Flip', ptb.window);
outlet.em.push_sample(EM.screen);


while 1 % keypress while loop
    switch knob.debugging
        case 1
            WaitSecs(time.short);
            outlet.em.push_sample(EM.next)
            break; % breaks this while loop
        case 0

            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
            if keyIsDown
                if keyCode(KbName(key.next))
                    outlet.em.push_sample(EM.next)
                    KbReleaseWait; % Ensures key is fully released before continuing
                    break;  % Exit the loop when the space bar is pressed
                elseif keyCode(KbName(key.escape))
                    sca;  % Close the Psychtoolbox window and exit the program
                    return;  % Exit the script
                else
                end
            end % if keyisdown
    end % knob.debug
end % while loop

Screen('FillRect', ptb.window, ptb.black); % goes black
Screen('Flip', ptb.window);

playblocking(voices.sound{1}); % close your eyes: training reg with sonic

% SONIFICATION ON: for training
% we reset the cap values so it fades in
sonic.cap.down = sonic.cap.start(1);
sonic.cap.up = sonic.cap.start(2);

disp('sonification on')

outlet.em.push_sample(EM.trainingon)












%% THE LOOP

while tdex < training.reg + training.disc + (test.reg + test.disc)*2 +1
    WaitSecs(time.short); % in between trials
    outlet.em.push_sample(EM.trial)
    storage.trial(tdex) = tdex;

    %% SWITCH TDEX: TRAINING, INTRO & BREAK
    switch tdex
        case training.reg/2 + 1


            %% EPISODE 3: INSTRUCTIONS REGULATION TRAINING - WITHOUT SONIFICATION

            % SONIFICATION OFF: TRAINING
            % unrelated to knob.cond,
            knob.cond = 0;
            knob.refractory = 1; % we reactivate the refractory time for the nex trial
            % but I need to change so it doesn't send osc

            % mute sonification
            sonic.decrease = linspace(sonic.fb, sonic.mute, sonic.steps);

            for k = 1:sonic.steps
                sonic.fb = sonic.decrease(k);

                send_osc(osc.host, osc.port, osc.addr, sonic.fb);
                outlet.nfb.push_sample(sonic.fb)
                pause(ring.stability)

            end
            send_osc(osc.host, osc.port, osc.addr, 0);
            outlet.nfb.push_sample(sonic.fb)

            disp('sonification off')
            playblocking(voices.sound{6}); % sonic off
            WaitSecs(time.short);

            disp('instructions regulation training - without sonification')

            change.direction = 1; % we need to do this manually
            change.counter = 0; % we need to restart it manually

            Screen('TextSize', ptb.window, ptb.font.small);
            Screen('TextFont', ptb.window, 'Times');
            DrawFormattedText(ptb.window,...
                ['In the next phase of the training, you will repeat the \n'...
                'regulation task, but this time without sonification. \n',...
                '\n',...
                'You will still hear the fanfare when you reach the target level \n'...
                'and the voice message indicating to change direction. \n',...
                ' \n',...
                'You will start by increasing your alpha state. \n',...
                ' \n',...
                'Please relax and keep your eyes closed.\n',...
                'This is still the training phase. \n',...
                ' \n',...
                '[press space to start]'], 'center', 'center', ptb.white, [], [], [], 1.5);
            Screen('Flip', ptb.window);
            outlet.em.push_sample(EM.screen);

            playblocking(voices.sound{2}); % open your eyes

            while 1 % keypress while loop
                switch knob.debugging
                    case 1
                        WaitSecs(time.short);
                        outlet.em.push_sample(EM.next)
                        break; % breaks this while loop
                    case 0

                        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
                        if keyIsDown
                            if keyCode(KbName(key.next))
                                outlet.em.push_sample(EM.next)
                                KbReleaseWait; % Ensures key is fully released before continuing
                                break;  % Exit the loop when the space bar is pressed
                            elseif keyCode(KbName(key.escape))
                                sca;  % Close the Psychtoolbox window and exit the program
                                return;  % Exit the script
                            else
                            end
                        end % if keyisdown
                end % knob.debug
            end % while loop


            Screen('FillRect', ptb.window, ptb.black); % goes black
            Screen('Flip', ptb.window);

            playblocking(voices.sound{1}); % close your eyes: training regulation without sonic
            WaitSecs(time.short);
            playblocking(voices.sound{4}); % increase alpha waves




            %% EPISODE 3: INSTRUCTIONS DISCRIMINATION TRAINING
        case training.reg + 1 % 1 above training regulation

            knob.task = 2; % we modify it manually because we are in the training
            knob.refractory = 1; % we reactivate the refractory time for the nex trial

            disp('instructions discrimination training')

            % screen 1
            Screen('TextSize', ptb.window, ptb.font.small);
            Screen('TextFont', ptb.window, 'Times');
            DrawFormattedText(ptb.window,...
                ['Now you´ll start with the training of the discrimination task. \n' ...
                'Instead of manipulating your alpha state, \n' ...
                'you will need to identify your current alpha state.\n' ...
                ' \n',...
                'During this phase you won´t hear any sonification. \n',...
                ' \n',...
                'But, every so often, you´ll hear a bell sound.\n',...
                ' \n',...
                '[Press space to see the next instructions]'], 'center', 'center', ptb.white, [], [], [], 1.5);
            Screen('Flip', ptb.window);
            outlet.em.push_sample(EM.screen);

            playblocking(voices.sound{2}); % open your eyes

            while 1 % keypress while loop
                switch knob.debugging
                    case 1
                        WaitSecs(time.short);
                        outlet.em.push_sample(EM.next)
                        break; % breaks this while loop
                    case 0

                        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
                        if keyIsDown
                            if keyCode(KbName(key.next))
                                outlet.em.push_sample(EM.next)
                                KbReleaseWait; % Ensures key is fully released before continuing
                                break;  % Exit the loop when the space bar is pressed
                            elseif keyCode(KbName(key.escape))
                                sca;  % Close the Psychtoolbox window and exit the program
                                return;  % Exit the script
                            else
                            end
                        end
                end % knob.debug
            end % while loop

            playblocking(audio.sound{1}); % bell sound: exmaple


            % screen 2
            Screen('TextSize', ptb.window, ptb.font.small);
            Screen('TextFont', ptb.window, 'Times');
            DrawFormattedText(ptb.window,...
                ['At that point you will need to decide if you were, just before \n' ...
                'in a high alpha state (↑) or a low alpha state (↓)\n' ...
                'by pressing ↑ or ↓ on the keyboard. \n',...
                ' \n',...
                'After your answer, you´ll hear the short fanfare (Ta-da!) \n',...
                'if your answer was correct. \n' ...
                'If you hear no sound, it means your answer was incorrect. \n',...
                ' \n',...
                'Depending on certain factors, you might need to wait \n',...
                'to hear the bellsound. Don´t worry about it. \n',...
                ' \n',...
                '[Press space to continue]'], 'center', 'center', ptb.white, [], [], [], 1.5);
            Screen('Flip', ptb.window);
            outlet.em.push_sample(EM.screen);

            while 1 % keypress while loop
                switch knob.debugging
                    case 1
                        WaitSecs(time.short);
                        outlet.em.push_sample(EM.next)
                        break; % breaks this while loop
                    case 0
                        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
                        if keyIsDown
                            if keyCode(KbName(key.next))
                                outlet.em.push_sample(EM.next)
                                KbReleaseWait; % Ensures key is fully released before continuing
                                break;  % Exit the loop when the space bar is pressed
                            elseif keyCode(KbName(key.escape))
                                sca;  % Close the Psychtoolbox window and exit the program
                                return;  % Exit the script
                            else
                            end
                        end
                end % knob.debug
            end % while 1

            % screen 3
            Screen('TextSize', ptb.window, ptb.font.small);

            Screen('TextFont', ptb.window, 'Times');
            DrawFormattedText(ptb.window,...
                ['You will repeat this exercise several times for practice.\n',...
                ' \n',...
                'We suggest you leaving your fingers already over the keys \n',...
                '↑ and ↓ \n',...
                'so you don´t have to search for them later on. \n',...
                ' \n',...
                'Please keep your eyes closed during the session.\n',...
                'This is still the training phase. \n',...
                ' \n',...
                '[press space to start]'], 'center', 'center', ptb.white, [], [], [], 1.5);
            Screen('Flip', ptb.window);
            outlet.em.push_sample(EM.screen);

            while 1 % keypress while loop
                switch knob.debugging
                    case 1
                        WaitSecs(time.short);
                        outlet.em.push_sample(EM.next)
                        break; % breaks this while loop
                    case 0
                        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
                        if keyIsDown
                            if keyCode(KbName(key.next))
                                outlet.em.push_sample(EM.next)
                                KbReleaseWait; % Ensures key is fully released before continuing
                                break;  % Exit the loop when the space bar is pressed
                            elseif keyCode(KbName(key.escape))
                                sca;  % Close the Psychtoolbox window and exit the program
                                return;  % Exit the script
                            else
                            end
                        end
                end % knob.debug
            end % while 1

            Screen('FillRect', ptb.window, ptb.black); % goes black
            Screen('Flip', ptb.window);

            playblocking(voices.sound{1}); % close your eyes: training discrimination


            %% EPISODE 4: INTRODUCTION EXPERIMENT
        case training.reg + training.disc + 1 % 1 above trainings

            knob.training = 0;
            change.counter = 0; % re-start the counter
            change.direction = 0; % we force the change here so we start with upregulation
            knob.refractory = 1; % the mini baseline is an overkill
            %knob.task = 1;% we start with regulation, if we modify it here, it will fail later on in the switching


            disp('introduction experiment')

            % screen 1 (only one)
            Screen('TextSize', ptb.window, ptb.font.small);
            Screen('TextFont', ptb.window, 'Times');
            DrawFormattedText(ptb.window,...
                ['You are now starting the experimental phase of the study.\n',...
                ' \n',...
                'The tasks you´ll perform in this phase will be the same \n',...
                'to the ones you practiced, but for a longer time. \n',...
                ' \n',...
                'Everytime you change of task, you will hear the previous messages \n',...
                'and the instructions will be displayed on the screen. \n',...
                ' \n',...
                'You´ll also be informed whether sonification will be active or not, \n',...
                'and in which direction you´ll start (in the regulation task).\n',...
                ' \n',...
                'There will be a break halfway through.\n',...
                ' \n',...
                '[press space to continue reading]'], 'center', 'center', ptb.white, [], [], [], 1.5);
            Screen('Flip', ptb.window);
            outlet.em.push_sample(EM.screen)
            WaitSecs(time.short);

            playblocking(voices.sound{2}); % open your eyes

            while 1 % keypress while loop
                switch knob.debugging
                    case 1
                        WaitSecs(time.short);
                        outlet.em.push_sample(EM.next)
                        break; % breaks this while loop
                    case 0
                        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
                        if keyIsDown
                            if keyCode(KbName(key.next))
                                outlet.em.push_sample(EM.next)
                                KbReleaseWait; % Ensures key is fully released before continuing
                                break;  % Exit the loop when the space bar is pressed
                            elseif keyCode(KbName(key.escape))
                                sca;  % Close the Psychtoolbox window and exit the program
                                return;  % Exit the script
                            else
                            end
                        end
                end % knob.debug
            end % while loop

            % BASELINE ANALYSIS? not here, when the experiment starts
            % there's a "change" of condition triggered, and therefore it
            % start wit a baseline analysis
            outlet.em.push_sample(EM.trainingoff)



            %% EPISODE 6: THE BREAK
        case training.reg + training.disc + test.reg + test.disc+1 % 74
            outlet.em.push_sample(EM.break)
            % task.counter

            %knob.task = 1; % we start with regulation, i think it's unnecessary
            % knob.task will be decided a posteriori
            change.direction = 0; % we force the change here so we start with upregulation
            knob.refractory = 1; % with the mini baseline, this is an overkill

            disp('=========================================');
            disp('on a break')

            Screen('TextSize', ptb.window, ptb.font.small);
            Screen('TextFont', ptb.window, 'Times');
            DrawFormattedText(ptb.window,...
                ['Break time: \n',...
                ' \n',...
                'Take a 1-minute break. You’re doing great!\n',...
                'Feel free to open your eyes and move your body.\n', ...
                ' \n',...
                'The experiment will continue automatically after the break.\n',...
                ' \n',...
                'The task and instructions will remain the same. \n',...
                ' \n',...
                '[please wait]'], 'center', 'center', ptb.white, [], [], [], 1.5);
            Screen('Flip', ptb.window);
            outlet.em.push_sample(EM.screen)

            playblocking(voices.sound{2}); % open your eyes

            while 1 % keypress while loop
                switch floor(GetSecs - startTime)
                    case time.break
                        break % breaks while loop
                end
            end % while loop
            
    end % switch tdex


    %% EPISODE X: SWITCHING TASK

    switch tdex % this doesn't work on training
        case tasks.index(tasks.counter)+1 % if we have to change of task


            WaitSecs(time.short);
            knob.instructions = 1; % there are instructions
            tasks.toggle = 1-tasks.toggle; % toggle to decide if we change of condtion
            % 0 means we continue in he same block with discrimination
            % 1 means we change of block and we start with regulation
            % the first time has to be 0 so it results in 1
            trial.counter = 1; % to keep track within the task how we progress

            % CHANGE OF CONDITION
            switch tasks.toggle
                case 1 % everytime is 1 we change of condition, so every 2 tasks
                    disp('========================================')
                    disp('change of task: regulation task')

                    knob.task = 1; % we always start with regulation
                    outlet.em.push_sample(EM.reg)

                    % change.direction = 1 - change.direction;
                    % we want to change direction to balance out without
                    % a bell sound
                    change.counter = 0; % re-start the counter

                    switch cond.order(cond.counter) % which block of the 4
                        case 1
                            knob.cond = 1; % with sonification
                            outlet.em.push_sample(EM.experimental);
                            % everytime we change of condition, we sent a marker.
                            disp('with sonification')
                            disp('========================================')

                        case 2
                            knob.cond = 0; % without sonification
                            outlet.em.push_sample(EM.control);
                            disp('without sonification')
                            % everytime we change of condition, we sent a marker.
                    end % switch cond.order

                    cond.counter = cond.counter+1; % it grows when we change of condition: we advance 1 block


                    % switch task.toggle: CHANGE OF CONDITION

                case 0 % if we are not changing of cond, we start the 2nd task of the block, discrimination

                    % SONIFICATION OFF:
                    switch knob.cond
                        case 1 % we turn it off now if it was on, for the discrimination
                            disp('sonification off')
                            outlet.em.push_sample(EM.son_off);
                            % sonification off

                            % mute sonification
                            sonic.decrease = linspace(sonic.fb, sonic.mute, sonic.steps);

                            for k = 1:sonic.steps
                                sonic.fb = sonic.decrease(k);

                                send_osc(osc.host, osc.port, osc.addr, sonic.fb);
                                outlet.nfb.push_sample(sonic.fb)

                                pause(ring.stability)

                            end
                            send_osc(osc.host, osc.port, osc.addr, 0);
                            outlet.nfb.push_sample(sonic.fb)

                            %WaitSecs(time.short);

                            playblocking(voices.sound{6}); % sonification deactivated

                    end % switch knob.cond to turn off the sonification
                    clear i % sonification counter
                    disp('========================================')
                    disp('change of task: discrimination task')
                    outlet.em.push_sample(EM.disc)
                    knob.task = 2; % discrimination task

            end % switch tasks.togle: to switch to regulation of discrimination

            tasks.counter = tasks.counter +1; % everytime we change of task it grows
            % necessary to detect when we need to change of task




            %% EPISODE X: threshold CALCULATION among tasks

            % analysis
            task.average(end+1) = mean(task.aaa); % we save the values for the future
            task.std(end+1) = std(task.aaa);
            disp(['previous task average: ', num2str(task.average(end)), ' — standard deviation: ', num2str(task.std(end))])
            disp('========================================')

            % to end the analysis, we empty task.aaa
            task.aaa = [];

            % we save it by substituing the last thres
            thres.trial(end+1) = tdex;
            thres.new(end+1) = task.average(end);
            thres.std(end+1) = task.std(end);

            % define the diferent threshold values:
            % discrimination
            thres.disc.low = thres.new(end) - thres.z(1)*thres.std(end);
            thres.disc.high = thres.new(end) + thres.z(1)*thres.std(end);
            % regulation
            thres.reg.low = thres.new(end) - thres.z(1)*thres.std(end); % the threshold participants
            thres.reg.high = thres.new(end) + thres.z(1)*thres.std(end);

            % sonification calculation
            [sonic.lowest] = thres.new(end) - thres.z(2)*thres.std(end);   % it used to be stream.ctl(1)
            [sonic.highest] = thres.new(end) + thres.z(2)*thres.std(end); % it used to be baseline(sonic.top)


    end % switch tdex, case tasks.index(tasks.counter)+1




    %% EPISODE X: switching direction
    switch knob.task
        case 1
            switch knob.training
                case 1 % we are in training
                    switch change.counter
                        case change.often(1)
                            change.counter = 0;
                            change.direction = 1-change.direction;
                            knob.refractory = 1; % we reactivate the refractory time for the nex trial

                            % voices
                            switch change.direction
                                case 1
                                    playblocking(voices.sound{4}); % increase
                                case 0
                                    playblocking(voices.sound{3}); % decrease
                            end
                    end % switch to see if we change in training

                case 0 % we are not training
                    switch change.counter
                        case change.often(2)
                            change.counter = 0;
                            change.direction = 1-change.direction;
                            knob.refractory = 1; % we reactivate the refractory time for the nex trial
                            % voices
                            switch change.direction
                                case 1
                                    playblocking(voices.sound{4}); % increase
                                case 0
                                    playblocking(voices.sound{3}); % decrease
                            end % switch change direction
                    end
            end % knob.training
    end % knob.task



    %% EPISODE X: MESSAGE BUILDING among trials

    %  training or not
    switch knob.training
        case 1
            message =(['training trial: ', num2str(tdex)]);
        case 0
            message = (['experimental trial: ', num2str(tdex)]);
    end

    % task and direction
    switch knob.task
        case 1 % regulation

            % sonification
            switch knob.cond
                case 1 % with sonification
                    message = (['with sonification - ', message]);
                case 0 % without
                    message = (['withut sonification - ', message]);
            end

            % direction
            switch change.direction
                case 1 % up regulation
                    message = ['up regulation ', message];
                case 0
                    message = ['down regulation ', message];
            end
        case 2
            message = ['discrimination ', message];
    end


    disp(message);
    disp(['threshold value: ', num2str(thres.reg.low), '. standard deviation value: ', num2str(thres.std(end))]) % right now we only have one value

    % building the storage variable

    storage.condition(tdex) = knob.cond;
    storage.direction(tdex) = change.direction;
    storage.training(tdex) = knob.training;
    storage.task(tdex) = knob.task;






































    %% EPISODE X: SWITCHING TASK INSTRUCTIONS
    switch knob.instructions
        case 1

            knob.instructions = 0; % to avoid it from jumping again
            knob.refractory = 1; % we reactivate the refractory time for the nex trial after instructions

            switch knob.task
                case 1
                    %% EPISODE 4: REGULATION TASK INSTRUCTIONS
                    switch knob.cond
                        case 0 % without sonification
                            instructions.title = 'Regulation Task without Sonification:\n';
                        case 1
                            instructions.title =  'Regulation Task with Sonification:\n';
                    end

                    switch change.direction
                        case 1
                            instructions.message = 'You will now begin increasing your alpha waves. \n';
                        case 0
                            instructions.message = 'You will now begin decreasing your alpha waves. \n';
                    end



                    Screen('TextSize', ptb.window, ptb.font.small);
                    Screen('TextFont', ptb.window, 'Times');
                    DrawFormattedText(ptb.window,...
                        [instructions.title,...
                        ' \n',...
                        'In this task, your goal is to control your alpha waves. \n',...
                        ' \n', ...
                        'When you reach the target level, you’ll hear a short fanfare. \n',...
                        ' \n',...
                        instructions.message,...
                        ' \n',...
                        'Remember to stay relaxed and avoid unncessary movement. \n',...
                        'Please keep your eyes closed during the task. \n',...
                        ' \n',...
                        '[press space to continue]'], 'center', 'center', ptb.white, [], [], [], 1.5);
                    Screen('Flip', ptb.window);
                    outlet.em.push_sample(EM.screen)

                    playblocking(voices.sound{2}); % open your eyes

                    while 1 % keypress while loop
                        switch knob.debugging
                            case 1
                                WaitSecs(time.short);
                                outlet.em.push_sample(EM.next)
                                break; % breaks this while loop
                            case 0

                                [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
                                if keyIsDown
                                    if keyCode(KbName(key.next))
                                        outlet.em.push_sample(EM.next)
                                        KbReleaseWait; % Ensures key is fully released before continuing
                                        break;  % Exit the loop when the space bar is pressed
                                    elseif keyCode(KbName(key.escape))
                                        sca;  % Close the Psychtoolbox window and exit the program
                                        return;  % Exit the script
                                    else
                                    end
                                end
                        end % switch knob.debug
                    end % while loop

                    % VOICES: experimental task

                    playblocking(voices.sound{1}); % close your eyes: regulation task

                    Screen('FillRect', ptb.window, ptb.black); % goes balck
                    Screen('Flip', ptb.window);

                    WaitSecs(time.short);

                    switch knob.cond
                        % SONIFICATION ON: test
                        case 1 % we reset the cap values so it fades in
                            sonic.cap.down = sonic.cap.start(1);
                            sonic.cap.up = sonic.cap.start(2);

                            disp('sonification on')
                            outlet.em.push_sample(EM.son_on)
                    end % switch knob.cond

                    switch knob.cond
                        case 1 % with sonification
                            playblocking(voices.sound{5}); % sonic on
                    end

                    switch change.direction % which direction are we?
                        case 1
                            playblocking(voices.sound{4}); % increase
                        case 0
                            playblocking(voices.sound{3}); % decrease
                    end


                case 2
                    %% EPISODE 5: DISCRIMINATION TASK INSTRUCTIONS


                    Screen('TextSize', ptb.window, ptb.font.small);
                    Screen('TextFont', ptb.window, 'Times');

                    DrawFormattedText(ptb.window,...
                        ['Discrimination task: \n',...
                        ' \n',...
                        'In this task, your goal is to identify your on-going alpha state. \n', ...
                        ' \n',...
                        'Simply focus on how you are feeling and wait for the bell. \n', ...
                        'When you hear it, press ↑ or ↓ to indicate whether \n', ...
                        'you were in a high (↑) or low (↓) alpha state. \n', ...
                        ' \n',...
                        'You’ll hear a fanfare only if your answer was correct. \n',...
                        ' \n',...
                        'Stay relaxed and don’t overthink your responses. \n', ...
                        'Please, keep your fingers on the keys and your eyes closed. \n',...
                        ' \n',...
                        '[press space to start]'], 'center', 'center', ptb.white, [], [], [], 1.5);
                    Screen('Flip', ptb.window);
                    outlet.em.push_sample(EM.screen)

                    playblocking(voices.sound{2}); % open your eyes

                    while 1 % keypress while loop
                        switch knob.debugging
                            case 1
                                WaitSecs(time.short);
                                outlet.em.push_sample(EM.next)
                                break; % breaks this while loop
                            case 0

                                [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
                                if keyIsDown
                                    if keyCode(KbName(key.next))
                                        outlet.em.push_sample(EM.next)
                                        KbReleaseWait; % Ensures key is fully released before continuing
                                        break;  % Exit the loop when the space bar is pressed
                                    elseif keyCode(KbName(key.escape))
                                        sca;  % Close the Psychtoolbox window and exit the program
                                        return;  % Exit the script
                                    else
                                    end
                                end
                        end % switch knob.debug
                    end % while loop

                    Screen('FillRect', ptb.window, ptb.black); % goes balck
                    Screen('Flip', ptb.window);
                    playblocking(voices.sound{1}); % close your eyes: discrimination task
                    WaitSecs(time.refractory);




            end % switch knob task

    end % switch knob instructions









    %% EPISODE X: STARTING THE TASKS

    % counters to be rewritten in every trial
    thres.hold = 1; % changes when the participant fullfils the condition
    thres.cnt.low = 0; % it grows when participant is in low alpha state
    thres.cnt.high = 0;
    thres.not.low = 0; % it grows when participant is NOT in low alpha state
    thres.not.high = 0;

    startTime = GetSecs; % we re-calculate the starting time of every trial


    switch knob.task
        case 1
            %% EPISODE 4: REGULATION TASK - SCREENS
            % let's stop with the screens, the voice should be enough

            %% EPISODE 4: REGULATION TASK - EVALUATION

            [aaachunk, ts] = aaainlet.pull_chunk(); % let's get rid off aaa in the network

            while thres.hold
                % run pseudo buffer
                pause(ring.stability);
                [aaachunk, ts] = aaainlet.pull_chunk();

                % failsafe: in case of temporal disconnections
                if isempty(aaachunk) % retry mechanism
                    %outlet.em.push_sample(EM.issues)
                    %WaitSecs(ring.stability);
                    %disp('>> connection issues <<')
                    [aaachunk, ts] = aaainlet.pull_chunk();
                    if isempty(aaachunk) % carry on mechanism
                        outlet.em.push_sample(EM.issues)
                        disp('>> connection issues (carry on protocol) <<')

                        pause(ring.stability);
                        [aaachunk, ts] = aaainlet.pull_chunk();
                        if isempty(aaachunk) % still empty: close
                            sca;
                            disp('>> connection issues (emergency break) <<')
                            break
                        end
                    end % for carry on mechanism if loop
                end % for retry mechanism if loop

                % SONIFICATION: TEST SONIFICATION
                switch knob.cond
                    case 1
                        % Normalize AAA value
                        sonic.fb = max(sonic.floor, min(sonic.ceiling, (aaachunk - sonic.lowest) / (sonic.highest - sonic.lowest)));

                        % Apply capping
                        sonic.fb = min(sonic.cap.up, max(sonic.cap.down, sonic.fb));

                        % In case aaachunk was not one value
                        sonic.fb = mean(sonic.fb);

                        send_osc(osc.host, osc.port, osc.addr, sonic.fb);
                        outlet.nfb.push_sample(sonic.fb)


                        % recalculate caaa
                        sonic.cap.up = sonic.fb + sonic.fb*sonic.cap.val; % defined for the next loop
                        sonic.cap.down = sonic.fb - sonic.fb*sonic.cap.val;
                      
                        

                end % switch knob.condition

                % REFRACTORY TIME
                switch knob.refractory
                    case 1
                        switch (GetSecs - startTime) > time.refractory % if therefractory time is over
                            case 1
                                knob.refractory = 0; % we go to the proper evaluation
                                outlet.em.push_sample(EM.refractoff);

                        end

                    case 0  % PROPER EVALUATION
                        % if any of the cnt overflows: they fullfil
                        % the condition
                        % we push the appropiate trigger, once the
                        % refractory time is over
                        switch knob.event % so it runs only once
                            case 1
                                knob.event = 0;
                                switch change.direction % this is just triggers
                                    case 1
                                        outlet.em.push_sample(EM.upreg_on) % pushes event: start of the trial
                                    case 0
                                        outlet.em.push_sample(EM.doreg_on) % pushes event: start of the trial
                                end
                        end % switch knob.event

                        switch any(thres.cnt.low >= thres.limit | thres.cnt.high >= thres.limit)
                            case 1
                                EM.event = EM.doreg_off * (change.direction == 0) + EM.upreg_off * (change.direction == 1);
                                outlet.em.push_sample(EM.event);
                                knob.reward = 1;
                                knob.refractory = 1; % we reactivate the refractory time for the nex trial
                                thres.hold = 0; % breaks the above while loop,we'll start a new trial

                                % score system
                                score.exp.up = score.exp.up + (change.direction == 1 & knob.cond == 1);
                                score.cntrl.up = score.cntrl.up + (change.direction == 1 & knob.cond == 0);

                                score.exp.down = score.exp.down +  (change.direction == 0 & knob.cond == 1);
                                score.cntrl.down = score.cntrl.down +  (change.direction == 0 & knob.cond == 0);

                                storage.reward(tdex) = 1;

                                disp('threshold reached!');
                        end

                        trial.aaa = [trial.aaa, aaachunk]; % we store the aaa values: regulation task

                        % proper evaluation
                        thres.low = sum(aaachunk <= thres.reg.low); % is alpha below the threshold
                        thres.high = sum(aaachunk >= thres.reg.high); % is alpha above the threshold
                        thres.mid = not(any(thres.low | thres.high)); % is alpha in a mid-state? if both are 0, it will become 1
                        % we add the sum in case aaachunk was bigger
                        % than a value

                        switch change.direction % to accumulate the datapoints
                            case 0 % downregulation
                                thres.cnt.low = thres.cnt.low + thres.low; % it grows if the participant is in low alpha state
                                thres.not.low = thres.not.low + thres.high + thres.mid - (thres.not.low*thres.low); % it grows if the participant is in high alpha state or mid; if participant becomes low again, the counter-control resets
                            case 1 % upregulation
                                thres.cnt.high = thres.cnt.high + thres.high; % it grows if the participant is in low alpha state
                                thres.not.high = thres.not.high + thres.low + thres.mid - (thres.not.high*thres.high); % it grows if the participant is in low alpha state o mid; if participant becomes high again, the counter-control resets
                        end

                        % counter control overflows
                        switch any(thres.not.low > thres.limit | thres.not.high > thres.limit)
                            case 1
                                % reset all counters even if they hadn't change
                                thres.cnt.low = 0;
                                thres.cnt.high = 0;
                                thres.not.low = 0;
                                thres.not.high = 0;
                        end

                        % or stays too long
                        switch  (GetSecs - startTime) > time.max
                            case 1
                                thres.hold = 0;
                                outlet.em.push_sample(EM.reg_timeout)
                                disp('trial cancelled: time out')
                                storage.reward(tdex) = 0;
                        end

                end % refractory time
            end % while thres.hold for regulation task

















































            % this space above belong to the regulation task
        case 2 % switch knob.task
            %% EPISODE 5: DISCRIMINATION TASK - EVALUATION
            % very basic refractory time
            switch knob.refractory
                case 1
                    WaitSecs(time.refractory);
                    knob.refractory = 0; % so it doesn't jump again
                    outlet.em.push_sample(EM.refractoff);
            end

            outlet.em.push_sample(EM.disc_on)

            [aaachunk, ts] = aaainlet.pull_chunk(); % let's get rid off aaa in the network

            while thres.hold
                % run pseudo buffer
                pause(ring.stability);
                [aaachunk, ts] = aaainlet.pull_chunk();

                % failsafe: in case of temporal disconnections
                if isempty(aaachunk) % retry mechanism
                    %outlet.em.push_sample(EM.issues)
                    %WaitSecs(ring.stability);
                    %disp('>> connection issues <<')
                    [aaachunk, ts] = aaainlet.pull_chunk();
                    if isempty(aaachunk) % carry on mechanism
                        pause(ring.stability);
                        outlet.em.push_sample(EM.issues)
                        disp('>> connection issues (carry on protocol) <<')
                        [aaachunk, ts] = aaainlet.pull_chunk();
                        if isempty(aaachunk) % still empty: close
                            sca;
                            disp('>> connection issues (emergency break) <<')
                            break
                        end
                    end % for carry on mechanism if loop
                end % for retry mechanism if loop


                % PROPER EVALUATION. DISCRIMINATION
                % if any of the cnt overflows: they fullfil
                % the condition
                switch any(thres.cnt.low >= thres.limit | thres.cnt.high >= thres.limit)
                    case 1 % one of the counters meets the limit
                        EM.event = EM.disc_low * (thres.cnt.low >= thres.limit) + EM.disc_high * (thres.cnt.high >= thres.limit);
                        outlet.em.push_sample(EM.event);
                        storage.state(tdex) = key.state.low*(thres.cnt.low >= thres.limit) + key.state.high*(thres.cnt.high >= thres.limit); % 104 - hh ; 108 - low
                        % we decide participants state
                        thres.hold = 0; % breaks the above while loop
                        knob.refractory = 1; % if there's prompt, we reactivate the refractory time for the nex trial

                end

                trial.aaa = [trial.aaa, aaachunk]; % we store the aaa values: discrimination task


                thres.low = sum(aaachunk <= thres.reg.low); % is alpha below the threshold
                thres.high = sum(aaachunk >= thres.reg.high); % is alpha above the threshold
                % we add those sum in case aaachunk was not one value
                thres.mid = not(any(thres.low | thres.high)); % is alpha in a mid-state? if both are 0, it will become 1

                thres.cnt.low = thres.cnt.low + thres.low; % it grows if the participant is in low alpha state
                thres.not.low = thres.not.low + thres.high + thres.mid - (thres.not.low*thres.low); % it grows if the participant is in high alpha state or mid

                thres.cnt.high = thres.cnt.high + thres.high; % it grows if the participant is in low alpha state
                thres.not.high = thres.not.high + thres.low + thres.mid - (thres.not.high*thres.high); % it grows if the participant is in high alpha state o mid

                % counter control overflows
                switch any(thres.not.low > thres.limit | thres.not.high > thres.limit)
                    case 1
                        % reset all counters
                        thres.cnt.low = thres.cnt.low - thres.cnt.low*(thres.not.low > thres.limit);
                        thres.cnt.high = thres.cnt.high - thres.cnt.high*(thres.not.high > thres.limit);
                        thres.not.low = thres.not.low - thres.not.low*(thres.not.low > thres.limit);
                        thres.not.high = thres.not.high - thres.not.high*(thres.not.high > thres.limit);
                end

                % or stays too long
                switch (GetSecs - startTime) > time.max
                    case 1
                        thres.hold = 0;
                        outlet.em.push_sample(EM.disc_timeout)
                        disp('                                        ')
                        disp('trial cancelled: time out')
                        disp('                                        ')
                        storage.state(tdex) = 0; % for the following switch
                end
            end % for the while loop: pseudo ring buffer & current state vs threshold

            %% EPISODE 5: THE PROMPT

            switch storage.state(tdex)
                case {key.state.high, key.state.low}

                    % prompt
                    Screen('TextSize', ptb.window, ptb.font.small);
                    Screen('TextFont', ptb.window, 'Times');
                    DrawFormattedText(ptb.window, ['Were you in a high (↑) or low (↓) alpha state? \n' ...
                        '(please keep your eyes closed)'] ...
                        , 'center', 'center', ptb.white, [], [], [], 1.5);
                    Screen('Flip', ptb.window);

                    sound(audio.y{1}, audio.Fs{1}) % it shouldn't be playblocking
                    outlet.em.push_sample(EM.prompt);
                    disp('prompt!')

                    %% EPISODE 5: SAVE RESPONSE
                    while 1 % key press while loop
                        if knob.debugging
                            WaitSecs(time.short);
                            storage.response(tdex) = key.state.high;
                            break;
                        else
                            [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
                            if keyIsDown
                                if keyCode(KbName(key.high))
                                    outlet.em.push_sample(EM.response)
                                    KbReleaseWait; % Ensures key is fully released before continuing
                                    storage.response(tdex) = key.state.high;
                                    break;  % Exit the loop when the H is pressed
                                elseif keyCode(KbName(key.low))
                                    outlet.em.push_sample(EM.response)
                                    KbReleaseWait; % Ensures key is fully released before continuing
                                    storage.response(tdex) = key.state.low;
                                    break; % Exit the loop when the L is pressed
                                elseif keyCode(KbName(key.escape))
                                    sca;  % Close the Psychtoolbox window and exit the program
                                    return;  % Exit the script
                                else
                                    % I'll save the responses somehow so participant's don't write
                                    % on the script
                                    nullResponse = KbName(keyCode);
                                end
                            end
                        end
                    end


                    %% EPISODE 5: CORRECT-INCORRECT ANSWER
                    % CORRECT
                    if storage.response(tdex) == storage.state(tdex)
                        knob.reward = 1;

                        % to save participant's score
                        switch storage.state(tdex) % in which state is the participant
                            case key.state.high
                                outlet.em.push_sample(EM.th)
                                score.exp.th = score.exp.th+(knob.cond==1);
                                score.cntrl.th = score.cntrl.th + (knob.cond==0);
                                disp('correct! (high alpha state)')

                            case key.state.low
                                outlet.em.push_sample(EM.tl)
                                score.exp.tl = score.exp.tl+(knob.cond==1);
                                score.cntrl.tl = score.cntrl.tl+(knob.cond==0);
                                disp('correct! (low alpha state)')

                        end % switch storage.state

                        % INCORRECT
                    elseif storage.response(tdex) ~= storage.state(tdex)
                        switch storage.state(tdex) % in which state is the participant
                            case key.state.high
                                outlet.em.push_sample(EM.fl)
                                % the person is in a high state but
                                % reports low state. False Low
                                score.exp.fl = score.exp.fl+(knob.cond==1);
                                score.cntrl.fl = score.cntrl.fl+(knob.cond==0);
                                disp('incorrect: false low state')
                            case key.state.low
                                outlet.em.push_sample(EM.fh)
                                % the person is in a low state but
                                % reports a high state. False high.
                                score.exp.fh = score.exp.fh+(knob.cond==1);
                                score.cntrl.fh = score.cntrl.fh+(knob.cond==0);
                                disp('incorrect: false high state')

                        end % switch storage.state

                    end

                    % Set the existing screen to black
                    Screen('FillRect', ptb.window, ptb.black);
                    Screen('Flip', ptb.window);


                otherwise  % time out trials
                    % Set the existing screen to black
                    Screen('FillRect', ptb.window, ptb.black);
                    Screen('Flip', ptb.window);
                    storage.response(tdex) = 0;
                    % nothing
            end % switch storage.state
    end % knob.task

    switch knob.reward % has to be ouside of the loop because if not it will slow down everything
        case 1
            playblocking(audio.sound{2}) % reward
            knob.reward = 0; % so it doesn't jump next time
    end


    % grows threshold counter for direction selction
    switch knob.task
        case 1 % we are in regulation
            change.counter = change.counter+1;
    end


    tdex = tdex + 1;
    knob.event = 1; % so the regulation event gets reactivated

    %% EPISODE X: threshold CALCULATION among trials

    % analysis
    trial.average(end+1) = mean(trial.aaa); % we save the values for the future
    trial.std(end+1) = std(trial.aaa);
    disp(['trial average: ', num2str(trial.average(end)), ' — standard deviation: ', num2str(trial.std(end))])

    % to end the analysis, we save and empty trial.aaa
    task.aaa = [task.aaa, trial.aaa];
    trial.aaa = [];

    % Cumulative dynamic weighted average (sample-based)
    thres.trial(end+1) = tdex;% we save the trail index
    trial.counter = trial.counter+1; % it grows before the calculation
    thres.weight = 1/(trial.counter);

    thres.new(end+1) = thres.weight*task.average(end) + (1-thres.weight)*mean(task.aaa);
    thres.std(end+1) = thres.weight *task.std(end) + (1-thres.weight) * std(task.aaa);

    disp(['(trial counter: ', num2str(trial.counter), '. weight: ', num2str(thres.weight*100), '%. prev task average: ', num2str(task.average(end)), ')'])
    disp('=========================================')

    % define the diferent threshold values:
    % discrimination
    thres.disc.low = thres.new(end) - thres.z(1)*thres.std(end);
    thres.disc.high = thres.new(end) + thres.z(1)*thres.std(end);
    % regulation
    thres.reg.low = thres.new(end) - thres.z(1)*thres.std(end); % the threshold participants
    thres.reg.high = thres.new(end) + thres.z(1)*thres.std(end);

    % sonification calculation
    [sonic.lowest] = abs(thres.new(end) - thres.z(2)*thres.std(end));   % it used to be stream.ctl(1)
    [sonic.highest] = thres.new(end) + thres.z(2)*thres.std(end); % it used to be baseline(sonic.top)


end % main while loop

%% THE END

playblocking(voices.sound{2}); % open your eyes

% Draw text in the middle of the screen in Courier in white
Screen('TextSize', ptb.window, ptb.font.small);
Screen('TextFont', ptb.window, 'Times');
DrawFormattedText(ptb.window, ['Thank you for your participation! \n'...
    'Please wait a moment.'], 'center', 'center', ptb.white, [], [], [], 1.5);
Screen('Flip', ptb.window);
outlet.em.push_sample(EM.end)


% save data
% simplify scores
score.up = score.exp.up + score.cntrl.up;
score.down = score.exp.down + score.cntrl.down;
score.th = score.exp.th + score.cntrl.th;
score.tl = score.exp.tl + score.cntrl.tl;
score.fh = score.exp.fh + score.cntrl.fh;
score.fl = score.exp.fl + score.cntrl.fl;
score.test.reg = test.reg; % let's save this
score.test.disc = test.disc; % let's save this


disp([' '])
disp('========================================')
disp('===============SCOREBOARD===============')
disp('REGULATION TASK:')
disp(['thresholds reached: ', num2str(sum(score.up + score.down)), ' out of ', num2str(score.test.reg*2)])
disp(['downregulation: ', num2str(score.down), ' trials'])
disp(['upregulation: ',  num2str(score.up), ' trials'])
disp(['success rate: ', num2str(round((sum(score.up + score.down)/(score.test.reg*2)*100), 2)), '%'])
disp('========================================')
disp('DISCRIMINATION TASK:')
disp(['total amount of correct answer: ', num2str(sum(score.th+score.tl))])
disp(['total amount of incorrect answer: ', num2str(sum(score.fh+score.fl))])
score.sensitivity = score.th / (score.th + score.fl); % they were i high state
score.specificity = score.tl / (score.tl + score.fh); % they were in low state
score.balanced_accuracy = (score.sensitivity + score.specificity)/2;
disp(['balanced accuracy: ', num2str(round(score.balanced_accuracy*100,2)), '%'])
disp('========================================')


paths.save = [paths.main, '\data\recordings\score'];
save(paths.save, 'score')
paths.save = [paths.main, '\data\recordings\trial'];
save(paths.save, 'trial')
paths.save = [paths.main, '\data\recordings\task'];
save(paths.save, 'task')
paths.save = [paths.main, '\data\recordings\thres'];
save(paths.save, 'thres')
paths.save = [paths.main, '\data\recordings\storage'];
save(paths.save, 'storage')

disp(['saving variables in: ', paths.main])


disp('========================================')
disp('1. stop streaming')
disp('2. check if ring buffer stopped and if the chunksize is saved')
disp('3. stop labrecorder')
disp('4. go')



