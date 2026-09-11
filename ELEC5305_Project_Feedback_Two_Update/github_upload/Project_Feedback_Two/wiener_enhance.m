function [y, d] = wiener_enhance(x, fs, noiseInterval_s, mode, cfg)
%WIENER_ENHANCE Offline STFT Wiener enhancement with fixed or VAD updates.
% No clean reference is an input to this function. The noise-interval
% annotation is supplied to both methods before their outputs are compared.
% MODE: 'fixed', 'vad', or 'identity' (overlap-add verification).
% No generated noise, audio mixing, toolbox downloads, or external calls.

assert(any(strcmp(mode, {'fixed','vad','identity'})), 'Unknown method.');
x = double(x(:));
assert(fs == cfg.fs && all(isfinite(x)), 'Expected finite 16 kHz audio.');
L = cfg.windowLength; H = cfg.hopLength; K = cfg.nfft;
assert(K >= L && mod(K,2) == 0 && H <= L, 'Invalid STFT settings.');
assert(noiseInterval_s(1) >= 0 && noiseInterval_s(2) <= numel(x)/fs, ...
    'Noise interval must lie within the recording.');
window = 0.54 - 0.46*cos(2*pi*(0:L-1)'/(L-1));
pad = L;
nFrames = ceil((numel(x) + 2*pad - L)/H) + 1;
totalLength = (nFrames-1)*H + L;
buffer = zeros(totalLength,1);
buffer(pad+(1:numel(x))) = x;
frameStarts = (0:nFrames-1)*H;
spectra = zeros(K/2+1,nFrames);
for k = 1:nFrames
    idx = frameStarts(k) + (1:L);
    fullSpectrum = fft(buffer(idx).*window,K);
    spectra(:,k) = fullSpectrum(1:K/2+1);
end
powerSpectra = abs(spectra).^2;
frameBegin_s = (frameStarts-pad)/fs;
frameEnd_s = (frameStarts-pad+L)/fs;
complete = frameBegin_s >= 0 & frameEnd_s <= numel(x)/fs;
calibration = complete & frameBegin_s >= noiseInterval_s(1)-1e-12 & ...
    frameEnd_s <= noiseInterval_s(2)+1e-12;
assert(nnz(calibration) >= 3, 'At least three complete noise frames required.');
initialPSD = mean(powerSpectra(:,calibration),2);
powerFloor = max(max(initialPSD)*1e-12,eps);
noisePSD = max(initialPSD,powerFloor);
previousGain = ones(K/2+1,1);
enhanced = zeros(size(spectra));
speech = false(1,nFrames); updated = false(1,nFrames);
energyRatio_dB = zeros(1,nFrames); meanGain = zeros(1,nFrames);
noisePower = zeros(1,nFrames); holdFrames = 0;

for k = 1:nFrames
    observedPSD = powerSpectra(:,k);
    energyRatio_dB(k) = 10*log10((sum(observedPSD)+eps)/(sum(noisePSD)+eps));
    if energyRatio_dB(k) > cfg.vadThreshold_dB
        speech(k) = true;
        holdFrames = cfg.hangoverFrames;
    elseif holdFrames > 0
        speech(k) = true;
        holdFrames = holdFrames-1;
    end
    % Exclude padding and calibration frames from subsequent adaptation.
    if strcmp(mode,'vad') && complete(k) && ~calibration(k) && ~speech(k)
        noisePSD = max(cfg.noiseAlpha*noisePSD + ...
            (1-cfg.noiseAlpha)*observedPSD,powerFloor);
        updated(k) = true;
    end
    if strcmp(mode,'identity')
        gain = ones(K/2+1,1);
    else
        % Non-negative instantaneous a-priori SNR estimate.
        xi = max(observedPSD./noisePSD - 1,0);
        rawGain = max(xi./(1+xi),cfg.gainFloor);
        gain = cfg.gainAlpha*previousGain + (1-cfg.gainAlpha)*rawGain;
    end
    previousGain = gain;
    enhanced(:,k) = gain.*spectra(:,k); % Retain observed complex phase
    meanGain(k) = mean(gain);
    noisePower(k) = sum(noisePSD);
end

reconstructed = zeros(totalLength,1); windowWeight = zeros(totalLength,1);
for k = 1:nFrames
    fullSpectrum = [enhanced(:,k);conj(enhanced(end-1:-1:2,k))];
    frame = real(ifft(fullSpectrum,K));
    idx = frameStarts(k)+(1:L);
    reconstructed(idx) = reconstructed(idx)+frame(1:L).*window;
    windowWeight(idx) = windowWeight(idx)+window.^2;
end
crop = pad+(1:numel(x));
assert(all(windowWeight(crop)>0), 'Uncovered overlap-add samples.');
y = reconstructed(crop)./windowWeight(crop);
assert(numel(y)==numel(x) && all(isfinite(y)), 'Invalid reconstructed output.');
d.time_s = (frameStarts+L/2-pad)/fs;
d.complete = complete; d.calibration = calibration;
d.speech = speech; d.noiseUpdated = updated;
d.energyRatio_dB = energyRatio_dB;
d.meanGain = meanGain; d.noisePower = noisePower;
d.updateFraction = nnz(updated)/max(nnz(complete & ~calibration),1);
d.calibrationFrames = nnz(calibration);
end
