%% ELEC5305 Project Feedback Two: first MATLAB experiment
% Yulong Chen, SID 550889472
% Run this file from the extracted Project_Feedback_Two folder.
% Outputs are actual MATLAB results only after this script completes.

projectDir = fileparts(mfilename('fullpath'));
if isempty(projectDir), projectDir = pwd; end
addpath(projectDir);
cfg = project_settings();
audioDir = fullfile(projectDir,'audio');
resultDir = fullfile(projectDir,'results_matlab');
figureDir = fullfile(resultDir,'figures');
listeningDir = fullfile(resultDir,'listening');
if ~isfolder(resultDir), mkdir(resultDir); end
if ~isfolder(figureDir), mkdir(figureDir); end
if ~isfolder(listeningDir), mkdir(listeningDir); end

%% Run all four cases, with identical settings for the two algorithms
rows = cell(12,12); row = 0; datasetRows = cell(4,8); caseIndex = 0;
methods = {'original','fixed','vad'};
displayNames = {'Unprocessed','Fixed Wiener','VAD-guided Wiener'};
for u = 1:numel(cfg.utterances)
    utterance = cfg.utterances{u};
    [ref,fsRef] = audioread(fullfile(audioDir,[utterance 'r1_16.wav']));
    for c = 1:numel(cfg.environments)
        environment = cfg.environments{c}; caseIndex = caseIndex+1;
        [x,fs] = audioread(fullfile(audioDir,[utterance '_' environment 'r1_16.wav']));
        assert(fs==cfg.fs && fsRef==fs && size(x,2)==1 && size(ref,2)==1, ...
            'Expected mono 16 kHz recordings.');
        originalLengths = [numel(x),numel(ref)];
        n = min(originalLengths);
        x = x(1:n); r = ref(1:n); % Trim only unmatched tails; no time shifts
        noiseInterval = cfg.noiseIntervals_s(u,:);
        [identity,identityInfo] = wiener_enhance(x,fs,noiseInterval,'identity',cfg);
        reconstructionError = norm(identity-x)/max(norm(x),eps);
        assert(reconstructionError<1e-10, 'STFT reconstruction check failed.');
        tic; [fixed,df] = wiener_enhance(x,fs,noiseInterval,'fixed',cfg); fixedTime=toc;
        tic; [adaptive,dv] = wiener_enhance(x,fs,noiseInterval,'vad',cfg); vadTime=toc;
        y = {x,fixed,adaptive}; times = [0,fixedTime,vadTime];
        fractions = [NaN,0,dv.updateFraction];
        inputMetric = evaluate_recording(r,x,x,fs,noiseInterval,cfg);
        for k = 1:3
            m = evaluate_recording(r,x,y{k},fs,noiseInterval,cfg);
            row = row+1;
            rows(row,:) = {utterance,environment,methods{k},m.referenceSNR_dB, ...
                m.referenceSNR_dB-inputMetric.referenceSNR_dB, ...
                m.nonSpeechAttenuation_dB,m.speechLevelChange_dB,times(k), ...
                fractions(k),m.noiseEvaluation_s,m.speechEvaluation_s,reconstructionError};
        end
        datasetRows(caseIndex,:) = {utterance,environment,originalLengths(1), ...
            originalLengths(2),n,fs,noiseInterval(1),noiseInterval(2)};

        % One common listening gain across all conditions; metrics above use
        % original scale. No per-output loudness normalisation or new mixing.
        playbackGain = min(1,0.99/max(abs([x;r;fixed;adaptive])));
        caseName = [utterance '_' environment];
        for k = 1:3
            audiowrite(fullfile(listeningDir,[caseName '_' methods{k} '.wav']), ...
                playbackGain*y{k},fs);
        end

        % Comparable STFT levels in all three panels; no separate colour limits.
        fig = figure('Color','w','Name',caseName,'Position',[80 80 1000 650]);
        tiledlayout(3,1,'TileSpacing','compact');
        L=cfg.windowLength; H=cfg.hopLength; K=cfg.nfft;
        w=0.54-0.46*cos(2*pi*(0:L-1)'/(L-1));
        starts=0:H:(n-L); indices=(1:L)'+starts;
        spectra=cell(3,1);
        for k=1:3
            S=fft(y{k}(indices).*w,K,1);
            spectra{k}=20*log10(abs(S(1:K/2+1,:))+1e-12);
        end
        maximum=max(spectra{1}(:));
        for k=1:3
            nexttile; imagesc((starts+L/2)/fs,(0:K/2)*fs/K,spectra{k});
            axis xy; ylim([0 8000]); caxis([maximum-70 maximum]); colorbar;
            ylabel('Frequency (Hz)'); title(displayNames{k});
        end
        xlabel('Time (s)'); sgtitle([caseName ' - same STFT scale'],'Interpreter','none');
        exportgraphics(fig,fullfile(figureDir,[caseName '_spectrogram.png']),'Resolution',160);

        fig=figure('Color','w','Name',[caseName ' VAD'],'Position',[80 80 1000 620]);
        tiledlayout(3,1,'TileSpacing','compact');
        nexttile; plot((0:n-1)/fs,x); grid on; ylabel('Amplitude');
        xline(noiseInterval(1),'r--'); xline(noiseInterval(2),'r--');
        title('Input; red lines mark the offline calibration interval');
        nexttile; plot(dv.time_s,dv.energyRatio_dB); hold on;
        yline(cfg.vadThreshold_dB,'r--'); grid on; ylabel('Energy ratio (dB)');
        title('Energy relative to the current noise estimate');
        nexttile; stairs(dv.time_s,double(dv.noiseUpdated),'LineWidth',1.2);
        grid on; ylabel('Noise update'); xlabel('Time (s)'); ylim([-0.1 1.1]);
        title('1 = frame used for noise adaptation');
        exportgraphics(fig,fullfile(figureDir,[caseName '_vad.png']),'Resolution',160);
        save(fullfile(resultDir,[caseName '_diagnostics.mat']),'df','dv','cfg', ...
            'noiseInterval','reconstructionError','playbackGain');
        fprintf('Completed %s: fixed %.2f dB, VAD %.2f dB reference SNR.\n', ...
            caseName,rows{row-1,4},rows{row,4});
    end
end

%% Save tables and MATLAB execution evidence
metrics=cell2table(rows,'VariableNames',{'Utterance','Environment','Method', ...
    'ReferenceSNR_dB','ReferenceSNRGain_dB','NonSpeechAttenuation_dB', ...
    'SpeechLevelChange_dB','Runtime_s','NoiseUpdateFraction', ...
    'NoiseEvaluation_s','SpeechEvaluation_s','IdentityRelativeError'});
dataset=cell2table(datasetRows,'VariableNames',{'Utterance','Environment', ...
    'OriginalNoisySamples','OriginalReferenceSamples','EvaluatedSamples','Fs_Hz', ...
    'CalibrationStart_s','CalibrationEnd_s'});
writetable(metrics,fullfile(resultDir,'metrics.csv'));
writetable(dataset,fullfile(resultDir,'dataset_summary.csv'));
save(fullfile(resultDir,'project_results.mat'),'metrics','dataset','cfg');
fid=fopen(fullfile(resultDir,'RUN_COMPLETED.txt'),'w');
assert(fid~=-1,'Cannot save run status.');
fprintf(fid,'MATLAB version: %s\nCompleted: %s\nCases: 4\nRows: 12\n',version,datestr(now,31));
fprintf(fid,'STFT identity reconstruction checks passed.\n'); fclose(fid);
disp(metrics);
zip(fullfile(projectDir,'Project_Feedback_Two_MATLAB_Results.zip'),{'results_matlab'},projectDir);
fprintf('\nFinished. Send Project_Feedback_Two_MATLAB_Results.zip for result review.\n');
