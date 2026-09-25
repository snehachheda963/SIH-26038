function [heatmap_image, report_text] = explainResult(image, dr_level, confidence_score, net, structures, quality_status)
% EXPLAINRESULT  Module 4 - Explainability (Grad-CAM + full report)
%
% INPUT:
%   image             - the cleaned retina image
%   dr_level          - predicted DR level from gradeDR.m
%   confidence_score  - the model's confidence (0-1) from gradeDR.m
%   net               - the trained network used for grading
%   structures        - the struct from segmentStructures.m (vessels, lesions, optic disc)
%   quality_status    - 'pass' or 'enhanced' from checkImageQuality.m
%
% OUTPUT:
%   heatmap_image - Grad-CAM heatmap overlay
%   report_text   - a full, multi-line clinical-style summary

    if isempty(net)
        heatmap_image = image;
        report_text = 'Report unavailable: model not yet trained.';
        return;
    end

    resized_image = imresize(image, net.Layers(1).InputSize(1:2));
    if size(resized_image, 3) == 1
        resized_image = repmat(resized_image, 1, 1, 3);
    end

    % ---- Grad-CAM heatmap (layer auto-selected, works for any architecture) ----
    scoreMap = gradCAM(net, resized_image, dr_level + 1);
    scoreMap = rescale(scoreMap);
    heatmapColor = ind2rgb(im2uint8(scoreMap), jet(256));
    alpha_mask = scoreMap * 0.55;
    heatmap_image = im2double(resized_image) .* (1 - alpha_mask) + heatmapColor .* alpha_mask;

    % ---- Build the full report ----
    severity_names = {'No DR', 'Mild', 'Moderate', 'Severe', 'Proliferative DR'};
    is_referable = dr_level >= 2;

    if is_referable
        recommendation = 'REFER to an ophthalmologist for confirmatory examination.';
    elseif dr_level == 1
        recommendation = 'Recommend rescreening within 6-12 months.';
    else
        recommendation = 'Recommend routine rescreening within 12-24 months.';
    end

    if strcmp(quality_status, 'enhanced')
        quality_note = 'Image quality was borderline; automatic contrast enhancement was applied before analysis.';
    else
        quality_note = 'Image quality: acceptable, no enhancement needed.';
    end

    % Count detected findings using connected-component analysis.
    % IMPORTANT: pixel-level thresholding often fragments one real lesion
    % into many small disconnected pieces - this doesn't hurt the validated
    % overlap/Dice scores (which measure area, not blob count), but it badly
    % inflates a naive region count. We merge nearby fragments first,
    % purely for counting - the actual detection masks used elsewhere
    % (visual overlay, Dice validation) are left untouched.
    ma_count = 0; he_count = 0; ex_count = 0;
    if ~isempty(structures)
        merged_ma = imclose(structures.lesion_map.microaneurysms, strel('disk', 3));
        merged_he = imclose(structures.lesion_map.hemorrhages, strel('disk', 4));
        merged_ex = imclose(structures.lesion_map.exudates, strel('disk', 6));

        ma_count = numel(regionprops(merged_ma, 'Area'));
        he_count = numel(regionprops(merged_he, 'Area'));
        ex_count = numel(regionprops(merged_ex, 'Area'));
        vessel_pct = round(100 * nnz(structures.vessel_mask) / numel(structures.vessel_mask), 1);
    else
        vessel_pct = 0;
    end

    % Safety cap: classical lesion detection can occasionally over-fire on
    % noisy/atypical images (a known limitation) - never show an implausible
    % raw count in a report a viewer might read at face value.
    LESION_COUNT_CAP = 100;
    ma_count_str = capped_count(ma_count, LESION_COUNT_CAP);
    he_count_str = capped_count(he_count, LESION_COUNT_CAP);
    ex_count_str = capped_count(ex_count, LESION_COUNT_CAP);

    report_text = sprintf([ ...
        'This retinal image was analyzed successfully. %s ' ...
        'The AI model identified findings consistent with %s (Grade %d), ' ...
        'with %.0f%% confidence. Within the image, %s microaneurysm region(s), ' ...
        '%s hemorrhage region(s), and %s exudate region(s) were detected, ' ...
        'alongside a blood vessel network covering approximately %.1f%% of the visible retina. ' ...
        '%s ' ...
        '%s\n\n' ...
        'As with any AI-assisted screening tool, this result should be treated as a ' ...
        'preliminary decision-support output rather than a definitive diagnosis. Please ' ...
        'review the highlighted heatmap and detected structures alongside this summary ' ...
        'before taking any clinical action.'], ...
        quality_note, severity_names{dr_level + 1}, dr_level, confidence_score * 100, ...
        ma_count_str, he_count_str, ex_count_str, vessel_pct, ...
        referral_sentence(is_referable), recommendation);
end

function s = capped_count(n, cap)
    if n > cap
        s = sprintf('numerous (>%d - flagged as unreliable, recommend manual review)', cap);
    else
        s = num2str(n);
    end
end

function s = referral_sentence(is_referable)
    if is_referable
        s = 'Based on the severity of these findings, this case is classified as REFERABLE.';
    else
        s = 'Based on the severity of these findings, this case is classified as not currently referable.';
    end
end