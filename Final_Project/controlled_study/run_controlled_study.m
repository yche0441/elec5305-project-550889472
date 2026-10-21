function run_controlled_study()
% Run the frozen matched noise-level diagnostic; does not tune any parameter.
% Work in a COPY of this folder because reproducibility runs replace results.
root=fileparts(mfilename('fullpath'));addpath(root);
assert(isfile(fullfile(root,'PROTOCOL.json')),'Save protocol before execution.');
cfg=experiment_config(); fs=cfg.fs; initial=round(cfg.initialSeconds*fs);
ids={'sp02','sp07','sp12','sp17','sp22','sp27'};
noiseNames={'car','street'}; profiles={'constant','rise_6dB','fall_6dB'};
targetDB=[0 6 -6]; methods={'unprocessed','fixed','vad_original','vad_selected'};
rows=struct([]); signals=struct([]); checks=struct([]); frameTables={};
ri=0; ci=0; vi=0; L=round(cfg.windowSeconds*fs); rampN=round(.05*fs);
meta=struct('MATLABVersion',version,'Started',char(datetime('now')), ...
 'Protocol','controlled-level-change-v1-20261014','Scoring','PySTOI standard separately from unquantized arrays');
for ui=1:numel(ids)
 u=ids{ui}; [clean,rate]=audioread(fullfile(root,'data','clean',[u '.wav']));
 assert(rate==fs && size(clean,2)==1); N=numel(clean);
 changeStart=initial+floor((N-initial)/2)+1;
 postStart=changeStart+rampN+round(.1*fs);
 assert(postStart<N && changeStart>initial+2*L);
 for ni=1:numel(noiseNames)
  noiseName=noiseNames{ni};
  [original,rate2]=audioread(fullfile(root,'data',noiseName,'10dB',[u '_' noiseName '_sn10.wav']));
  assert(rate2==fs && isequal(size(clean),size(original)));
  residual=original-clean; baseOutput=[]; baseTrace=cell(3,1); calibrationPSD=[];
  for profileIndex=1:numel(profiles)
   gainDB=zeros(N,1); gainDB(changeStart:changeStart+rampN-1)=linspace(0,targetDB(profileIndex),rampN)';
   gainDB(changeStart+rampN:end)=targetDB(profileIndex);
   gain=10.^(gainDB/20); injected=residual.*gain; mixture=clean+injected;
   assert(isequal(mixture(1:changeStart-1),original(1:changeStart-1)));
   if profileIndex==1,assert(isequal(mixture,original));end
   ci=ci+1; out=zeros(N,4);out(:,1)=mixture;
   signals(ci).Utterance=u; signals(ci).Noise=noiseName;signals(ci).Profile=profiles{profileIndex};
   signals(ci).clean=clean;signals(ci).input=mixture;signals(ci).injectedNoise=injected;
   signals(ci).gainDB=gainDB;signals(ci).changeStart=changeStart;signals(ci).postStart=postStart;
   for mi=2:4
    c=cfg; mode='vad'; if mi==2,mode='fixed';end
    if mi==4,c.vadThreshold_dB=1;c.hangoverFrames=10;end
    [out(:,mi),trace]=tsnr_enhance(mixture,fs,c,mode);
    assert(all(isfinite(out(:,mi))) && numel(out(:,mi))==N);
    if isempty(calibrationPSD),calibrationPSD=trace.initialPSD;end
    assert(isequal(calibrationPSD,trace.initialPSD),'Shared initial PSD differs.');
    preFrame=trace.valid & trace.frameStartSample+L-1<changeStart;
    if profileIndex==1
     baseTrace{mi-1}=trace;
    else
     tb=baseTrace{mi-1};
     assert(isequal(trace.noisePower(preFrame),tb.noisePower(preFrame)));
     assert(isequal(trace.speechDecision(preFrame),tb.speechDecision(preFrame)));
     assert(isequal(trace.noiseUpdated(preFrame),tb.noiseUpdated(preFrame)));
     safeEnd=changeStart-2*L-1;
     assert(isequal(out(1:safeEnd,mi),baseOutput(1:safeEnd,mi)),'Output prefix changed before support margin.');
    end
    if profileIndex==1 && mi==2
     [identity,~]=tsnr_enhance(mixture,fs,c,'identity');
     identityError=max(abs(identity-mixture));assert(identityError<1e-12);
     other=c;other.vadThreshold_dB=1;other.hangoverFrames=10;
     [fixedOther,~]=tsnr_enhance(mixture,fs,other,'fixed');
     assert(isequal(fixedOther,out(:,mi)),'Threshold affects fixed output.');
    end
    [~,proxy]=pair_diagnostics(clean,mixture,trace,cfg);
    starts=trace.frameStartSample; valid=trace.valid;
    truePower=nan(size(starts)); window=.5-.5*cos(2*pi*(1:L)'/(L+1));
    for k=find(valid)'
     ix=starts(k)+(0:L-1);v=fft(injected(ix).*window,2*L);truePower(k)=sum(abs(v).^2);
    end
    late=valid & starts>=postStart;
    assert(any(late) && all(truePower(valid)>0));
    errDB=10*log10(trace.noisePower./truePower);
    j=find(valid);q=numel(j);
    frameTables{end+1}=table(repmat(ci,q,1),repmat(string(u),q,1),repmat(string(noiseName),q,1), ...
      repmat(string(profiles{profileIndex}),q,1),repmat(string(methods{mi}),q,1),starts(j),trace.time_s(j), ...
      trace.noisePower(j),truePower(j),errDB(j),trace.speechDecision(j),trace.noiseUpdated(j), ...
      proxy.speechProxy(j),proxy.nonSpeechProxy(j),late(j), ...
      'VariableNames',{'CaseID','Utterance','Noise','Profile','Method','FrameStartSample','Time_s', ...
      'EstimateBeforeUpdate','InjectedFramePower','EstimateRatio_dB','SpeechDecision','Updated', ...
      'SpeechProxy','NonSpeechProxy','LatePost'}); %#ok<AGROW>
    diagnostics(mi).LateTrackingBias_dB=10*log10(sum(trace.noisePower(late))/sum(truePower(late)));
    diagnostics(mi).LateMedianAbsTrackingError_dB=median(abs(errDB(late)));
    diagnostics(mi).LateUpdateFraction=mean(trace.noiseUpdated(late));
    diagnostics(mi).SpeechProxyUpdates=sum(trace.noiseUpdated & proxy.speechProxy);
    diagnostics(mi).SpeechProxyFrames=sum(proxy.speechProxy);
    diagnostics(mi).NonSpeechProxyUpdates=sum(trace.noiseUpdated & proxy.nonSpeechProxy);
    diagnostics(mi).NonSpeechProxyFrames=sum(proxy.nonSpeechProxy);
    diagnostics(mi).TotalUpdates=sum(trace.noiseUpdated);diagnostics(mi).ValidFrames=sum(valid);
    if mi==2,assert(~any(trace.noiseUpdated));end
   end
   if profileIndex==1,baseOutput=out;end
   signals(ci).outputs=out;
   for mi=1:4
    ri=ri+1;r=struct('CaseID',ci,'Utterance',u,'Noise',noiseName,'Profile',profiles{profileIndex}, ...
      'Method',methods{mi},'SNR_dB',measure_snr(clean(initial+1:end),out(initial+1:end,mi)), ...
      'PostSNR_dB',measure_snr(clean(postStart:end),out(postStart:end,mi)), ...
      'LateTrackingBias_dB',NaN,'LateMedianAbsTrackingError_dB',NaN,'LateUpdateFraction',NaN, ...
      'SpeechProxyUpdates',NaN,'SpeechProxyFrames',NaN,'NonSpeechProxyUpdates',NaN,'NonSpeechProxyFrames',NaN, ...
      'TotalUpdates',NaN,'ValidFrames',NaN);
    if mi>1
     fn=fieldnames(diagnostics(mi));for f=1:numel(fn),r.(fn{f})=diagnostics(mi).(fn{f});end
    end
    if isempty(rows),rows=r;else,rows(ri)=orderfields(r,rows);end %#ok<AGROW>
   end
   vi=vi+1;vr=struct('CaseID',ci,'Utterance',u,'Noise',noiseName,'Profile',profiles{profileIndex}, ...
     'Samples',N,'ChangeStartSample',changeStart,'PostStartSample',postStart,'PrefixExact',true, ...
     'SharedInitialPSDExact',true,'PreChangeTraceExact',true,'SafeOutputPrefixExact',true, ...
     'IdentityMaxAbsError',identityError,'InputPeak',max(abs(mixture)), ...
     'InitialCleanToInjectedNoise_dB',10*log10(sum(clean(1:initial).^2)/sum(injected(1:initial).^2)));
   if isempty(checks),checks=vr;else,checks(vi)=orderfields(vr,checks);end %#ok<AGROW>
   fprintf('CASE %02d/36 %s %s %s complete\n',ci,u,noiseName,profiles{profileIndex});
  end
 end
end
assert(numel(rows)==144 && numel(signals)==36 && all(isfinite([rows.SNR_dB])));
writetable(struct2table(rows),fullfile(root,'matlab_metrics.csv'));
writetable(struct2table(checks),fullfile(root,'verification_cases.csv'));
writetable(vertcat(frameTables{:}),fullfile(root,'frame_diagnostics.csv'));
meta.Completed=char(datetime('now'));
save(fullfile(root,'unquantized_signals.mat'),'signals','fs','methods','meta','-v7');
fid=fopen(fullfile(root,'MATLAB_RUN_STATUS.json'),'w');fprintf(fid,'%s',jsonencode(meta,PrettyPrint=true));fclose(fid);
fprintf('CONTROLLED STUDY MATLAB COMPLETE:36mixtures,144rows, all verification gates passed.\n');
end
