% Reproduce the soft-tracker study in a fresh copy; preserve supplied results.
releaseFolder = fileparts(mfilename('fullpath'));
sourceFolder = fullfile(releaseFolder,'spp_recovery');
assert(isfolder(sourceFolder),'Extract the complete project folders first.');
stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
reproductionFolder = fullfile(releaseFolder,'reproduction_runs',['spp_recovery_' stamp]);
assert(~isfolder(reproductionFolder),'Choose a fresh output directory.');
mkdir(reproductionFolder);
items = dir(sourceFolder);
for k = 1:numel(items)
    name = items(k).name;
    % Generated waveform chunks are recomputed; do not copy 250 MB of them.
    if any(strcmp(name,{'.','..','signals','__pycache__'})), continue; end
    copyfile(fullfile(sourceFolder,name),fullfile(reproductionFolder,name));
end
previousPath = path;
restorePath = onCleanup(@() path(previousPath));
addpath(reproductionFolder,'-begin');
verify_spp_synthetic();
run_recovery_study();
fprintf('\nMATLAB results are in:\n%s\n',reproductionFolder);
fprintf('Next score the unquantized outputs using Python with requirements.txt installed:\n');
fprintf('python3 "%s"\n',fullfile(reproductionFolder,'score_recovery.py'));
fprintf('The source release and its saved reference results were preserved.\n');
