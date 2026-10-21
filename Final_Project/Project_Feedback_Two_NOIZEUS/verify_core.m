function report = verify_core(root, cfg)
% Meaningful native MATLAB gates, executed before the experiment.
saved = load(fullfile(root,'original_reference','Scalart_Original_Run.mat'));
legacy = cfg;
legacy.initialSeconds = 10000/double(saved.fs);
legacy.legacyReproduction = true;
[actual, ~] = tsnr_enhance(double(saved.x(:)), double(saved.fs), legacy, 'fixed');
report.LegacyTSNRMaxAbsError = max(abs(actual-double(saved.esTSNR(:))));
assert(report.LegacyTSNRMaxAbsError < 1e-10, ...
    'The TSNR adaptation does not reproduce the saved author-code run.');

report.IdentityMaxRelativeError = 0;
for k = 1:numel(cfg.utterances)
    [x,fs] = audioread(fullfile(root,'data','clean',[cfg.utterances{k} '.wav']));
    [y,~] = tsnr_enhance(x,fs,cfg,'identity');
    err = norm(y-x)/max(norm(x),realmin);
    report.IdentityMaxRelativeError = max(report.IdentityMaxRelativeError,err);
end
assert(report.IdentityMaxRelativeError < 1e-12, 'Unity gain reconstruction failed.');

[x,fs] = audioread(fullfile(root,'data','car','0dB','sp01_car_sn0.wav'));
[fixed,tf] = tsnr_enhance(x,fs,cfg,'fixed');
frozen = cfg;
frozen.noiseSmoothing = 1;
[vad,tv] = tsnr_enhance(x,fs,frozen,'vad');
report.FrozenUpdateMaxAbsError = max(abs(fixed-vad));
assert(report.FrozenUpdateMaxAbsError < 1e-12, ...
    'The two paths differ even when noise updates are disabled.');
assert(isequal(tf.initialPSD,tv.initialPSD) && isequal(tf.finalPSD,tv.finalPSD));
assert(~any(tf.noiseUpdated), 'Fixed mode updated the PSD.');
reference = load(fullfile(root,'verification','python_reference.mat'));
[adaptive,~] = tsnr_enhance(x,fs,cfg,'vad');
report.CrossLanguageFixedMaxAbsError = max(abs(fixed-reference.fixed));
report.CrossLanguageVADMaxAbsError = max(abs(adaptive-reference.vad));
assert(report.CrossLanguageFixedMaxAbsError<1e-10 && ...
    report.CrossLanguageVADMaxAbsError<1e-10, 'Cross-language preflight differs.');
report.SNRKnownError = abs(measure_snr(x,x*2));
assert(report.SNRKnownError < 1e-12, 'Reference SNR sanity check failed.');
[zero,~] = tsnr_enhance(zeros(size(x)),fs,cfg,'vad');
assert(all(zero==0), 'Silent-input handling failed.');
report.Passed = true;
fprintf('Verification passed: source TSNR, reconstruction, controlled update and SNR.\n');
end
