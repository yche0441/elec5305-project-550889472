function [enhanced, trace] = tsnr_enhance(noisy, fs, cfg, mode)
% TSNR_ENHANCE Controlled adaptation of the existing TSNR implementation.
% Derived from WienerNoiseReduction.m by LIU Ming / Pascal Scalart.
% Original copyright, conditions and disclaimer: license.txt.
% Reference: Plapous, Marro and Scalart (2006), doi:10.1109/TASL.2006.872621.
% The clean reference is deliberately not an input to this function.
% fixed/vad share every operation except recursive noise-PSD updating.
% identity and legacyReproduction are verification modes, not extra systems.

validateattributes(noisy, {'double'}, {'column','real','finite','nonempty'});
assert(any(strcmp(mode, {'fixed','vad','identity'})), 'Unknown mode.');
assert(fs == cfg.fs, 'Use the unchanged 8 kHz corpus.');
L = fix(cfg.windowSeconds * fs);
nfft = 2 * L;
hop = L - fix((1-cfg.shiftFraction)*L);
assert(mod(L,2) == 0, 'The source gain constraint requires an even window.');
initialSamples = round(cfg.initialSeconds * fs);
assert(initialSamples >= L && numel(noisy) >= initialSamples+nfft, ...
    'Recording or initial noise interval is too short.');
% Explicit legacy hanning convention, verified against the uploaded native run.
window = 0.5 - 0.5*cos(2*pi*(1:L)'/(L+1));
noisePSD = zeros(nfft,1);
for k = 0:initialSamples-L
    spectrum = fft(noisy(k+(1:L)).*window, nfft);
    noisePSD = noisePSD + abs(spectrum).^2;
end
noisePSD = noisePSD / (initialSamples-L+1);
psdFloor = max(realmin, cfg.psdFloorRelative * mean(noisePSD));
noisePSD = max(noisePSD, psdFloor);
initialPSD = noisePSD;

if cfg.legacyReproduction
    assert(strcmp(mode,'fixed'), 'Legacy verification uses fixed noise only.');
    leftPad = 0;
    work = noisy;
else
    leftPad = L;
    work = [zeros(leftPad,1); noisy; zeros(2*L,1)];
end
starts = (1:hop:numel(work)-nfft+1)';
accumulator = zeros(size(work));
weights = zeros(size(work));
previousMagnitude = zeros(nfft,1);
holdFrames = 0;
count = numel(starts);
trace.frameStartSample = starts-leftPad;
trace.time_s = (trace.frameStartSample-1+(L-1)/2)/fs;
trace.valid = trace.frameStartSample > initialSamples & ...
    trace.frameStartSample+L-1 <= numel(noisy);
trace.energyRatio_dB = zeros(count,1);
trace.speechDecision = false(count,1);
trace.noiseUpdated = false(count,1);
trace.noisePower = zeros(count,1);
trace.windowLength = L;
trace.hop = hop;
trace.initialSamples = initialSamples;
trace.initialPSD = initialPSD;

for k = 1:count
    b = starts(k);
    spectrum = fft(work(b+(0:L-1)).*window, nfft);
    magnitude = abs(spectrum);
    power = magnitude.^2;
    ratioDB = 10*log10(max(sum(power),realmin)/max(sum(noisePSD),realmin));
    if ratioDB > cfg.vadThreshold_dB
        speech = true;
        holdFrames = cfg.hangoverFrames;
    elseif holdFrames > 0
        speech = true;
        holdFrames = holdFrames-1;
    else
        speech = false;
    end
    trace.energyRatio_dB(k) = ratioDB;
    trace.speechDecision(k) = speech;
    trace.noisePower(k) = sum(noisePSD);

    if strcmp(mode,'identity')
        newMagnitude = magnitude;
    else
        % Source TSNR branch: DD prior -> first Wiener gain -> second SNR/gain.
        post = max(power./noisePSD-1, cfg.posteriorFloor);
        prior = cfg.priorSmoothing*(previousMagnitude.^2./noisePSD) + ...
            (1-cfg.priorSmoothing)*post;
        preliminaryMagnitude = prior./(prior+1).*magnitude;
        secondSNR = preliminaryMagnitude.^2./noisePSD;
        gain = max(secondSNR./(secondSNR+1), cfg.gainFloor);
        gain = source_gain_control(gain, L);
        newMagnitude = gain.*magnitude;
    end
    previousMagnitude = abs(newMagnitude);
    block = real(ifft(newMagnitude.*exp(1i*angle(spectrum)), nfft));
    if cfg.legacyReproduction
        accumulator(b+(0:nfft-1)) = accumulator(b+(0:nfft-1)) + ...
            block*cfg.shiftFraction;
    else
        accumulator(b+(0:nfft-1)) = accumulator(b+(0:nfft-1)) + block;
        weights(b+(0:L-1)) = weights(b+(0:L-1)) + window;
    end

    % The only experimental difference: update AFTER this frame for the next.
    % Calibration frames and computational padding never update the PSD.
    if strcmp(mode,'vad') && trace.valid(k) && ~speech
        noisePSD = cfg.noiseSmoothing*noisePSD + ...
            (1-cfg.noiseSmoothing)*power;
        noisePSD = max(noisePSD, psdFloor);
        trace.noiseUpdated(k) = true;
    end
end

if cfg.legacyReproduction
    enhanced = accumulator;
    peak = max(abs(enhanced));
    if peak > 0
        enhanced = enhanced * (max(abs(noisy))/peak);
    end
else
    indices = leftPad+(1:numel(noisy));
    assert(all(weights(indices)>0), 'Incomplete overlap-add coverage.');
    enhanced = accumulator(indices)./weights(indices);
end
enhanced = enhanced(:);
trace.finalPSD = noisePSD;
assert(numel(enhanced)==numel(noisy) && all(isfinite(enhanced)), ...
    'Invalid reconstruction.');
end

function constrainedGain = source_gain_control(gain, L)
% Same impulse constraint and energy normalization as the author source.
nfft = numel(gain);
half = L/2;
window = 0.54-0.46*cos(2*pi*(0:L-1)'/(L-1));
impulse = real(ifft(gain));
limited = [impulse(1:half).*window(half+1:L); ...
    zeros(nfft-L,1); impulse(nfft-half+1:nfft).*window(1:half)];
constrainedGain = abs(fft(limited,nfft));
denominator = mean(constrainedGain.^2);
if denominator > 0
    constrainedGain = constrainedGain*sqrt(mean(gain.^2)/denominator);
else
    constrainedGain = zeros(size(gain));
end
end
