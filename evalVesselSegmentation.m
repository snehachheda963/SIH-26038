% EVALVESSELSEGMENTATION  Tests segmentStructures.m's vessel detection
% against DRIVE's hand-drawn "correct answer" masks, and reports a Dice
% score (0-1, higher is better) so we can calibrate VESSEL_THRESHOLD
% properly instead of guessing.
%
% BEFORE RUNNING: make sure your DRIVE dataset folder is in this project
% folder (same place idrid_dataset is).

dataset_folder = dir('DRIVE*');
if isempty(dataset_folder)
    error('DRIVE dataset folder not found. Make sure it is inside your SIH26038 folder.');
end
dataset_name = dataset_folder(1).name;

images_folder = fullfile(dataset_name, 'training', 'training', 'images');
manual_folder = fullfile(dataset_name, 'training', 'training', '1st_manual');

% Test on a few images, not all 20, for a quick calibration check
test_image_numbers = [21, 25, 30];
dice_scores = zeros(size(test_image_numbers));

figure('Name', 'Vessel Segmentation vs Ground Truth');

for i = 1:numel(test_image_numbers)
    n = test_image_numbers(i);

    img_path = fullfile(images_folder, sprintf('%d_training.tif', n));
    truth_path = fullfile(manual_folder, sprintf('%d_manual1.gif', n));

    image = imread(img_path);
    ground_truth = imread(truth_path) > 0;  % convert to logical mask

    structures = segmentStructures(image);
    predicted_mask = structures.vessel_mask;

    % Resize ground truth to match if needed (should already match, but just in case)
    if ~isequal(size(predicted_mask), size(ground_truth))
        ground_truth = imresize(ground_truth, size(predicted_mask));
    end

    % Dice score: 2 * overlap / (predicted area + true area). 1.0 = perfect match.
    intersection = sum(predicted_mask(:) & ground_truth(:));
    dice_scores(i) = 2 * intersection / (sum(predicted_mask(:)) + sum(ground_truth(:)));

    fprintf('Image %d: Dice score = %.3f\n', n, dice_scores(i));

    subplot(numel(test_image_numbers), 3, (i-1)*3 + 1);
    imshow(image); title(sprintf('Image %d - Original', n));

    subplot(numel(test_image_numbers), 3, (i-1)*3 + 2);
    imshow(predicted_mask); title('Our prediction');

    subplot(numel(test_image_numbers), 3, (i-1)*3 + 3);
    imshow(ground_truth); title('Ground truth');
end

fprintf('\nAverage Dice score: %.3f\n', mean(dice_scores));
fprintf('(0.0 = no overlap, 1.0 = perfect match. Published vessel segmentation\n');
fprintf('research typically reports 0.75-0.82 on DRIVE - use that as a rough benchmark.)\n');
