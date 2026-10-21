function run_final_study()
root=fileparts(mfilename('fullpath')); addpath(root);
source=fullfile(root,'reference_v1'); % Portable, unchanged v1 verification fixtures
cfg=experiment_config();
assert(isfile(fullfile(root,'stoi_bridge.py')),'STOI bridge required.');
meta=struct('MATLABVersion',version,'Started',char(datetime('now')),'STOI','pystoi standard extended=False via unquantized double MAT bridge');
verification=verify_core(source,cfg);
rows=struct([]); grid=struct([]); gi=0;
for threshold=[1 3 5]
 for hangover=[0 5 10]
  c=cfg;c.vadThreshold_dB=threshold;c.hangoverFrames=hangover;
  r=score_set(root,{'sp01','sp16'},c,'development','vad_grid');
  rows=[rows;r(:)]; %#ok<AGROW>
  gi=gi+1; grid(gi).Threshold_dB=threshold;grid(gi).HangoverFrames=hangover;
  grid(gi).MeanSNR_dB=mean([r.SNR_dB]);grid(gi).MeanSTOI=mean([r.STOI]);
  grid(gi).SpeechProxyUpdateFraction=sum([r.SpeechProxyUpdates])/sum([r.SpeechProxyFrames]);
  grid(gi).MeanUpdateFraction=mean([r.UpdateFraction]);
  fprintf('GRID threshold=%g hangover=%g SNR=%.6f STOI=%.6f\n',threshold,hangover,grid(gi).MeanSNR_dB,grid(gi).MeanSTOI);
  writetable(struct2table(rows),fullfile(root,'development_metrics.csv'));
 end
end
G=struct2table(grid);writetable(G,fullfile(root,'development_summary.csv'));
candidates=find(G.MeanSTOI>=max(G.MeanSTOI)-1e-6);
[~,order]=sortrows([-G.MeanSNR_dB(candidates),abs(G.Threshold_dB(candidates)-3)+abs(G.HangoverFrames(candidates)-5)],[1 2]);
best=candidates(order(1));selected=cfg;selected.vadThreshold_dB=G.Threshold_dB(best);selected.hangoverFrames=G.HangoverFrames(best);
fid=fopen(fullfile(root,'SELECTION.json'),'w');fprintf(fid,'%s',jsonencode(struct('threshold_dB',selected.vadThreshold_dB,'hangoverFrames',selected.hangoverFrames,'developmentMeanSTOI',G.MeanSTOI(best),'selected_before_new_test',char(datetime('now')))));fclose(fid);
r=score_set(root,{'sp01','sp16'},cfg,'development','fixed');
writetable(struct2table(r),fullfile(root,'development_fixed.csv'));
test=struct([]); utterances={'sp02','sp07','sp12','sp17','sp22','sp27'};
for method={'unprocessed','fixed','vad_original','vad_selected'}
 c=cfg;if strcmp(method{1},'vad_selected'),c=selected;end
 r=score_set(root,utterances,c,'new_sentence_test',method{1});test=[test;r(:)]; %#ok<AGROW>
 writetable(struct2table(test),fullfile(root,'new_test_metrics.csv'));
 fprintf('TEST %s SNR=%.6f STOI=%.6f\n',method{1},mean([r.SNR_dB]),mean([r.STOI]));
end
assert(numel(test)==192 && all(isfinite([test.STOI])));
meta.Completed=char(datetime('now'));save(fullfile(root,'study_results.mat'),'cfg','selected','grid','rows','test','verification','meta');
fid=fopen(fullfile(root,'RUN_STATUS.txt'),'w');fprintf(fid,'COMPLETE\nMATLAB: %s\nNative verification passed\nDevelopment:9configs x16cases\nNew sentence test:48cases x4methods\nAll SNR/STOI finite\n',version);fclose(fid);
fprintf('FINAL STUDY COMPLETE\n');
end
function rows=score_set(root,utterances,cfg,split,method)
rows=struct([]);
for ui=1:numel(utterances)
 u=utterances{ui};[clean,fs]=audioread(fullfile(root,'data','clean',[u '.wav']));
 for ni=1:numel(cfg.noises)
  noise=cfg.noises{ni};
  for nominal=cfg.nominalSNRs
   [noisy,fs2]=audioread(fullfile(root,'data',noise,sprintf('%ddB',nominal),sprintf('%s_%s_sn%d.wav',u,noise,nominal)));
   assert(fs==8000 && fs2==fs && isequal(size(noisy),size(clean)) && size(clean,2)==1);
   mode='vad';if strcmp(method,'fixed')||strcmp(method,'unprocessed'),mode='fixed';end
   [output,trace]=tsnr_enhance(noisy,fs,cfg,mode);
   if strcmp(method,'unprocessed'),output=noisy;end
   [~,frame]=pair_diagnostics(clean,noisy,trace,cfg);ix=801:numel(clean);
   r=struct('Utterance',u,'Noise',noise,'NominalSNR_dB',nominal,'Split',split,'Method',method,'Threshold_dB',cfg.vadThreshold_dB,'HangoverFrames',cfg.hangoverFrames,'SNR_dB',measure_snr(clean(ix),output(ix)),'STOI',bridge_stoi(root,clean(ix),output(ix),fs),'SpeechProxyUpdates',sum(trace.noiseUpdated & frame.speechProxy),'SpeechProxyFrames',sum(frame.speechProxy),'UpdateFraction',sum(trace.noiseUpdated)/sum(trace.valid));
   assert(isfinite(r.SNR_dB)&&isfinite(r.STOI));
   if isempty(rows),rows=r;else,rows(end+1)=r;end %#ok<AGROW>
  end
 end
end
end

function value=bridge_stoi(root,reference,processed,fs)
inputFile=fullfile(root,'metric_input.mat');save(inputFile,'reference','processed','fs','-v7');
py=getenv('ELEC5305_PYTHON');
if isempty(py), py='python3'; end % Set an absolute Python executable when needed
[status,text]=system(sprintf('"%s" "%s" "%s"',py,fullfile(root,'stoi_bridge.py'),inputFile));
assert(status==0,'Python STOI failed: %s',text);value=str2double(strtrim(text));assert(isfinite(value));
end
