% Optional full reproduction. Supplied numerical evidence is never overwritten.
% Open START_HERE.m for the much shorter video demonstration.
releaseFolder = fileparts(mfilename('fullpath'));
addpath(releaseFolder);
check_environment();
runName = ['parameter_study_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))];
outputRoot = fullfile(releaseFolder,'reproduction_runs',runName);
assert(~isfolder(outputRoot),'This run folder already exists. Try again.');
mkdir(outputRoot);
copyfile(fullfile(releaseFolder,'Final_Project_Study'),fullfile(outputRoot,'Final_Project_Study'));
rerunFolder = fullfile(outputRoot,'Final_Project_Study');
addpath(rerunFolder);
fprintf('Full parameter study. New results: %s\n',rerunFolder);
diary(fullfile(outputRoot,'MATLAB_REPRODUCTION.log'));
previousFolder = pwd;
try
    % MATLAB searches its current folder before folders added to the path.
    cd(rerunFolder);
    assert(strcmp(which('run_final_study'),fullfile(rerunFolder,'run_final_study.m')), ...
        'The study runner must resolve to the new reproduction copy.');
    run_final_study();
    diary off;
    cd(previousFolder);
catch problem
    diary off;
    cd(previousFolder);
    rethrow(problem);
end
fprintf('Complete. Supplied reference results are unchanged.\nNew results: %s\n',rerunFolder);
