function save_case_outputs(folder,caseID,entry,frame,cfg)
% Same STFT colour limits and shared audio playback gain for each quartet.
signals = {entry.clean,entry.noisy,entry.fixed,entry.vad};
names = {'Clean reference','Unprocessed','Fixed TSNR Wiener','VAD-updated TSNR Wiener'};
shortNames = {'clean','unprocessed','fixed','vad'};
L = fix(cfg.windowSeconds*entry.fs);
hop = L-fix((1-cfg.shiftFraction)*L);
window = 0.5-0.5*cos(2*pi*(1:L)'/(L+1));
nfft = 2*L;
starts = 1:hop:numel(entry.clean)-L+1;
allDB = cell(1,4);
maxDB = -Inf;
for j = 1:4
    spectrum = zeros(nfft/2+1,numel(starts));
    for k = 1:numel(starts)
        z = fft(signals{j}(starts(k)+(0:L-1)).*window,nfft);
        spectrum(:,k) = abs(z(1:nfft/2+1));
    end
    allDB{j} = 20*log10(max(spectrum/sum(window),1e-12));
    maxDB = max(maxDB,max(allDB{j}(:)));
end
f = figure('Visible','off','Color','w','Position',[100 100 1050 1000]);
cleanup = onCleanup(@() close(f));
for j = 1:4
    subplot(4,1,j);
    imagesc((starts-1+(L-1)/2)/entry.fs,(0:nfft/2)*entry.fs/nfft,allDB{j});
    axis xy;
    caxis([maxDB-70,maxDB]);
    colorbar;
    ylabel('Frequency (Hz)');
    title(names{j});
end
xlabel('Time (s)');
sgtitle([strrep(caseID,'_',' ') ' -- common magnitude dB scale']);
exportgraphics(f,fullfile(folder,'figures',[caseID '_spectrogram.png']),'Resolution',150);
clear cleanup

f = figure('Visible','off','Color','w','Position',[100 100 1050 700]);
cleanup = onCleanup(@() close(f)); %#ok<NASGU>
trace = entry.vadTrace;
valid = trace.valid;
subplot(3,1,1);
plot(trace.time_s(valid),trace.energyRatio_dB(valid),'b');
hold on; yline(cfg.vadThreshold_dB,'r:');
ylabel('Energy ratio (dB)'); grid on;
title('Noisy-frame energy / current noise estimate');
subplot(3,1,2);
plot(trace.time_s(valid),frame.cleanRelative_dB(valid),'k');
hold on;
yline(cfg.cleanSpeechProxy_dB,'g:');
yline(cfg.cleanNonSpeechProxy_dB,'r:');
ylabel('Clean relative power (dB)'); grid on;
title('Reference energy proxy used only for evaluation');
subplot(3,1,3);
stairs(trace.time_s(valid),double(trace.speechDecision(valid)),'b');
hold on;
stairs(trace.time_s(valid),double(trace.noiseUpdated(valid)),'r');
ylim([-0.1 1.1]); grid on;
legend('VAD speech decision','PSD update','Location','best');
xlabel('Time (s)'); ylabel('Decision');
sgtitle(strrep(caseID,'_',' '));
exportgraphics(f,fullfile(folder,'figures',[caseID '_vad.png']),'Resolution',150);

% Scientific metrics and saved MAT signals are unscaled. WAVs are copies.
peak = max(cellfun(@(x) max(abs(x)),signals));
playbackGain = min(1,0.99/max(peak,realmin));
for j = 1:4
    audiowrite(fullfile(folder,'listening',[caseID '_' shortNames{j} '.wav']), ...
        signals{j}*playbackGain,entry.fs,'BitsPerSample',24);
end
fid = fopen(fullfile(folder,'listening',[caseID '_gain.txt']),'w');
assert(fid~=-1);
fprintf(fid,'Common playback gain applied to all four WAV copies: %.17g\n',playbackGain);
fprintf(fid,'Metrics use the original unscaled double-precision signals in the MAT file.\n');
fclose(fid);
end
