function show_controlled_results()
% Display saved controlled-study results. This does not recompute the study.
root=fileparts(mfilename('fullpath'));
names={'paired_effects.png','tracking_example.png'};
titles={'Stored controlled study: paired sentence effects', ...
    'Stored controlled study: known noise change and estimated noise power'};
for k=1:numel(names)
    source=fullfile(root,'controlled_study',names{k});
    assert(isfile(source),'Missing controlled-study result: %s',source);
    pixels=imread(source);
    figure('Name',titles{k},'Color','w','Position',[70 60 1250 820]);
    image(pixels);axis image off;
    title(titles{k},'Interpreter','none');
end
fprintf('Showing STORED results from 36 matched mixtures / 144 method rows.\n');
fprintf('No new experiment was run by this display command.\n');
end
