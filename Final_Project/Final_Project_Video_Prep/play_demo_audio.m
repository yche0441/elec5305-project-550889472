function play_demo_audio()
% Explicit opt-in playback for demonstration, not a subjective listening test.
root=fileparts(mfilename('fullpath'));out=fullfile(root,'demo_generated');
files={'01_noisy_input.wav','02_fixed_noise_psd.wav','03_original_vad.wav','04_selected_vad.wav'};
labels={'1 of 4: Noisy input','2 of 4: Fixed noise PSD','3 of 4: Original VAD','4 of 4: Selected VAD'};
assert(isfile(fullfile(out,files{1})),'Run video_demo first.');
f=figure('Name','Audio demonstration','Color','w','Position',[180 180 820 320]);
for k=1:4
 clf(f);axes('Parent',f);axis off;
 text(0.5,0.65,labels{k},'HorizontalAlignment','center','FontSize',24,'FontWeight','bold');
 text(0.5,0.35,{'sp02 / street noise / nominal 5 dB','Same playback gain for all four signals','Illustrative playback; no subjective evaluation claim'},'HorizontalAlignment','center','FontSize',14);drawnow;
 fprintf('%s\n',labels{k});[y,fs]=audioread(fullfile(out,files{k}));playblocking(audioplayer(y,fs));pause(1);
end
fprintf('Audio demonstration finished.\n');
end
