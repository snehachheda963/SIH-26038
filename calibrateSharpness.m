% CALIBRATESHARPNESS  Checks the sharpness score across several real
% images at once, so we can set SHARPNESS_THRESHOLD properly instead of
% guessing from a single image.

image_files = dir(fullfile('sample_images', '*.jpg'));
% Also pull a few from your training data for a bigger, more reliable sample
training_files = dir(fullfile('data', 'train', '2', '*.jpg'));
if numel(training_files) > 5
    training_files = training_files(1:5);
end

fprintf('--- Sharpness scores on real, genuine (non-blurred) images ---\n');
real_scores = [];
for i = 1:numel(image_files)
    img = imread(fullfile(image_files(i).folder, image_files(i).name));
    gray_image = rgb2gray(img);
    normalized_gray = mat2gray(gray_image);
    lap = imfilter(normalized_gray, fspecial('laplacian'));
    score = var(lap(:));
    real_scores(end+1) = score; %#ok<AGROW>
    fprintf('%s: %.6f\n', image_files(i).name, score);
end
for i = 1:numel(training_files)
    img = imread(fullfile(training_files(i).folder, training_files(i).name));
    gray_image = rgb2gray(img);
    normalized_gray = mat2gray(gray_image);
    lap = imfilter(normalized_gray, fspecial('laplacian'));
    score = var(lap(:));
    real_scores(end+1) = score; %#ok<AGROW>
    fprintf('%s: %.6f\n', training_files(i).name, score);
end

fprintf('\n--- Sharpness score on a deliberately blurred version ---\n');
sample_img = imread(fullfile(image_files(1).folder, image_files(1).name));
blurry = imgaussfilt(sample_img, 8);
gray_blurry = rgb2gray(blurry);
lap_blurry = imfilter(mat2gray(gray_blurry), fspecial('laplacian'));
blurry_score = var(lap_blurry(:));
fprintf('Blurred test image: %.6f\n', blurry_score);

fprintf('\n--- Summary ---\n');
fprintf('Real images - min: %.6f, max: %.6f\n', min(real_scores), max(real_scores));
fprintf('Blurred image: %.6f\n', blurry_score);
suggested_threshold = (min(real_scores) + blurry_score) / 2;
fprintf('\nSuggested SHARPNESS_THRESHOLD: %.6f\n', suggested_threshold);
fprintf('(set roughly halfway between the lowest real image and the blurred one)\n');
