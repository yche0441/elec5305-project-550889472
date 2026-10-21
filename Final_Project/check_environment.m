function details = check_environment()
% CHECK_ENVIRONMENT Check the local release and locate a working Python STOI.
% Does not install software or change settings outside this MATLAB session.
root = fileparts(mfilename('fullpath'));
required = {'Final_Project_Study/experiment_config.m', ...
    'Final_Project_Study/tsnr_enhance.m', ...
    'Final_Project_Study/stoi_bridge.py', ...
    'Final_Project_Study/data/clean/sp02.wav', ...
    'Final_Project_Study/new_test_metrics.csv', ...
    'Final_Project_Video_Prep/video_demo.m'};
for k = 1:numel(required)
    assert(isfile(fullfile(root,required{k})), ...
        'The release is incomplete. Extract the complete ZIP, including its subfolders. Missing: %s', required{k});
end
selected = getenv('ELEC5305_PYTHON');
% Optional machine-local setup is excluded from the distributed ZIP.
localConfig = fullfile(root,'LOCAL_RUNTIME.json');
if isfile(localConfig)
    local = jsondecode(fileread(localConfig));
    if isfield(local,'python') && isfile(local.python) && ...
            (isempty(selected) || strcmp(selected,local.python))
        selected = local.python;
        if isfield(local,'pythonpath') && isfolder(local.pythonpath)
            oldPath = getenv('PYTHONPATH');
            if isempty(oldPath)
                setenv('PYTHONPATH',local.pythonpath);
            else
                setenv('PYTHONPATH',[local.pythonpath pathsep oldPath]);
            end
        end
    end
end
if isempty(selected)
    candidates = {fullfile(getenv('HOME'),'.cache','codex-runtimes', ...
        'codex-primary-runtime','dependencies','python','bin','python3'), 'python3', 'python'};
else
    candidates = {selected};
end
code = ['import json,sys,numpy,scipy,pystoi; ' ...
    'print(json.dumps(dict(python=sys.version.split()[0],numpy=numpy.__version__,' ...
    'scipy=scipy.__version__,pystoi=pystoi.__version__)))'];
details = [];
lastError = '';
for k = 1:numel(candidates)
    executable = candidates{k};
    if any(executable == '"') || any(executable == newline)
        error('ELEC5305_PYTHON must be an executable path, without quotes or arguments.');
    end
    [status, result] = system(sprintf('"%s" -c "%s"',executable,code));
    if status == 0
        try
            details = jsondecode(strtrim(result));
        catch
            lastError = result;
            continue;
        end
        assert(strcmp(details.pystoi,'0.4.1'), ...
            'This release requires pystoi 0.4.1. Use requirements.txt in this folder.');
        setenv('ELEC5305_PYTHON',executable);
        details.executable = executable;
        details.MATLAB = version;
        fprintf('Environment ready: MATLAB %s; Python %s; PySTOI %s.\n', ...
            details.MATLAB,details.python,details.pystoi);
        fprintf('NumPy %s; SciPy %s. Full reproducibility versions are in requirements.txt.\n', ...
            details.numpy,details.scipy);
        return;
    end
    lastError = result;
end
error(['Python with numpy, scipy and pystoi 0.4.1 was not found. ' ...
    'Install requirements.txt, then setenv(''ELEC5305_PYTHON'',''/full/path/to/python''). ' ...
    'No files were overwritten. Details: %s'],lastError);
end

