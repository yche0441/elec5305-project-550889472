function result = run_recovery_demo()
% RUN_RECOVERY_DEMO Fresh computation of the frozen sp03/street/+6 dB example.
% Base MATLAB only. Run from this folder or add it to the MATLAB path.
% Reads source WAVs and the frozen configuration; never loads saved signals.
% Scores are computed before playback gain or WAV quantisation. Standard
% Python STOI is referenced only as a STORED score, not recomputed by MATLAB.
root=fileparts(mfilename('fullpath')); addpath(root);
outdir=fullfile(root,'demo'); if ~isfolder(outdir),mkdir(outdir);end
cfg=experiment_config();fs=cfg.fs;
[clean,fc]=audioread(fullfile(root,'data','clean','sp03.wav'));
[source,fn]=audioread(fullfile(root,'data','street','10dB','sp03_street_sn10.wav'));
assert(fc==fs && fn==fs && size(clean,2)==1 && isequal(size(clean),size(source)));
N=numel(clean);initial=800;L=200;rampN=400;
changeStart=initial+floor((N-initial)/2)+1;postStart=changeStart+rampN+800;
gainDB=zeros(N,1);gainDB(changeStart:changeStart+rampN-1)=linspace(0,6,rampN)';gainDB(changeStart+rampN:end)=6;
injectedNoise=(source-clean).*10.^(gainDB/20);input=clean+injectedNoise;
assert(isequal(input(1:changeStart-1),source(1:changeStart-1)));
methods={'unprocessed','fixed','vad_original','vad_selected','spp_default','spp_matched'};
labels={'Input','Fixed','Original gate','Selected gate','SPP 0.8','SPP 0.95'};
outputs=zeros(N,6);outputs(:,1)=input;traces=cell(1,5);
for methodIndex=2:6
 c=cfg;mode='vad';
 if methodIndex==2,mode='fixed';
 elseif methodIndex==4,c.vadThreshold_dB=1;c.hangoverFrames=10;
 elseif methodIndex>=5,mode='spp';c.sppNoiseSmoothing=.8;if methodIndex==6,c.sppNoiseSmoothing=.95;end
 end
 [outputs(:,methodIndex),traces{methodIndex-1}]=tsnr_enhance(input,fs,c,mode);
end
reference=readtable(fullfile(root,'metrics.csv'),'TextType','string');
reference=reference(reference.Cohort=="new_confirmation" & reference.Utterance=="sp03" & reference.Noise=="street" & reference.NominalSNR_dB==10 & reference.Profile=="rise_6dB",:);
assert(height(reference)==6,'Saved comparison table lacks the six frozen methods.');
SNR_dB=zeros(6,1);PostSNR_dB=zeros(6,1);LateBandError_dB=nan(6,1);StoredPythonSTOI=zeros(6,1);
maxSNRDifference=0;maxPostSNRDifference=0;maxBandDifference=0;
win=.5-.5*cos(2*pi*(1:L)'/(L+1));freq=(0:L)'*fs/(2*L);oneWeight=[1;2*ones(L-1,1);1];edges=[0 500 1000 2000 4001];
t=traces{1};valid=t.valid;late=valid & t.frameStartSample>=postStart;
truePSD=nan(2*L,numel(valid));
for frameIndex=find(valid)'
 ix=t.frameStartSample(frameIndex)+(0:L-1);
 truePSD(:,frameIndex)=abs(fft(injectedNoise(ix).*win,2*L)).^2;
end
for methodIndex=1:6
 row=reference(reference.Method==string(methods{methodIndex}),:);assert(height(row)==1);
 SNR_dB(methodIndex)=measure_snr(clean(801:end),outputs(801:end,methodIndex));
 PostSNR_dB(methodIndex)=measure_snr(clean(postStart:end),outputs(postStart:end,methodIndex));
 StoredPythonSTOI(methodIndex)=row.STOI;
 maxSNRDifference=max(maxSNRDifference,abs(SNR_dB(methodIndex)-row.SNR_dB));
 maxPostSNRDifference=max(maxPostSNRDifference,abs(PostSNR_dB(methodIndex)-row.PostSNR_dB));
 if methodIndex>1
  tr=traces{methodIndex-1};assert(isequal(tr.initialPSD,t.initialPSD));assert(isequal(tr.valid,valid));
  signed=zeros(1,4);
  for bandIndex=1:4
   bins=find(freq>=edges(bandIndex)&freq<edges(bandIndex+1));
   estimated=sum(sum(tr.noisePSDBefore(bins,late).*oneWeight(bins)));
   actual=sum(sum(truePSD(bins,late).*oneWeight(bins)));
   signed(bandIndex)=10*log10(estimated/actual);
  end
  LateBandError_dB(methodIndex)=mean(abs(signed));
  maxBandDifference=max(maxBandDifference,abs(LateBandError_dB(methodIndex)-row.LateBandError_dB));
 end
end
assert(maxSNRDifference<1e-10 && maxPostSNRDifference<1e-10 && maxBandDifference<1e-10,'Fresh demo does not match frozen results.');

% One gain across all playback clips including clean; no independently
% normalised output. Scores above use the original unquantized doubles.
peak=max([max(abs(outputs),[],'all'),max(abs(clean))]);playbackGain=.95/peak;
assert(isfinite(playbackGain)&&playbackGain>0);
audioFiles={'01_input.wav','02_fixed.wav','03_original_gate.wav','04_selected_gate.wav','05_spp_0_8.wav','06_spp_0_95.wav'};
for methodIndex=1:6
 audiowrite(fullfile(outdir,audioFiles{methodIndex}),outputs(:,methodIndex)*playbackGain,fs,'BitsPerSample',24);
end
audiowrite(fullfile(outdir,'07_clean_reference.wav'),clean*playbackGain,fs,'BitsPerSample',24);
save(fullfile(outdir,'Recovery_Demo_Signals.mat'),'clean','source','input','injectedNoise','outputs','methods','fs','changeStart','postStart','playbackGain','-v7');
result=struct('Status','PASS','Case','new_confirmation/sp03/street/10dB/rise_6dB', ...
 'FreshComputationFromSourceWAV',true,'NoSavedSignalsLoaded',true,'MATLABVersion',version, ...
 'CompletedUTC',char(datetime('now','TimeZone','UTC')),'Methods',{methods},'FreshSNR_dB',SNR_dB', ...
 'FreshPostSNR_dB',PostSNR_dB','FreshLateBandError_dB',LateBandError_dB', ...
 'StoredStandardPythonSTOI',StoredPythonSTOI','STOINote','Stored standard pystoi scores, not recomputed by this MATLAB demo', ...
 'MaxAbsSNRDifferenceFromSaved',maxSNRDifference,'MaxAbsPostSNRDifferenceFromSaved',maxPostSNRDifference, ...
 'MaxAbsBandErrorDifferenceFromSaved',maxBandDifference,'PlaybackCommonGain',playbackGain, ...
 'PlaybackPeakAcrossAllClips',peak*playbackGain,'PlaybackBitsPerSample',24, ...
 'SubjectiveListeningEvaluated',false,'OldBaselines','Full-study regression verified unchanged waveforms for all old baseline cases');
fid=fopen(fullfile(outdir,'DEMO_CHECK.json'),'w');fprintf(fid,'%s\n',jsonencode(result,PrettyPrint=true));fclose(fid);
T=table(string(methods)',SNR_dB,PostSNR_dB,LateBandError_dB,StoredPythonSTOI, ...
 'VariableNames',{'Method','FreshSNR_dB','FreshPostSNR_dB','FreshLateBandError_dB','StoredStandardPythonSTOI'});
writetable(T,fullfile(outdir,'Demo_Metrics.csv'));

colours=[.39 .44 .5;.77 .53 .28;.70 .36 .16;0 .49 .51;.42 .35 .80];
fig=figure('Visible','off','Color','w','Position',[100 100 1250 900]);
layout=tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
title(layout,'Fresh computation: sp03, street noise, +6 dB rise','FontSize',17,'FontWeight','bold');
time=t.time_s(valid);normaliser=sum(t.initialPSD);changeTime=(changeStart-1)/fs;lateTime=(postStart-1)/fs;
ax1=nexttile(layout);hold(ax1,'on');
plot(ax1,time,10*log10(sum(truePSD(:,valid),1)'/normaliser),'Color',[.62 .66 .71],'LineWidth',1,'DisplayName','Injected noise');
for methodIndex=2:6
 tr=traces{methodIndex-1};style='-';if methodIndex==6,style='--';end
 plot(ax1,time,10*log10(tr.noisePower(valid)/normaliser),style,'Color',colours(methodIndex-1,:), ...
  'LineWidth',1.7,'DisplayName',labels{methodIndex});
end
legend(ax1,'Location','northwest','NumColumns',3,'FontSize',10);
ylabel(ax1,{'Broadband power relative';'to initial estimate (dB)'});grid(ax1,'on');
ax2=nexttile(layout);hold(ax2,'on');
for methodIndex=2:6
 tr=traces{methodIndex-1};style='-';if methodIndex==6,style='--';end
 plot(ax2,time,tr.meanUpdateWeight(valid),style,'Color',colours(methodIndex-1,:),'LineWidth',1.5);
end
ylabel(ax2,{'Mean effective';'update weight'});xlabel(ax2,'Time (s)');grid(ax2,'on');
for a=[ax1 ax2]
 xlim(a,[time(1),time(end)]);yl=ylim(a);
 h=patch(a,[changeTime changeTime+.05 changeTime+.05 changeTime],[yl(1) yl(1) yl(2) yl(2)], ...
  [.86 .70 .32],'FaceAlpha',.18,'EdgeColor','none','HandleVisibility','off');uistack(h,'bottom');
 xline(a,lateTime,':','Color',[.3 .3 .3],'LineWidth',1.3,'HandleVisibility','off');
end
ax3=nexttile(layout);bars=bar(ax3,SNR_dB,'FaceColor','flat');bars.CData=[.28 .34 .40;colours];
xticks(ax3,1:6);xticklabels(ax3,labels);ylabel(ax3,'Reference SNR (dB)');grid(ax3,'on');
title(ax3,'Fresh reference SNR from unquantized outputs; whole recording excluding first 100 ms','FontSize',12);
for j=1:6,text(ax3,j,SNR_dB(j),sprintf(' %.3f',SNR_dB(j)),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',10);end
set([ax1 ax2 ax3],'FontSize',11,'Box','off');
exportgraphics(fig,fullfile(outdir,'Recovery_Demo.png'),'Resolution',180);
close(fig);
fid=fopen(fullfile(outdir,'AUDIO_PLAYBACK_NOTES.txt'),'w');
fprintf(fid,'All seven WAV files use one common gain %.17g, chosen from all six method outputs and the clean reference so the largest playback peak is 0.95. They are 24-bit playback copies. Numerical scores use unquantized outputs in Recovery_Demo_Signals.mat. No separate output normalisation, subjective listening ratings or perceptual superiority claims are made.\n',playbackGain);fclose(fid);
disp(T);fprintf('FRESH RECOVERY DEMO PASS. Source WAVs recomputed; scores and four-band errors match saved study.\n');
end
