\code\experiment

This folder contains the MATLAB scripts used to run the experiment. Here you can find a bref description of each script; see Experiment_Protocol.pdf (in documents/) for the full step-by-step procedure for running a session.

Main scripts:
- new_streamer.m: It streams a raw EEG file (.xdf format). You can choose the specific file (line 19), sampling rate (line 14) and stream name (line 54), among other features.
- ring_buffer.m: online analysis script. It requires a running EEG stream, a working EEGLAB, and the Signal Processing Toolbox. You can choose the specific channel (line 32), the EEG stream name (line 39), various ring buffer atributtes (line 43) and filter properties (line 56). Knob.debugging can be used to visualize the process at every ring buffer update, but this will heavily slow down the execution.
- ptb_demo.m: Experiment control script. Controls the full experiment, including instructions, task flows, sonification production, participant input and behavioral data logging. It requires the online analysis script to be running and producing AAA values; it creates the stream with the event markers (EM) and sonification values (SONIC). It requires Psychtoolbox (and GStreamer) installed and running. If you modify anything of the online analysis, you should adapt this code (such as line 33). There are many variables that can be edited, such as (line 39) the duration intertrial, time above/below the threshold, or break duration. 
- red_noise.pd: allows you to generate the red noise and receive OSC messages from "ptb_demo.m". It requires Purr Data installed. To activate, you shall click on "Medien -> 
Audion An". You can test it with "Medien -> Teste Audio und Midi -> OUTPUT MONITOR" 


Paths need to be edited to your own local folders:
- paths.main: the main project folder
- paths.eeglab: location of your EEGLAB installation; comment out if EEGLAB loads automatically on startup.
- paths.lib: location of dependency libraries; add additional paths if dependencies are stored elsewhere.
