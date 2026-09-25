% CALIBRATELESIONTHRESHOLDS  Measures the actual top-hat filter values
% INSIDE real lesion regions (from ground truth) versus OUTSIDE (normal
% tissue), across several images, so we can set MA_THRESHOLD, HE_THRESHOLD,
% and EX_THRESHOLD from real data instead of guessing.

base = fullfile('A. Segmentation', 'A. Segmentation');
images_folder = fullfile(base, '1. Original Images', 'a. Training Set');
gt_folder = fullfile(base, '2. All Segmentation Groundtruths', 'a. Training Set');

ma_folder = fullfile(gt_folder, '1. Microaneurysms');
he_folder = fullfile(gt_folder, '2. Haemorrhages');
ex_hard_folder = fullfile(gt_folder, '3. Hard Exudates');
ex_soft_folder = fullfile(gt_folder, '4. Soft Exudates');

test_image_numbers = [1, 5, 10];

all_ma_inside = []; all_ma_outside = [];
all_he_inside = []; all_he_outside = [];
all_ex_inside = []; all_ex_outside = [];

for i = 1:numel(test_image_numbers)
    n = test_image_numbers(i);
    num_str = sprintf('%02d', n);

    img_path = fullfile(images_folder, ['IDRiD_' num_str '.jpg']);
    if ~isfile(img_path)
        continue;
    end
    image = imread(img_path);
    gray_image = rgb2gray(image);
    retina_mask = imerode(imfill(gray_image > 10, 'holes'), strel('disk', 5));
    green_channel = imadjust(image(:, :, 2));
    inverted_green = imcomplement(green_channel);

    ma_enhanced = imtophat(inverted_green, strel('disk', 4));
    he_enhanced = imtophat(inverted_green, strel('disk', 12));
    ex_enhanced = imtophat(green_channel, strel('disk', 15));

    % Microaneurysms
    ma_gt_path = fullfile(ma_folder, ['IDRiD_' num_str '_MA.tif']);
    if isfile(ma_gt_path)
        ma_gt = imread(ma_gt_path) > 0;
        inside_vals = ma_enhanced(ma_gt);
        outside_vals = ma_enhanced(retina_mask & ~ma_gt);
        all_ma_inside = [all_ma_inside; inside_vals(:)]; %#ok<AGROW>
        all_ma_outside = [all_ma_outside; outside_vals(:)]; %#ok<AGROW>
    end

    % Hemorrhages
    he_gt_path = fullfile(he_folder, ['IDRiD_' num_str '_HE.tif']);
    if isfile(he_gt_path)
        he_gt = imread(he_gt_path) > 0;
        inside_vals = he_enhanced(he_gt);
        outside_vals = he_enhanced(retina_mask & ~he_gt);
        all_he_inside = [all_he_inside; inside_vals(:)]; %#ok<AGROW>
        all_he_outside = [all_he_outside; outside_vals(:)]; %#ok<AGROW>
    end

    % Exudates (hard + soft combined)
    ex_gt = false(size(gray_image));
    ex_hard_path = fullfile(ex_hard_folder, ['IDRiD_' num_str '_EX.tif']);
    ex_soft_path = fullfile(ex_soft_folder, ['IDRiD_' num_str '_SE.tif']);
    if isfile(ex_hard_path); ex_gt = ex_gt | (imread(ex_hard_path) > 0); end
    if isfile(ex_soft_path); ex_gt = ex_gt | (imread(ex_soft_path) > 0); end
    if any(ex_gt(:))
        inside_vals = ex_enhanced(ex_gt);
        outside_vals = ex_enhanced(retina_mask & ~ex_gt);
        all_ex_inside = [all_ex_inside; inside_vals(:)]; %#ok<AGROW>
        all_ex_outside = [all_ex_outside; outside_vals(:)]; %#ok<AGROW>
    end
end

fprintf('=== Microaneurysms ===\n');
fprintf('Inside true MA regions  - median: %.1f, 25th pct: %.1f\n', median(all_ma_inside), prctile(all_ma_inside, 25));
fprintf('Outside (normal tissue) - median: %.1f, 90th pct: %.1f, 99th pct: %.1f\n', ...
    median(all_ma_outside), prctile(all_ma_outside, 90), prctile(all_ma_outside, 99));

fprintf('\n=== Hemorrhages ===\n');
fprintf('Inside true HE regions  - median: %.1f, 25th pct: %.1f\n', median(all_he_inside), prctile(all_he_inside, 25));
fprintf('Outside (normal tissue) - median: %.1f, 90th pct: %.1f, 99th pct: %.1f\n', ...
    median(all_he_outside), prctile(all_he_outside, 90), prctile(all_he_outside, 99));

fprintf('\n=== Exudates ===\n');
fprintf('Inside true EX regions  - median: %.1f, 25th pct: %.1f\n', median(all_ex_inside), prctile(all_ex_inside, 25));
fprintf('Outside (normal tissue) - median: %.1f, 90th pct: %.1f, 99th pct: %.1f\n', ...
    median(all_ex_outside), prctile(all_ex_outside, 90), prctile(all_ex_outside, 99));

fprintf('\nSuggested thresholds (roughly between "outside 90th pct" and "inside 25th pct"):\n');
fprintf('MA_THRESHOLD suggestion: %.1f\n', (prctile(all_ma_outside, 90) + prctile(all_ma_inside, 25)) / 2);
fprintf('HE_THRESHOLD suggestion: %.1f\n', (prctile(all_he_outside, 90) + prctile(all_he_inside, 25)) / 2);
fprintf('EX_THRESHOLD suggestion: %.1f\n', (prctile(all_ex_outside, 90) + prctile(all_ex_inside, 25)) / 2);
