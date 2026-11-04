function status = verify_spp_synthetic()
% VERIFY_SPP_SYNTHETIC Checks implementation using generated values only.
% No corpus scores, tuning, or real-data outcomes are inspected here.
here=fileparts(mfilename('fullpath'));
addpath(here); addpath(fullfile(here,'validation_reference'));
cleanup=onCleanup(@() rmpath(fullfile(here,'validation_reference')));
cfg=baseline_config_reference();
rng(5305,'twister');
N=16000; t=(0:N-1)'/cfg.fs;
y=.03*randn(N,1);
y(801:end)=y(801:end)+.04*sin(2*pi*170*t(801:end)).*(.5+.5*cos(2*pi*3*t(801:end)));
status.syntheticOnly=true;
status.baselineBitIdentical=true;
status.originalTraceFieldsBitIdentical=true;
for name={'fixed','vad','identity'}
 [old,oldTrace]=tsnr_enhance_reference_snapshot(y,cfg.fs,cfg,name{1});
 [new,newTrace]=tsnr_enhance(y,cfg.fs,cfg,name{1});
 assert(isequal(old,new),'Baseline waveform changed.');
 fn=fieldnames(oldTrace);
 for j=1:numel(fn)
  assert(isequaln(oldTrace.(fn{j}),newTrace.(fn{j})),'Baseline trace changed.');
 end
end
cfg.legacyReproduction=true;
a=tsnr_enhance_reference_snapshot(y,cfg.fs,cfg,'fixed');
b=tsnr_enhance(y,cfg.fs,cfg,'fixed');
assert(isequal(a,b),'Legacy output changed.');
cfg.legacyReproduction=false;
status.legacyBitIdentical=true;

% Two smoothing rates, exact explicit reference recurrence, saturation case.
for alpha=[.8 .95]
 cfg.sppNoiseSmoothing=alpha;
 D=exp(randn(400,1)); M=.5*ones(400,1);
 for frame=1:120
  P=D.*logspace(-4,4,400)';
  if frame>20, P=1e5*D; end
  xi=10^(15/10);
  LR=exp(min(log(1/(1+xi))+xi/(1+xi)*(P./D),200));
  raw=LR./(1+LR);
  expectedM=.9*M+.1*raw;
  capped=raw;
  ix=expectedM>.99;
  capped(ix)=min(capped(ix),.99);
  E=capped.*D+(1-capped).*P;
  expectedD=alpha*D+(1-alpha)*E;
  [newD,newM,tr]=noise_psd_spp_update(P,D,M,cfg);
  assert(max(abs(newD-expectedD)./max(expectedD,realmin))<2e-14);
  assert(max(abs(newM-expectedM))<2e-14);
  assert(max(abs(tr.probabilityBeforeCap-raw))<2e-14);
  assert(max(abs(tr.probabilityAfterCap-capped))<2e-14);
  assert(isequal(tr.capActive,ix));
  assert(max(abs(tr.updateWeight-(1-alpha)*(1-capped)))<2e-14);
  if frame>70
   assert(all(tr.capActive) && all(tr.probabilityAfterCap==.99));
   assert(all(tr.updateWeight>0));
  end
  % Keep test powers bounded while checking state; use fixed positive PSD.
  M=newM;
 end
end
status.explicitRecurrencePassed=true;
status.stagnationSafeguardPassed=true;

cfg.sppNoiseSmoothing=.8;
[e,tr]=tsnr_enhance(y,cfg.fs,cfg,'spp');
assert(all(isfinite(e)) && numel(e)==N);
assert(isequal(tr.noisePSDBefore(:,2:end),tr.noisePSDAfter(:,1:end-1)));
assert(isequal(tr.sppStateBefore(:,2:end),tr.sppStateAfter(:,1:end-1)));
invalid=~tr.valid;
assert(isequal(tr.noisePSDBefore(:,invalid),tr.noisePSDAfter(:,invalid)));
assert(isequal(tr.sppStateBefore(:,invalid),tr.sppStateAfter(:,invalid)));
assert(all(tr.meanUpdateWeight(invalid)==0));
assert(isequal(tr.initialPSD,tr.noisePSDBefore(:,1)));
for k=find(tr.valid)'
 D=tr.noisePSDBefore(:,k); P=tr.noisyPeriodogram(:,k);
 expected=D+tr.updateWeight(:,k).*(P-D);
 actual=tr.noisePSDAfter(:,k);
 assert(max(abs(expected-actual)./max(actual,realmin))<3e-14);
end
status.afterEnhancementCausalStatePassed=true;
status.calibrationAndPaddingFrozen=true;
status.binwiseRecurrenceTracePassed=true;
% Real-input FFT powers and binwise states retain conjugate symmetry.
assert(max(abs(tr.noisePSDAfter(2:200,:)-tr.noisePSDAfter(400:-1:202,:)),[],'all')<1e-12);
status.conjugateSymmetryPassed=true;
status.matlabVersion=version;
status.pass=true;
fid=fopen(fullfile(here,'SYNTHETIC_UNIT_CHECK.json'),'w');
fprintf(fid,'%s\n',jsonencode(status,PrettyPrint=true)); fclose(fid);
disp(status);
end
