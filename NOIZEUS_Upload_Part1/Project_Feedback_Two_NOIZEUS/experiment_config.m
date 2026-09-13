function cfg = experiment_config()
% Frozen first experiment. Set before viewing enhancement results.
cfg.protocolVersion = '2026-09-12-v1';
cfg.utterances = {'sp01','sp06','sp11','sp16','sp21','sp26'};
cfg.development = {'sp01','sp16'};
cfg.evaluation = {'sp06','sp11','sp21','sp26'};
cfg.noises = {'car','street'};
cfg.nominalSNRs = [0 5 10 15];
cfg.fs = 8000;
cfg.initialSeconds = 0.10;
cfg.windowSeconds = 0.025;
cfg.shiftFraction = 0.4;
cfg.priorSmoothing = 0.99;
cfg.posteriorFloor = 0.1;
cfg.gainFloor = 0.15;
cfg.noiseSmoothing = 0.95;
cfg.vadThreshold_dB = 3;
cfg.hangoverFrames = 5;
cfg.psdFloorRelative = 1e-12;
cfg.cleanSpeechProxy_dB = -30;
cfg.cleanNonSpeechProxy_dB = -40;
cfg.legacyReproduction = false;
cfg.figureUtterance = 'sp06';
cfg.figureSNR = 5;
end
