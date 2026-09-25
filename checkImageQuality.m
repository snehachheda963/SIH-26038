function [status, cleaned_image, reject_reason] = checkImageQuality(image)
% CHECKIMAGEQUALITY  Module 1 - Image Quality Assessment & Enhancement
%
% INPUT:
%   image  - a retina fundus image (read using imread)
%
% OUTPUT:
%   status         - 'pass' / 'enhanced' / 'reject'
%   cleaned_image  - the (possibly enhanced) image, ready for Module 2
%   reject_reason  - text explaining why an image was rejected

    reject_reason = '';
    cleaned_image = image;
    gray_image = rgb2gray(image);

    %% 1. Sharpness check (blur detection)
    % A sharp image has strong edges -> high variance after Laplacian filtering.
    % A blurry image has smooth transitions -> low variance.
    % IMPORTANT: normalize contrast first (mat2gray) so a simply-dark image
    % isn't mistaken for a blurry one - raw pixel values scale with
    % brightness, which would otherwise shrink the Laplacian variance too.
    normalized_gray = mat2gray(gray_image);
    laplacian_filtered = imfilter(normalized_gray, fspecial('laplacian'));
    sharpness_score = var(laplacian_filtered(:));
    % Threshold from calibration on the NORMALIZED scale across 8 real
    % images (range 0.000271-0.000681) vs a deliberately blurred one
    % (0.000079-0.000085) - set safely in the gap between them.
    SHARPNESS_THRESHOLD = 0.00018;

    %% 2. Illumination check (too dark / too bright / very uneven)
    mean_brightness = mean(gray_image(:));
    % Retina photos are naturally dark-backgrounded with a bright circular
    % field, so we check the brightness of just the retina region, not
    % the whole frame (which is mostly black background).
    retina_mask = gray_image > 10;  % rough retina-vs-background split
    if any(retina_mask(:))
        retina_brightness = mean(gray_image(retina_mask));
    else
        retina_brightness = mean_brightness;
    end
    % Calibrated from real debug output: two genuinely good images measured
    % 113.9 and 134.4; one visibly dark image measured 34.4. 25 let the dark
    % one slip through as "pass" - 60 sits safely below both good images and
    % safely above the dark one.
    TOO_DARK_THRESHOLD = 60;
    TOO_BRIGHT_THRESHOLD = 220;

    %% 3. Field of view check (is the retina fully visible and reasonably centered?)
    retina_mask_filled = imfill(retina_mask, 'holes');
    stats = regionprops(retina_mask_filled, 'Area', 'Centroid', 'BoundingBox');

    field_of_view_ok = false;
    area_fraction = 0;
    FIELD_MIN_FRACTION = 0.15;  % moved out here so it's always defined, even if stats is empty
    if ~isempty(stats)
        [~, biggest_idx] = max([stats.Area]);
        biggest_blob = stats(biggest_idx);
        image_area = numel(gray_image);
        % The retina field should cover a meaningful fraction of the frame -
        % if it's tiny, the camera was likely too far away or badly aimed.
        area_fraction = biggest_blob.Area / image_area;
        field_of_view_ok = area_fraction >= FIELD_MIN_FRACTION;
    end

    %% Decision logic
    fprintf('[DEBUG] sharpness=%.5f (threshold=%.5f) | brightness=%.1f (dark<%.0f, bright>%.0f) | area_fraction=%.3f (min=%.2f)\n', ...
        sharpness_score, SHARPNESS_THRESHOLD, retina_brightness, TOO_DARK_THRESHOLD, TOO_BRIGHT_THRESHOLD, ...
        area_fraction, FIELD_MIN_FRACTION);

    if sharpness_score < SHARPNESS_THRESHOLD
        status = 'reject';
        cleaned_image = [];
        reject_reason = 'Image too blurry. Please retake with a steadier hand or better focus.';
        return;
    end

    if ~field_of_view_ok
        status = 'reject';
        cleaned_image = [];
        reject_reason = 'Retina not fully visible in frame. Please retake, centering the eye.';
        return;
    end

    needs_enhancement = (retina_brightness < TOO_DARK_THRESHOLD) || ...
                         (retina_brightness > TOO_BRIGHT_THRESHOLD);

    if needs_enhancement
        %% Enhancement: CLAHE (contrast) applied per RGB channel + denoising
        % NOTE: CLAHE amplifies sensor/JPEG noise along with real detail,
        % especially on dark images. Tried fixing this purely with a
        % stronger post-blur (0.5 -> 1.2 sigma) - that helped vessel
        % detection (fibermetric, looking for lines) but made lesion
        % detection worse (imtophat looks for round blobs, and blurred
        % noise smooths into exactly that blob shape). So: attack the
        % noise at the source instead - a lower ClipLimit boosts contrast
        % less aggressively, meaning less noise gets amplified to begin
        % with, rather than trying to filter it out after the fact.
        enhanced = image;
        for c = 1:size(image, 3)
            enhanced(:, :, c) = adapthisteq(image(:, :, c), 'ClipLimit', 0.006);  % was 0.01
        end
        cleaned_image = imgaussfilt(enhanced, 1.2);  % kept - this part helped vessel detection
        status = 'enhanced';
        return;
    end

    status = 'pass';
end