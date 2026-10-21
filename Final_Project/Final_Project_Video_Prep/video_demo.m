function video_demo()
% VIDEO_DEMO Reproduce one predetermined case; do not rescore or select test cases.
% Enhancement helper: LIU Ming / Pascal Scalart adaptation; see Study/license.txt.
root=fileparts(mfilename('fullpath'));
study=fullfile(fileparts(root),'Final_Project_Study');
out=fullfile(root,'demo_generated');if ~isfolder(out),mkdir(out);end
addpath(study);
cfg=experiment_config();selected=cfg;selected.vadThreshold_dB=1;selected.hangoverFrames=10;
[clean,fs]=audioread(fullfile(study,'data','clean','sp02.wav'));
[noisy,fs2]=audioread(fullfile(study,'data','street','5dB','sp02_street_sn5.wav'));
assert(fs==8000 && fs2==fs && isequal(size(clean),size(noisy)));
[fixed,~]=tsnr_enhance(noisy,fs,cfg,'fixed');
[original,~]=tsnr_enhance(noisy,fs,cfg,'vad');
[revised,~]=tsnr_enhance(noisy,fs,selected,'vad');
waveforms=[noisy fixed original revised];
methods={'unprocessed','fixed','vad_original','vad_selected'};
labels={'Noisy input','Fixed noise PSD','Original VAD','Selected VAD'};
files={'01_noisy_input.wav','02_fixed_noise_psd.wav','03_original_vad.wav','04_selected_vad.wav'};
metrics=readtable(fullfile(study,'new_test_metrics.csv'),'TextType','string');
caseRows=metrics.Utterance=="sp02" & metrics.Noise=="street" & metrics.NominalSNR_dB==5;
snrValues=zeros(4,1);stoiValues=zeros(4,1);allSNR=zeros(4,1);allSTOI=zeros(4,1);
ix=801:numel(clean);reference=clean(ix);
py=getenv('ELEC5305_PYTHON');if isempty(py),py='python3';end
for k=1:4
 processed=waveforms(ix,k);
 snrValues(k)=measure_snr(reference,processed);
 matInput=fullfile(out,'metric_input.mat');save(matInput,'reference','processed','fs','-v7');
 [status,result]=system(sprintf('"%s" "%s" "%s"',py,fullfile(study,'stoi_bridge.py'),matInput));
 assert(status==0,'PySTOI requires Python packages numpy scipy pystoi. %s',result);
 stoiValues(k)=str2double(strtrim(result));assert(isfinite(stoiValues(k)));
 expected=metrics(caseRows & metrics.Method==string(methods{k}),:);
 assert(height(expected)==1 && abs(snrValues(k)-expected.SNR_dB)<1e-8 && abs(stoiValues(k)-expected.STOI)<1e-8,'Fresh case metrics must match saved study.');
 stored=metrics(metrics.Method==string(methods{k}),:);assert(height(stored)==48);
 allSNR(k)=mean(stored.SNR_dB);allSTOI(k)=mean(stored.STOI);
end
% One shared attenuation only; no separate loudness normalization of methods.
peak=max(abs(waveforms),[],'all');playbackGain=min(1,0.95/max(peak,eps));
for k=1:4,audiowrite(fullfile(out,files{k}),waveforms(:,k)*playbackGain,fs,'BitsPerSample',24);end
save(fullfile(out,'demo_results.mat'),'waveforms','clean','fs','labels','methods','snrValues','stoiValues','allSNR','allSTOI','playbackGain');
T=table(string(labels'),snrValues,stoiValues,allSNR,allSTOI,'VariableNames',{'Method','FreshCaseSNR_dB','FreshCasePySTOI','Stored48CaseMeanSNR_dB','Stored48CaseMeanPySTOI'});
writetable(T,fullfile(out,'demo_metrics.csv'));disp(T);
fig=figure('Name','ELEC5305 - live example and stored study results','Color','w','Position',[80 80 1200 760]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
nexttile;bar(snrValues,'FaceColor',[0.20 0.45 0.67]);set(gca,'XTick',1:4,'XTickLabel',labels);xtickangle(15);ylabel('SNR (dB)');title('Fresh run: sp02 / street / nominal 5 dB');grid on;label_bars(snrValues,'%.2f',[0 ceil(max(snrValues)*1.20)]);
nexttile;bar(stoiValues,'FaceColor',[0.20 0.45 0.67]);set(gca,'XTick',1:4,'XTickLabel',labels);xtickangle(15);ylabel('Standard PySTOI');ylim([0 1]);title('Fresh run: objective intelligibility estimate');grid on;label_bars(stoiValues,'%.4f',[0 1]);
nexttile;bar(allSNR,'FaceColor',[0.42 0.57 0.34]);set(gca,'XTick',1:4,'XTickLabel',labels);xtickangle(15);ylabel('Mean SNR (dB)');title('Stored study: 48 test conditions');grid on;label_bars(allSNR,'%.2f',[0 ceil(max(allSNR)*1.20)]);
nexttile;bar(allSTOI,'FaceColor',[0.42 0.57 0.34]);set(gca,'XTick',1:4,'XTickLabel',labels);xtickangle(15);ylabel('Mean standard PySTOI');ylim([0 1]);title('Stored study: 48 test conditions');grid on;label_bars(allSTOI,'%.4f',[0 1]);
sgtitle({'VAD-guided Wiener speech enhancement','Objective measurements only; no subjective listening evaluation'},'FontWeight','bold');
exportgraphics(fig,fullfile(out,'Demo_Results.png'),'Resolution',160);
fig2=figure('Name','ELEC5305 - waveform example','Color','w','Position',[120 100 1100 780]);
tiledlayout(4,1,'Padding','compact','TileSpacing','compact');t=(0:size(waveforms,1)-1)/fs;
for k=1:4
 nexttile;plot(t,waveforms(:,k),'Color',[0.2 0.4 0.6]);ylim([-max(peak,0.01) max(peak,0.01)]);xlim([0 t(end)]);ylabel('Amplitude');title(labels{k});grid on;
end
xlabel('Time (seconds)');sgtitle('Same case and amplitude scale - waveforms alone do not establish perceptual quality');
exportgraphics(fig2,fullfile(out,'Demo_Waveforms.png'),'Resolution',160);
fid=fopen(fullfile(out,'RUN_STATUS.txt'),'w');fprintf(fid,'COMPLETE\n%s\nCase sp02, street, nominal 5 dB (predetermined).\n4 fresh SNR and PySTOI pairs matched saved results within 1e-8.\n48-condition bars use stored, previously completed study; not a new full run.\nCommon playback gain %.17g, 24-bit WAV, %d Hz.\nNo subjective listening was performed or claimed by this demo.\n',version,playbackGain,fs);fclose(fid);
fprintf('\nDEMO COMPLETE. Four fresh case scores match the saved study.\nCommon playback gain: %.9f\nOptional audio: play_demo_audio\nOutputs: %s\n',playbackGain,out);
figure(fig); % Keep the numerical result panels visible for recording.
end

function label_bars(values, numberFormat, axisLimits)
% Full axes and explicit values show the small differences without exaggeration.
ylim(axisLimits);
offset=0.025*diff(axisLimits);
for k=1:numel(values)
 text(k,values(k)+offset,sprintf(numberFormat,values(k)), ...
  'HorizontalAlignment','center','FontSize',11,'FontWeight','bold');
end
end
