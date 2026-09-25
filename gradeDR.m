function [dr_level, confidence_score, is_referable] = gradeDR(image, lesion_map)
% GRADEDR  Module 3 - DR Severity Grading
% Owner: ML Engineer
%
% INPUT:
%   image      - the cleaned retina image (from Module 1)
%   lesion_map - the .lesion_map struct from Module 2 (segmentStructures.m)
%                Note: for a "v1" quick model, you can ignore lesion_map and
%                classify directly from the image - upgrade to use it later.
%
% OUTPUT:
%   dr_level          - integer 0-4 (International Clinical DR severity scale)
%                        0 = No DR, 1 = Mild, 2 = Moderate, 3 = Severe, 4 = Proliferative
%   confidence_score  - value between 0 and 1 (how sure the model is)
%   is_referable      - true if dr_level >= 2 (needs a doctor's review)
%
% This output feeds into explainResult.m (Module 4).
%
% RECOMMENDED APPROACH (transfer learning - fastest path to a working model):
%   1. Load a pretrained network, e.g.:  net = resnet18;  (or resnet50, efficientnetb0)
%   2. Replace its final layers for 5-class classification (Deep Network Designer app,
%      or programmatically replace the last fullyConnectedLayer + classificationLayer).
%   3. Train on labeled data from APTOS2019 / IDRiD / Messidor
%      (trainNetwork or trainnet, with imageDatastore + augmentedImageDatastore).
%   4. Save the trained model: save('dr_model.mat', 'net');
%   5. In this function, load it once (persistent variable) and call
%      classify(net, image) to get the predicted label + score.

    net = loadTrainedModel();  % returns [] until trainDRModel.m has been run

    if isempty(net)
        % ---- Placeholder behavior until a real model is trained ----
        dr_level = 0;
        confidence_score = 0.0;
        is_referable = false;
        return;
    end

    % ---- Real inference using the trained model ----
    resized_image = imresize(image, net.Layers(1).InputSize(1:2));
    if size(resized_image, 3) == 1
        resized_image = repmat(resized_image, 1, 1, 3);  % grayscale -> RGB, matches training
    end

    [predicted_label, scores] = classify(net, resized_image);
    dr_level = double(predicted_label) - 1;  % categories '0'-'4' map to indices 1-5
    confidence_score = max(scores);
    is_referable = dr_level >= 2;
end