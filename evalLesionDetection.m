% EVALLESIONDETECTION  Tests segmentStructures.m's lesion detection
% (microaneurysms, hemorrhages, exudates) against IDRiD's real hand-drawn
% ground truth masks, across several images at once, and reports a Dice
% score per lesion type so we can calibrate thresholds properly.

base = fullfile('A. Segmentation', 'A. Segmentation');
images_folder = fullfile(base, '1. Original Images', 'a. Training Set');
gt_folder = fullfile(base, '2. All Segmentation Groundtruths', 'a. Training Set');

ma_folder = fullfile(gt_folder, '1. Microaneurysms');
he_folder = fullfile(gt_folder, '2. Haemorrhages');
ex_hard_folder = fullfile(gt_folder, '3. Hard Exudates');
ex_soft_folder = fullfile(gt_folder, '4. Soft Exudates');

if ~isfolder(images_folder)
    error('Images folder not found:\n%s\nCheck your A. Segmentation folder path.', images_folder);
end

test_image_numbers = [1, 5, 10];  % a few images at once, not one at a time

ma_dice = zeros(size(test_image_numbers));
he_dice = zeros(size(test_image_numbers));
ex_dice = zeros(size(test_image_numbers));

figure('Name', 'Lesion Detection vs Ground Truth');

for i = 1:numel(test_image_numbers)
    n = test_image_numbers(i);
    num_str = sprintf('%02d', n);

    img_path = fullfile(images_folder, ['IDRiD_' num_str '.jpg']);
    if ~isfile(img_path)
        fprintf('Image %d not found, skipping.\n', n);
        continue;
    end
    image = imread(img_path);

    structures = segmentStructures(image);

    % --- Microaneurysms ---
    ma_gt_path = fullfile(ma_folder, ['IDRiD_' num_str '_MA.tif']);
    if isfile(ma_gt_path)
        ma_gt = imread(ma_gt_path) > 0;
        ma_pred = structures.lesion_map.microaneurysms;
        inter = sum(ma_pred(:) & ma_gt(:));
        ma_dice(i) = 2 * inter / (sum(ma_pred(:)) + sum(ma_gt(:)) + eps);
    end

    % --- Hemorrhages ---
    he_gt_path = fullfile(he_folder, ['IDRiD_' num_str '_HE.tif']);
    if isfile(he_gt_path)
        he_gt = imread(he_gt_path) > 0;
        he_pred = structures.lesion_map.hemorrhages;
        inter = sum(he_pred(:) & he_gt(:));
        he_dice(i) = 2 * inter / (sum(he_pred(:)) + sum(he_gt(:)) + eps);
    end

    % --- Exudates (combine hard + soft ground truth, since our detector
    % doesn't currently distinguish between the two) ---
    ex_gt = false(size(rgb2gray(image)));
    ex_hard_path = fullfile(ex_hard_folder, ['IDRiD_' num_str '_EX.tif']);
    ex_soft_path = fullfile(ex_soft_folder, ['IDRiD_' num_str '_SE.tif']);
    if isfile(ex_hard_path)
        ex_gt = ex_gt | (imread(ex_hard_path) > 0);
    end
    if isfile(ex_soft_path)
        ex_gt = ex_gt | (imread(ex_soft_path) > 0);
    end
    ex_pred = structures.lesion_map.exudates;
    inter = sum(ex_pred(:) & ex_gt(:));
    ex_dice(i) = 2 * inter / (sum(ex_pred(:)) + sum(ex_gt(:)) + eps);

    fprintf('Image %s: MA Dice=%.3f | HE Dice=%.3f | EX Dice=%.3f\n', ...
        num_str, ma_dice(i), he_dice(i), ex_dice(i));

    subplot(numel(test_image_numbers), 2, (i-1)*2 + 1);
    imshow(image); title(sprintf('Image %s - Original', num_str));

    combined_pred = structures.lesion_map.microaneurysms | structures.lesion_map.hemorrhages | structures.lesion_map.exudates;
    combined_gt = false(size(ex_gt));
    if isfile(ma_gt_path); combined_gt = combined_gt | (imread(ma_gt_path) > 0); end
    if isfile(he_gt_path); combined_gt = combined_gt | (imread(he_gt_path) > 0); end
    combined_gt = combined_gt | ex_gt;

    subplot(numel(test_image_numbers), 2, (i-1)*2 + 2);
    comparison = cat(3, double(combined_pred), double(combined_gt), zeros(size(combined_gt)));
    imshow(comparison); title('Red=ours, Green=truth, Yellow=both match');
end

fprintf('\n--- Averages ---\n');
fprintf('Microaneurysms Dice: %.3f\n', mean(ma_dice(ma_dice > 0)));
fprintf('Hemorrhages Dice: %.3f\n', mean(he_dice(he_dice > 0)));
fprintf('Exudates Dice: %.3f\n', mean(ex_dice(ex_dice > 0)));
fprintf('\n(Lesion segmentation is a genuinely hard task - published research\n');
fprintf('often reports 0.3-0.5 Dice for microaneurysms specifically, since they''re\n');
fprintf('tiny; exudates/hemorrhages are usually easier, often 0.5-0.7.)\n');
