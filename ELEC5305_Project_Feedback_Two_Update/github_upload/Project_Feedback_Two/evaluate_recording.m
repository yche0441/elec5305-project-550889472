function m = evaluate_recording(reference, original, processed, fs, noiseInterval_s, cfg)
%EVALUATE_RECORDING Reference error and labelled-interval proxies.
% Preserve absolute recording scale. Never re-align or renormalise outputs
% to improve a metric. The clean room reference is evaluation data.
reference = reference(:); original = original(:); processed = processed(:);
assert(isequal(size(reference),size(original),size(processed)), 'Length mismatch.');
localEnergy = conv(reference.^2,ones(cfg.windowLength,1)/cfg.windowLength,'same');
relative_dB = 10*log10((localEnergy+eps)/(max(localEnergy)+eps));
t = (0:numel(reference)-1)'/fs;
calibration = t >= noiseInterval_s(1) & t < noiseInterval_s(2);
noiseMask = relative_dB <= cfg.referenceNoiseThreshold_dB & ~calibration;
speechMask = relative_dB >= cfg.referenceSpeechThreshold_dB & ~calibration;
assert(nnz(noiseMask)>0 && nnz(speechMask)>0, 'Missing evaluation intervals.');
% SpEAR's documented variance-ratio convention. This penalises distortion
% and includes the small room re-recording mismatch in the reference.
m.referenceSNR_dB = 10*log10((var(reference,1)+eps)/ ...
    (var(processed-reference,1)+eps));
m.nonSpeechAttenuation_dB = 10*log10((mean(original(noiseMask).^2)+eps)/ ...
    (mean(processed(noiseMask).^2)+eps));
% Speech-interval total level change is a proxy, not a listening score.
m.speechLevelChange_dB = 10*log10((mean(processed(speechMask).^2)+eps)/ ...
    (mean(original(speechMask).^2)+eps));
m.noiseEvaluation_s = nnz(noiseMask)/fs;
m.speechEvaluation_s = nnz(speechMask)/fs;
m.noiseMask = noiseMask; m.speechMask = speechMask;
end
