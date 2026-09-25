function result = runPipeline(image_path)
% RUNPIPELINE  Module 5 - Integration (runs the full pipeline end-to-end)
% Owner: Integration Lead
%
% INPUT:
%   image_path - path to a retina image file, e.g. 'sample_images/patient1.jpg'
%
% OUTPUT:
%   result - a struct combining everything, ready to hand to the frontend:
%       .status          - 'pass' / 'reject' / 'enhanced' (from Module 1)
%       .reject_reason   - text if rejected (empty otherwise)
%       .dr_level        - 0-4 (from Module 3)
%       .confidence_score
%       .is_referable
%       .heatmap_image   - image with Grad-CAM overlay (from Module 4)
%       .report_text     - doctor-readable summary (from Module 4)
%
% This is the function your frontend (App Designer or web backend) should call.
% It does not need to know anything about how each module works internally -
% only what runPipeline() promises to return.

    image = imread(image_path);

    % ---- Step 1: Quality check ----
    [status, cleaned_image, reject_reason] = checkImageQuality(image);

    if strcmp(status, 'reject')
        result = struct( ...
            'status', status, ...
            'reject_reason', reject_reason, ...
            'dr_level', [], 'confidence_score', [], 'is_referable', [], ...
            'heatmap_image', [], 'report_text', '', 'structures', []);
        return;
    end

    % ---- Step 2: Segmentation ----
    structures = segmentStructures(cleaned_image);

    % ---- Step 3: DR grading ----
    [dr_level, confidence_score, is_referable] = gradeDR(cleaned_image, structures.lesion_map);

    % ---- Step 4: Explainability ----
    trained_net = loadTrainedModel();  % returns [] until trainDRModel.m has been run
    [heatmap_image, report_text] = explainResult(cleaned_image, dr_level, confidence_score, trained_net, structures, status);

    % ---- Combine everything for the frontend ----
    result = struct( ...
        'status', status, ...
        'reject_reason', reject_reason, ...
        'dr_level', dr_level, ...
        'confidence_score', confidence_score, ...
        'is_referable', is_referable, ...
        'heatmap_image', heatmap_image, ...
        'report_text', report_text, ...
        'structures', structures);

    % ---- Optional: log this result so the Simulink team has real usage data ----
    % logResultForSimulink(result);  % TODO: implement simple CSV/struct logging
end