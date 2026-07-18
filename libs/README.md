libs/
* violin_half.m: essential for Analysis. It creates the violin plots. It is a modified version of violin.m by Hoffmann (2015) for MATLAB 2025.
* requirements.txt


Dependencies required to run the Experiment and Analysis code:
* EEGLAB 2025.0.0: essential for Experiment and Analysis. Requires the xdfimport plugin (v1.2).
* liblsl-Matlab: essential for Experiment and Analysis
* Psychtoolbox 3.0.19: essential for Experiment. Must be stored at the local disk (C:).
* GStreamer: essential for Experiment, as a dependency of Psychtoolbox. Requires installation.
* Purr Data: essential for Experiment. Generates the red noise. Requires installation.
* send_osc.m & netutil-1.0.0.jar: essential for Experiment. Send sonification values (osc messages) from the Experiment script to the Purr Data patch.
* standard_1020.elc: essential for Analysis. Contains the electrode location of the MBT cap, available via EEGLAB.
