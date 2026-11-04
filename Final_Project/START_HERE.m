% ELEC5305 final project: open this script in MATLAB and press Run.
% Fresh soft-tracker follow-up example; the full frozen study is not rerun.
releaseFolder = fileparts(mfilename('fullpath'));
addpath(fullfile(releaseFolder,'spp_recovery'),'-begin');
run_recovery_demo();
fprintf('\nFresh SNR and tracking checks completed. Displayed STOI is a saved Python score.\n');
fprintf('Same-gain examples are in spp_recovery/demo.\n');
fprintf('RUN_ORIGINAL_DEMO shows the earlier example from the recorded presentation.\n');
fprintf('RUN_RECOVERY_STUDY creates a separate full-reproduction copy.\n');
