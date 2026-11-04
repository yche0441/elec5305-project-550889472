function run_recovery_study()
% Frozen soft-SPP follow-up. Run in a COPY: saved result files are replaced.
root=fileparts(mfilename('fullpath'));addpath(root);
protocol=jsondecode(fileread(fullfile(root,'PROTOCOL.json')));
assert(strcmp(protocol.protocol_id,'soft-tracker-recovery-v1-20261104'));
cfg=experiment_config();fs=cfg.fs;initial=800;L=200;rampN=400;
methods={'unprocessed','fixed','vad_original','vad_selected','spp_default','spp_matched'};
oldIDs={'sp02','sp07','sp12','sp17','sp22','sp27'};
newIDs=cellstr(protocol.new_sentence_ids);
cohorts={'old_diagnostic','new_confirmation'};speakers={'CH','DE','JE','KI','SI','TI'};
noises={'car','street'};profilesAll={'constant','rise_6dB','fall_6dB'};targetDB=[0 6 -6];
for name={'signals','figures','audio'},if ~isfolder(fullfile(root,name{1})),mkdir(fullfile(root,name{1}));end,end
previous=load(fullfile(root,'regression_reference.mat'),'signals');
rows=struct([]);checks=struct([]);frameTables={};ci=0;ri=0;
win=.5-.5*cos(2*pi*(1:L)'/(L+1));freq=(0:L)'*fs/(2*L);oneWeight=[1;2*ones(L-1,1);1];
edges=[0 500 1000 2000 4001];
meta=struct('MATLABVersion',version,'StartedUTC',char(datetime('now','TimeZone','UTC')), ...
 'Protocol',protocol.protocol_id,'Scoring','Python pystoi0.4.1 standard separately on unquantized outputs');
for co=1:2
 if co==1,ids=oldIDs;snrs=10;else,ids=newIDs;snrs=[0 5 10 15];end
 for ui=1:numel(ids)
  u=ids{ui};speaker=speakers{ceil(str2double(u(3:end))/5)};
  [clean,rate]=audioread(fullfile(root,'data','clean',[u '.wav']));assert(rate==fs&&size(clean,2)==1);
  N=numel(clean);changeStart=initial+floor((N-initial)/2)+1;postStart=changeStart+rampN+800;
  assert(postStart<N);signals=struct([]);si=0;
  for ni=1:2
   noiseName=noises{ni};
   for snr=snrs
    [source,rate2]=audioread(fullfile(root,'data',noiseName,sprintf('%ddB',snr),sprintf('%s_%s_sn%d.wav',u,noiseName,snr)));
    assert(rate2==fs&&isequal(size(source),size(clean)));residual=source-clean;
    if snr==10,profiles=profilesAll;else,profiles={'constant'};end
    baseOut=[];baseTraces=cell(5,1);initialPSD=[];
    for profileIndex=1:numel(profiles)
     gainDB=zeros(N,1);gainDB(changeStart:changeStart+rampN-1)=linspace(0,targetDB(profileIndex),rampN)';gainDB(changeStart+rampN:end)=targetDB(profileIndex);
     injected=residual.*10.^(gainDB/20);mixture=clean+injected;
     assert(isequal(mixture(1:changeStart-1),source(1:changeStart-1)));
     if profileIndex==1,assert(isequal(mixture,source));end
     ci=ci+1;si=si+1;out=zeros(N,6);out(:,1)=mixture;traceExample={};diagnostics=struct([]);
     s=struct('CaseID',ci,'Cohort',cohorts{co},'Utterance',u,'Speaker',speaker,'Noise',noiseName, ...
      'NominalSNR_dB',snr,'Profile',profiles{profileIndex},'clean',clean,'input',mixture,'injectedNoise',injected, ...
      'changeStart',changeStart,'postStart',postStart,'outputs',[]);
     for mi=2:6
      c=cfg;mode='vad';
      if mi==2,mode='fixed';elseif mi==4,c.vadThreshold_dB=1;c.hangoverFrames=10;
      elseif mi>=5,mode='spp';c.sppNoiseSmoothing=.8;if mi==6,c.sppNoiseSmoothing=.95;end,end
      [out(:,mi),t]=tsnr_enhance(mixture,fs,c,mode);
      if isempty(initialPSD),initialPSD=t.initialPSD;end
      assert(isequal(t.initialPSD,initialPSD));
      valid=t.valid;late=valid&t.frameStartSample>=postStart;assert(any(late));
      pre=valid&t.frameStartSample+L-1<changeStart;
      if profileIndex==1,baseTraces{mi-1}=t;
      else
       tb=baseTraces{mi-1};assert(isequal(t.noisePSDBefore(:,pre),tb.noisePSDBefore(:,pre)));
       assert(isequal(t.updateWeight(:,pre),tb.updateWeight(:,pre)));
       assert(isequal(out(1:changeStart-2*L-1,mi),baseOut(1:changeStart-2*L-1,mi)));
      end
      assert(all(t.meanUpdateWeight(~valid)==0));
      assert(isequal(t.noisePSDBefore(:,~valid),t.noisePSDAfter(:,~valid)));
      assert(isequaln(t.sppStateBefore(:,~valid),t.sppStateAfter(:,~valid)));
      [~,proxy]=pair_diagnostics(clean,mixture,t,cfg);
      truePSD=nan(2*L,numel(valid));
      for k=find(valid)'
       ix=t.frameStartSample(k)+(0:L-1);truePSD(:,k)=abs(fft(injected(ix).*win,2*L)).^2;
      end
      truePower=sum(truePSD,1)';err=10*log10(t.noisePower./truePower);
      signed=zeros(1,4);
      for b=1:4
       bins=find(freq>=edges(b)&freq<edges(b+1));
       est=sum(sum(t.noisePSDBefore(bins,late).*oneWeight(bins)));
       truth=sum(sum(truePSD(bins,late).*oneWeight(bins)));
       assert(est>0&&truth>0);signed(b)=10*log10(est/truth);
      end
      d=struct('LateTrackingBias_dB',10*log10(sum(t.noisePower(late))/sum(truePower(late))), ...
       'LateMedianAbsTrackingError_dB',median(abs(err(late))), ...
       'LateBandError_dB',mean(abs(signed)),'Band0_500Bias_dB',signed(1),'Band500_1000Bias_dB',signed(2), ...
       'Band1000_2000Bias_dB',signed(3),'Band2000_4000Bias_dB',signed(4), ...
       'LateSpectralNRMSE',norm(mean(t.noisePSDBefore(1:L+1,late),2)-mean(truePSD(1:L+1,late),2))/norm(mean(truePSD(1:L+1,late),2)), ...
       'MeanUpdateWeight',mean(t.meanUpdateWeight(valid)), ...
       'LateMeanUpdateWeight',mean(t.meanUpdateWeight(late)), ...
       'SpeechProxyMeanWeight',mean(t.meanUpdateWeight(proxy.speechProxy)), ...
       'LowEnergyProxyMeanWeight',mean(t.meanUpdateWeight(proxy.nonSpeechProxy)), ...
       'ValidFrames',sum(valid),'LateFrames',sum(late),'SpeechProxyFrames',sum(proxy.speechProxy), ...
       'LowEnergyProxyFrames',sum(proxy.nonSpeechProxy));
      if mi==2,assert(~any(t.noiseUpdated));end
      if isempty(diagnostics),diagnostics=repmat(d,1,6);else,diagnostics(mi)=d;end
      j=find(valid);q=numel(j);
      frameTables{end+1}=table(repmat(ci,q,1),repmat(string(cohorts{co}),q,1),repmat(string(u),q,1), ...
       repmat(string(noiseName),q,1),repmat(snr,q,1),repmat(string(profiles{profileIndex}),q,1),repmat(string(methods{mi}),q,1), ...
       t.frameStartSample(j),t.time_s(j),t.noisePower(j),truePower(j),err(j),t.meanUpdateWeight(j), ...
       proxy.speechProxy(j),proxy.nonSpeechProxy(j),late(j), ...
       'VariableNames',{'CaseID','Cohort','Utterance','Noise','NominalSNR_dB','Profile','Method','FrameStartSample','Time_s', ...
       'EstimateBeforeUpdate','InjectedFramePower','EstimateRatio_dB','MeanUpdateWeight','SpeechProxy','LowEnergyProxy','LatePost'}); %#ok<AGROW>
      if co==2&&strcmp(u,'sp03')&&strcmp(noiseName,'street')&&snr==10&&profileIndex==2
       traceExample{mi-1}=t; %#ok<AGROW>
      end
     end
     if profileIndex==1
      baseOut=out;[identity,~]=tsnr_enhance(mixture,fs,cfg,'identity');identityError=max(abs(identity-mixture));assert(identityError<1e-12);
      cfgOther=cfg;cfgOther.vadThreshold_dB=1;cfgOther.hangoverFrames=10;
      [fOther,~]=tsnr_enhance(mixture,fs,cfgOther,'fixed');assert(isequal(fOther,out(:,2)));
     end
     oldError=NaN;
     if co==1
      idx=find(strcmp({previous.signals.Utterance},u)&strcmp({previous.signals.Noise},noiseName)&strcmp({previous.signals.Profile},profiles{profileIndex}));assert(numel(idx)==1);
      oldError=max(abs(out(:,1:4)-previous.signals(idx).outputs),[],'all');assert(oldError==0,'Old baseline waveform changed.');
     end
     s.outputs=out;if isempty(signals),signals=s;else,signals(si)=s;end %#ok<AGROW>
     for mi=1:6
      ri=ri+1;r=struct('CaseID',ci,'Cohort',cohorts{co},'Utterance',u,'Speaker',speaker,'Noise',noiseName, ...
       'NominalSNR_dB',snr,'Profile',profiles{profileIndex},'Method',methods{mi}, ...
       'SNR_dB',measure_snr(clean(initial+1:end),out(initial+1:end,mi)), ...
       'PostSNR_dB',measure_snr(clean(postStart:end),out(postStart:end,mi)));
      fn=fieldnames(diagnostics(2));for f=1:numel(fn),if mi==1,r.(fn{f})=NaN;else,r.(fn{f})=diagnostics(mi).(fn{f});end,end
      if isempty(rows),rows=r;else,rows(ri)=r;end %#ok<AGROW>
     end
     vr=struct('CaseID',ci,'Cohort',cohorts{co},'Utterance',u,'Noise',noiseName,'NominalSNR_dB',snr,'Profile',profiles{profileIndex}, ...
      'Samples',N,'ChangeStartSample',changeStart,'PostStartSample',postStart,'PrefixExact',true,'SharedInitialPSDExact',true, ...
      'PreChangeTraceExact',true,'SafeOutputPrefixExact',true,'InvalidStateFrozen',true,'IdentityMaxAbsError',identityError, ...
      'OldBaselineMaxAbsError',oldError,'InputPeak',max(abs(mixture)));
     if isempty(checks),checks=vr;else,checks(ci)=vr;end %#ok<AGROW>
     if ~isempty(traceExample)
      traceSignal=s;save(fullfile(root,'preselected_trace.mat'),'traceExample','traceSignal','methods','fs','-v7');
     end
     fprintf('CASE %03d/252 %s %s %s %ddB %s complete\n',ci,cohorts{co},u,noiseName,snr,profiles{profileIndex});
    end
   end
  end
  save(fullfile(root,'signals',sprintf('%s_%s.mat',cohorts{co},u)),'signals','methods','fs','-v7');
 end
end
assert(ci==252&&ri==1512);
writetable(struct2table(rows),fullfile(root,'matlab_metrics.csv'));
writetable(struct2table(checks),fullfile(root,'verification_cases.csv'));
writetable(vertcat(frameTables{:}),fullfile(root,'frame_diagnostics.csv'));
meta.CompletedUTC=char(datetime('now','TimeZone','UTC'));
fid=fopen(fullfile(root,'MATLAB_RUN_STATUS.json'),'w');fprintf(fid,'%s',jsonencode(meta,PrettyPrint=true));fclose(fid);
fprintf('RECOVERY STUDY COMPLETE:252 inputs,1512 method rows, all verification gates passed.\n');
end
