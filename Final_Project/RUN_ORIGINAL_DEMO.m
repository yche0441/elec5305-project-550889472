% ELEC5305 final project: open this file in MATLAB and press Run.
% Runs one short, predetermined example; saved full-study results are preserved.
releaseFolder = fileparts(mfilename('fullpath'));
addpath(releaseFolder);
check_environment();
addpath(fullfile(releaseFolder,'Final_Project_Video_Prep'));
video_demo();
fprintf('\nNext: enter play_demo_audio for the optional four-clip demonstration.\n');

