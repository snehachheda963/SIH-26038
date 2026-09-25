function structures = segmentStructures(cleaned_image)
% SEGMENTSTRUCTURES  Module 2 - Retinal Structure Segmentation
%
% INPUT:
%   cleaned_image - the 'cleaned_image' output from checkImageQuality.m
%
% OUTPUT:
%   structures - struct with fields:
%       .vessel_mask          - binary mask marking blood vessels
%       .optic_disc_location  - [x, y] center coordinates of the optic disc
%       .lesion_map           - struct of lesion masks:
%             .microaneurysms      - small dark dots (earliest DR sign)
%             .hemorrhages         - larger dark blotches
%             .exudates            - bright yellow/white deposits (hard + soft combined)
%             .neovascularization  - still placeholder, no labeled dataset available for this
%
% NOTE ON THRESHOLDS: lesion thresholds are calculated ADAPTIVELY per image
% (mean + k*std of that image's own filter response), not as one fixed
% number - a fixed threshold badly over/under-fires across images with
% different brightness/contrast, which is what we saw and fixed here.

    gray_image = rgb2gray(cleaned_image);

    %% Rough retina-vs-background mask
    retina_mask = gray_image > 10;
    retina_mask = imfill(retina_mask, 'holes');
    retina_mask = imerode(retina_mask, strel('disk', 5));

    %% 1. Optic disc localization (done first so we can exclude it below)
    green_channel = imadjust(cleaned_image(:, :, 2));
    smoothed = imgaussfilt(green_channel, 15);
    smoothed(~retina_mask) = 0;
    [~, max_idx] = max(smoothed(:));
    [disc_row, disc_col] = ind2sub(size(smoothed), max_idx);
    optic_disc_location = [disc_col, disc_row];

    [xx, yy] = meshgrid(1:size(gray_image, 2), 1:size(gray_image, 1));
    OPTIC_DISC_EXCLUSION_RADIUS = 60;
    optic_disc_exclusion = sqrt((xx - disc_col).^2 + (yy - disc_row).^2) <= OPTIC_DISC_EXCLUSION_RADIUS;

    %% 2. Vessel segmentation (unchanged)
    vessel_enhanced = fibermetric(green_channel, 'ObjectPolarity', 'dark');
    VESSEL_THRESHOLD = 0.30;
    vessel_mask = (vessel_enhanced > VESSEL_THRESHOLD) & retina_mask & ~optic_disc_exclusion;
    vessel_mask = bwareaopen(vessel_mask, 50);

    valid_region = retina_mask & ~optic_disc_exclusion & ~vessel_mask;

    %% 3. Microaneurysms - tiny, round, dark red dots
    inverted_green = imcomplement(green_channel);
    ma_enhanced = imtophat(inverted_green, strel('disk', 4));

    ma_region_vals = ma_enhanced(valid_region);
    MA_K = 4.5;  % raised from 3.5 - was letting through far too many noise specks on some images
    MA_THRESHOLD = mean(ma_region_vals) + MA_K * std(double(ma_region_vals));

    ma_candidates = (ma_enhanced > MA_THRESHOLD) & valid_region;

    ma_stats = regionprops(ma_candidates, 'Area', 'Circularity', 'PixelIdxList');
    microaneurysms = false(size(gray_image));
    for k = 1:numel(ma_stats)
        if ma_stats(k).Area >= 3 && ma_stats(k).Area <= 60 && ma_stats(k).Circularity > 0.6
            microaneurysms(ma_stats(k).PixelIdxList) = true;
        end
    end

    %% 4. Hemorrhages - larger, irregular dark blotches
    he_enhanced = imtophat(inverted_green, strel('disk', 12));

    he_region_vals = he_enhanced(valid_region);
    HE_K = 3.0;
    HE_THRESHOLD = mean(he_region_vals) + HE_K * std(double(he_region_vals));

    he_candidates = (he_enhanced > HE_THRESHOLD) & valid_region;

    he_stats = regionprops(he_candidates, 'Area', 'PixelIdxList');
    hemorrhages = false(size(gray_image));
    for k = 1:numel(he_stats)
        if he_stats(k).Area > 60 && he_stats(k).Area <= 3000
            hemorrhages(he_stats(k).PixelIdxList) = true;
        end
    end

    %% 5. Exudates (hard + soft combined) - bright yellow/white deposits
    ex_enhanced = imtophat(green_channel, strel('disk', 30));

    ex_region_vals = ex_enhanced(valid_region);
    EX_K = 3.0;
    EX_THRESHOLD = mean(ex_region_vals) + EX_K * std(double(ex_region_vals));

    exudates = (ex_enhanced > EX_THRESHOLD) & valid_region;
    exudates = bwareaopen(exudates, 15);

    %% 6. Neovascularization - still placeholder (no labeled dataset available)
    neovascularization = false(size(gray_image));

    lesion_map = struct( ...
        'microaneurysms', microaneurysms, ...
        'hemorrhages', hemorrhages, ...
        'exudates', exudates, ...
        'neovascularization', neovascularization);

    structures = struct( ...
        'vessel_mask', vessel_mask, ...
        'optic_disc_location', optic_disc_location, ...
        'lesion_map', lesion_map);
end