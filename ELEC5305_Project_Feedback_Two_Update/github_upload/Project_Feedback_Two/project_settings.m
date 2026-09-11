function cfg = project_settings()
%PROJECT_SETTINGS Fixed settings for an offline pilot, not tuned per outcome.
cfg.fs = 16000;
cfg.windowLength = 400;          % 25 ms
cfg.hopLength = 160;             % 10 ms
cfg.nfft = 512;
cfg.noiseAlpha = 0.90;           % Update only during likely non-speech
cfg.vadThreshold_dB = 3;
cfg.hangoverFrames = 5;          % Protect 50 ms after a speech decision
cfg.gainFloor = 0.10;
cfg.gainAlpha = 0.60;            % Same gain smoothing for both methods
cfg.referenceNoiseThreshold_dB = -35;
cfg.referenceSpeechThreshold_dB = -25;
% Short, low-reference-energy intervals in these existing recordings.
% These are late calibration pauses, not 5-10 s opening noise recordings.
% Both methods receive exactly the same frozen annotation for each utterance.
cfg.utterances = {'butter','scholars'};
cfg.environments = {'factory','volvo'};
cfg.noiseIntervals_s = [2.42 2.50; 1.90 2.20];
end
