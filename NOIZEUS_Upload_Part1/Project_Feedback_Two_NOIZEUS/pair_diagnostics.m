function [row, frame] = pair_diagnostics(clean, noisy, trace, cfg)
% Reference-only diagnostics. No values here are passed into the enhancer.
L = trace.windowLength;
starts = trace.frameStartSample;
valid = trace.valid;
frame.cleanPower_dB = NaN(size(starts));
frame.residualPower_dB = NaN(size(starts));
for k = find(valid)'
    ix = starts(k)+(0:L-1);
    frame.cleanPower_dB(k) = 10*log10(max(mean(clean(ix).^2),realmin));
    frame.residualPower_dB(k) = ...
        10*log10(max(mean((noisy(ix)-clean(ix)).^2),realmin));
end
assert(any(valid), 'No valid evaluation frames.');
peak = max(frame.cleanPower_dB(valid));
frame.cleanRelative_dB = frame.cleanPower_dB-peak;
frame.speechProxy = valid & frame.cleanRelative_dB >= cfg.cleanSpeechProxy_dB;
frame.nonSpeechProxy = valid & frame.cleanRelative_dB <= cfg.cleanNonSpeechProxy_dB;
% The middle 10 dB band is unlabelled. These are energy proxies, not gold VAD.
row.NoiseVariation_dB = linear_percentile(frame.residualPower_dB(valid),90) - ...
    linear_percentile(frame.residualPower_dB(valid),10);
row.ProxySpeechFrames = sum(frame.speechProxy);
row.ProxyNonSpeechFrames = sum(frame.nonSpeechProxy);
row.ValidFrames = sum(valid);
ix = 1:trace.initialSamples;
row.InitialCleanToResidual_dB = ...
    10*log10(max(sum(clean(ix).^2),realmin)/max(sum((noisy(ix)-clean(ix)).^2),realmin));
row.InputWholeRecordSNR_dB = ...
    10*log10(sum(clean.^2)/sum((noisy-clean).^2));
end

function value = linear_percentile(x, p)
x = sort(x(:));
position = 1+(numel(x)-1)*p/100;
lo = floor(position);
hi = ceil(position);
value = x(lo)+(position-lo)*(x(hi)-x(lo));
end
