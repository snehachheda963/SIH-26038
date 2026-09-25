% TESTPIPELINE  Runs the full pipeline on every image in sample_images/
% and shows/saves the results. Just drop images into sample_images/ and
% run this script - no other setup needed.

image_folder = 'sample_images';
image_files = [dir(fullfile(image_folder, '*.jpg')); ...
               dir(fullfile(image_folder, '*.jpeg')); ...
               dir(fullfile(image_folder, '*.png'))];

if isempty(image_files)
    error(['No images found in %s/.\n' ...
           'Drop a few test images into that folder and run this again.'], image_folder);
end

fprintf('Found %d test image(s). Running pipeline...\n\n', numel(image_files));

results_table = table('Size', [0, 5], ...
    'VariableTypes', {'string', 'string', 'double', 'double', 'logical'}, ...
    'VariableNames', {'ImageName', 'Status', 'DR_Level', 'Confidence', 'Referable'});

for i = 1:numel(image_files)
    img_path = fullfile(image_files(i).folder, image_files(i).name);
    fprintf('Processing %s ... ', image_files(i).name);

    result = runPipeline(img_path);

    if strcmp(result.status, 'reject')
        fprintf('REJECTED (%s)\n', result.reject_reason);
        results_table = [results_table; {string(image_files(i).name), "reject", NaN, NaN, false}]; %#ok<AGROW>
        continue;
    end

    fprintf('DR Level %d (confidence %.2f)\n', result.dr_level, result.confidence_score);
    fprintf('%s\n\n', result.report_text);
    results_table = [results_table; {string(image_files(i).name), string(result.status), ...
        result.dr_level, result.confidence_score, result.is_referable}]; %#ok<AGROW>

    % Show the heatmap for a visual check (full report printed above instead -
    % a figure title isn't built for multi-sentence text and truncates it)
    figure('Name', image_files(i).name);
    imshow(result.heatmap_image);
    title(sprintf('%s - Level %d (%.0f%% confidence)', ...
        image_files(i).name, result.dr_level, result.confidence_score * 100), 'Interpreter', 'none');
end

fprintf('\n--- Summary ---\n');
disp(results_table);

% Save results to a CSV so you have a record for your report/presentation
writetable(results_table, 'pipeline_test_results.csv');
fprintf('\nResults saved to pipeline_test_results.csv\n');