function run_noizeus_experiment()
% Open this file and press Run. It takes no input arguments.
% ELEC5305 Project Feedback Two / semester Project, Yulong Chen 550889472.
% Result collection fix: 2026-09-13-r1 (first-record struct initialization).
root = fileparts(mfilename('fullpath'));
addpath(root);
cfg = experiment_config();
assert(~cfg.legacyReproduction, 'Legacy mode cannot be used for the main experiment.');
tag = char(datetime('now','Format','yyyyMMdd_HHmmss'));
runFolder = fullfile(root,'results',['run_' tag]);
assert(~isfolder(runFolder), 'Run folder already exists. Run again in a moment.');
mkdir(runFolder);
mkdir(fullfile(runFolder,'figures'));
mkdir(fullfile(runFolder,'listening'));
diary(fullfile(runFolder,'run_log.txt'));
diaryCleanup = onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('ELEC5305 NOIZEUS controlled TSNR experiment: %s\n', cfg.protocolVersion);
fprintf('MATLAB: %s\n', version);
fprintf('48 input cases; 16 development and 32 held-out evaluation cases.\n');
fprintf('Evaluation excludes the first %.2f s in every signal.\n',cfg.initialSeconds);
verification = verify_core(root,cfg);
verify_record_collection();
metadata = struct('MATLABVersion',version,'Toolboxes',ver,'Started',tag, ...
    'STOIPath',which('stoi'),'Protocol',cfg.protocolVersion);
metadata.ImplementationRevision = '2026-09-13-r1';
stoiAvailable = ~isempty(metadata.STOIPath);
stoiIssue = '';
if ~stoiAvailable
    stoiIssue = 'MATLAB stoi was not found. Audio Toolbox with stoi is required for STOI.';
    fprintf('STOI unavailable: SNR and diagnostics will still run.\n');
end
metricRows = struct([]);
caseRows = struct([]);
pairedRows = struct([]);
signals = struct([]);
methods = {'unprocessed','fixed','vad'};
caseNumber = 0;
totalCases = numel(cfg.utterances)*numel(cfg.noises)*numel(cfg.nominalSNRs);

for u = 1:numel(cfg.utterances)
    utterance = cfg.utterances{u};
    [clean,fs] = audioread(fullfile(root,'data','clean',[utterance '.wav']));
    assert(fs==cfg.fs && size(clean,2)==1 && all(isfinite(clean)));
    if ismember(utterance,cfg.development)
        split = 'development';
    else
        split = 'evaluation';
    end
    for n = 1:numel(cfg.noises)
        noise = cfg.noises{n};
        for s = 1:numel(cfg.nominalSNRs)
            nominal = cfg.nominalSNRs(s);
            file = sprintf('%s_%s_sn%d.wav',utterance,noise,nominal);
            [noisy,noisyFs] = audioread(fullfile(root,'data',noise, ...
                sprintf('%ddB',nominal),file));
            assert(noisyFs==fs && isequal(size(clean),size(noisy)), ...
                'Clean/noisy dimensions or sample rates differ: %s',file);
            assert(all(isfinite(noisy)), 'Nonfinite input.');
            caseNumber = caseNumber+1;
            caseID = sprintf('%s_%s_%ddB',utterance,noise,nominal);
            fprintf('[%02d/%02d] %s (%s)\n',caseNumber,totalCases,caseID,split);
            t = tic;
            [fixed,fixedTrace] = tsnr_enhance(noisy,fs,cfg,'fixed');
            fixedTime = toc(t);
            t = tic;
            [vad,vadTrace] = tsnr_enhance(noisy,fs,cfg,'vad');
            vadTime = toc(t);
            assert(isequal(fixedTrace.initialPSD,vadTrace.initialPSD));
            assert(~any(fixedTrace.noiseUpdated));
            [caseInfo,frame] = pair_diagnostics(clean,noisy,vadTrace,cfg);
            caseInfo.CaseID = caseID;
            caseInfo.Utterance = utterance;
            caseInfo.Split = split;
            caseInfo.Noise = noise;
            caseInfo.NominalSNR_dB = nominal;
            caseInfo.Fs_Hz = fs;
            caseInfo.Samples = numel(clean);
            caseInfo.EvaluationStartSample = vadTrace.initialSamples+1;
            caseRows = append_record(caseRows,caseInfo);
            ix = vadTrace.initialSamples+1:numel(clean);
            inputSNR = measure_snr(clean(ix),noisy(ix));
            outputs = {noisy,fixed,vad};
            traces = {[],fixedTrace,vadTrace};
            runTimes = [NaN,fixedTime,vadTime];
            caseSNR = NaN(1,3);
            caseSTOI = NaN(1,3);
            for m = 1:3
                output = outputs{m};
                caseSNR(m) = measure_snr(clean(ix),output(ix));
                if stoiAvailable
                    try
                        score = stoi(output(ix),clean(ix),fs);
                        assert(isscalar(score) && isfinite(score) && ...
                            score>=-1-1e-6 && score<=1+1e-6, 'Invalid STOI value.');
                        caseSTOI(m) = score;
                    catch problem
                        stoiAvailable = false;
                        stoiIssue = sprintf('%s: %s',problem.identifier,problem.message);
                        fprintf('STOI could not continue: %s\n',stoiIssue);
                    end
                end
                row.CaseID = caseID;
                row.Utterance = utterance;
                row.Split = split;
                row.Noise = noise;
                row.NominalSNR_dB = nominal;
                row.Method = methods{m};
                row.InputSNR_dB = inputSNR;
                row.OutputSNR_dB = caseSNR(m);
                row.SNRImprovement_dB = caseSNR(m)-inputSNR;
                row.STOI = caseSTOI(m);
                row.Runtime_s = runTimes(m);
                row.NoiseVariation_dB = caseInfo.NoiseVariation_dB;
                row.PeakAbsolute = max(abs(output));
                row.ProxySpeechMissFraction = NaN;
                row.ProxyNonSpeechFalseAlarmFraction = NaN;
                row.UpdateOnSpeechProxyFraction = NaN;
                row.NoiseUpdateFraction = NaN;
                if m>1
                    trace = traces{m};
                    row.ProxySpeechMissFraction = fraction(~trace.speechDecision,frame.speechProxy);
                    row.ProxyNonSpeechFalseAlarmFraction = fraction(trace.speechDecision,frame.nonSpeechProxy);
                    row.UpdateOnSpeechProxyFraction = fraction(trace.noiseUpdated,frame.speechProxy);
                    row.NoiseUpdateFraction = fraction(trace.noiseUpdated,trace.valid);
                end
                metricRows = append_record(metricRows,row);
            end
            pair.CaseID = caseID;
            pair.Split = split;
            pair.Noise = noise;
            pair.NominalSNR_dB = nominal;
            pair.NoiseVariation_dB = caseInfo.NoiseVariation_dB;
            pair.VADminusFixedSNR_dB = caseSNR(3)-caseSNR(2);
            pair.VADminusFixedSTOI = caseSTOI(3)-caseSTOI(2);
            pairedRows = append_record(pairedRows,pair);
            entry.CaseID = caseID;
            entry.fs = fs;
            entry.clean = clean;
            entry.noisy = noisy;
            entry.fixed = fixed;
            entry.vad = vad;
            entry.fixedTrace = fixedTrace;
            entry.vadTrace = vadTrace;
            signals = append_record(signals,entry);
            if strcmp(utterance,cfg.figureUtterance) && nominal==cfg.figureSNR
                save_case_outputs(runFolder,caseID,entry,frame,cfg);
            end
        end
    end
end

metrics = struct2table(metricRows);
cases = struct2table(caseRows);
paired = struct2table(pairedRows);
summary = condition_summary(metrics);
assert(height(metrics)==144 && height(cases)==48 && height(paired)==48);
writetable(metrics,fullfile(runFolder,'metrics.csv'));
writetable(cases,fullfile(runFolder,'dataset_diagnostics.csv'));
writetable(paired,fullfile(runFolder,'paired_comparisons.csv'));
writetable(summary,fullfile(runFolder,'condition_summary.csv'));
metadata.Completed = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
metadata.STOIIssue = stoiIssue;
metadata.STOIFiniteRows = sum(isfinite(metrics.STOI));
metadata.FullMetricsComplete = all(isfinite(metrics.STOI));
save(fullfile(runFolder,'experiment_results.mat'),'cfg','metadata', ...
    'verification','metrics','cases','paired','summary','signals','-v7');
copyfile(fullfile(root,'experiment_config.m'),runFolder);
copyfile(fullfile(root,'PROTOCOL.md'),runFolder);
copyfile(fullfile(root,'source_information','DATA_AUDIT.json'),runFolder);
copyfile(fullfile(root,'METRIC_GUIDE.md'),runFolder);
save_overview(runFolder,paired);
fid = fopen(fullfile(runFolder,'RUN_STATUS.txt'),'w');
assert(fid~=-1,'Cannot save status.');
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid,'Protocol: %s\nMATLAB: %s\n',cfg.protocolVersion,version);
fprintf(fid,'Input cases: 48\nMetric rows: 144\nVerification gates: PASSED\n');
fprintf(fid,'Finite STOI rows: %d/144\n',metadata.STOIFiniteRows);
if metadata.FullMetricsComplete
    fprintf(fid,'Status: COMPLETE (SNR and STOI measured)\n');
else
    fprintf(fid,'Status: PARTIAL -- STOI needs completion\nReason: %s\n',stoiIssue);
end
fprintf(fid,'Scientific interpretation and listening review are still required.\n');
clear fileCleanup
fprintf('\nCompleted. STOI rows available: %d/144.\n',metadata.STOIFiniteRows);
disp(summary);
diary('off');
zipPath = fullfile(root,['NOIZEUS_Results_' tag '.zip']);
zip(zipPath,{fullfile('results',['run_' tag])},root);
fprintf('\nDownload this ZIP and send it for review:\n%s\n',zipPath);
end

function records = append_record(records,record)
% A fieldless struct([]) cannot receive a populated struct by index.
% Let the first record establish the fields before appending later records.
if isempty(records)
    records = record;
else
    records(end+1) = record;
end
end

function verify_record_collection()
% Regression gate for first insertion, later insertion and table conversion.
first = struct('CaseID','first','Score',1,'Available',true);
second = struct('CaseID','second','Score',NaN,'Available',false);
records = append_record(struct([]),first);
records = append_record(records,second);
assert(numel(records)==2 && isequal(records(1),first) && ...
    isequaln(records(2),second), 'Result collection regression check failed.');
resultTable = struct2table(records);
assert(height(resultTable)==2 && resultTable.Score(1)==1 && isnan(resultTable.Score(2)) && ...
    isequal(resultTable.Available,[true;false]), 'Result table conversion failed.');
fprintf('Result collection check passed (2026-09-13-r1).\n');
end

function value = fraction(event,eligible)
if any(eligible)
    value = sum(event & eligible)/sum(eligible);
else
    value = NaN;
end
end

function summary = condition_summary(metrics)
rows = struct([]);
splits = {'development','evaluation'};
noises = {'car','street'};
methods = {'unprocessed','fixed','vad'};
for a = 1:2
    for b = 1:2
        for nominal = [0 5 10 15]
            for c = 1:3
                keep = strcmp(metrics.Split,splits{a}) & ...
                    strcmp(metrics.Noise,noises{b}) & metrics.NominalSNR_dB==nominal & ...
                    strcmp(metrics.Method,methods{c});
                part = metrics(keep,:);
                row.Split = splits{a};
                row.Noise = noises{b};
                row.NominalSNR_dB = nominal;
                row.Method = methods{c};
                row.N = height(part);
                row.MeanInputSNR_dB = mean(part.InputSNR_dB);
                row.MeanOutputSNR_dB = mean(part.OutputSNR_dB);
                row.MeanSNRImprovement_dB = mean(part.SNRImprovement_dB);
                row.StdSNRImprovement_dB = std(part.SNRImprovement_dB);
                row.FiniteSTOIRows = sum(isfinite(part.STOI));
                row.MeanSTOI = mean(part.STOI,'omitnan');
                rows = append_record(rows,row);
            end
        end
    end
end
summary = struct2table(rows);
end

function save_overview(folder,paired)
f = figure('Visible','off','Color','w','Position',[100 100 1100 450]);
cleanup = onCleanup(@() close(f)); %#ok<NASGU>
select = strcmp(paired.Split,'evaluation');
names = {'car','street'};
colors = [0.05 0.35 0.7; 0.8 0.3 0.1];
for panel = 1:2
    subplot(1,2,panel);
    hold on;
    handles = gobjects(2,1);
    for n = 1:2
        keep = select & strcmp(paired.Noise,names{n});
        if panel==1
            y = paired.VADminusFixedSNR_dB(keep);
        else
            y = paired.VADminusFixedSTOI(keep);
        end
        handles(n) = scatter(paired.NoiseVariation_dB(keep),y,40,colors(n,:),'filled');
    end
    yline(0,'k:'); grid on;
    xlabel('Residual-noise frame power P90-P10 (dB)');
    if panel==1
        ylabel('VAD minus fixed reference SNR (dB)');
    else
        ylabel('VAD minus fixed STOI');
    end
    title('Held-out cases; positive favours VAD');
    legend(handles,names,'Location','best');
end
exportgraphics(f,fullfile(folder,'figures','variation_and_paired_effect.png'),'Resolution',150);
end
