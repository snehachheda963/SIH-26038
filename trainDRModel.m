% TRAINDRMODEL  Trains the DR severity classifier.
%
% This version tries to use a pretrained network if available, but falls back
% to a custom CNN built from scratch if the support package isn't installed.
% The custom CNN needs NO downloads and works fine on small datasets.
% Also applies class weighting to compensate for imbalanced data (some DR
% grades have far fewer images than others).
%
% BEFORE RUNNING:
%   Make sure data/train/0 ... data/train/4 contain your sorted images
%   (run sortIDRiDDataset.m first if you haven't).
%
% Just hit Run (F5). Training progress will appear in a plot window.

%% 1. Load images from folders (labels come from folder names: 0,1,2,3,4)
data_folder = fullfile('data', 'train');

if ~isfolder(data_folder) || isempty(dir(fullfile(data_folder, '*', '*.*')))
    error(['No training images found in %s.\n' ...
           'Run setupProjectFolders.m and sortIDRiDDataset.m first.'], data_folder);
end

imds = imageDatastore(data_folder, ...
    'IncludeSubfolders', true, ...
    'LabelSource', 'foldernames');

numClasses = numel(categories(imds.Labels));
fprintf('Found %d images across %d classes.\n', numel(imds.Files), numClasses);

fprintf('\nImages per class:\n');
disp(countEachLabel(imds));

%% 2. Split into training (80%) and validation (20%) sets
[imdsTrain, imdsVal] = splitEachLabel(imds, 0.8, 'randomized');

%% 3. Class weights - compensate for imbalanced data (e.g. Grade 1 has far fewer
%% images than Grade 0/2). Without this, the model learns to just ignore rare classes.
%% This MUST be computed before the network is built, since the final layer uses it.
labelCounts = countEachLabel(imdsTrain);
classWeights = sqrt(numel(imdsTrain.Files) ./ (numel(labelCounts.Label) * labelCounts.Count));
classWeights = classWeights';  % row vector, same order as labelCounts.Label

% ---- Targeted referable-DR boost ----
% Our last run hit 95.1% specificity (target >85%, lots of headroom) but only
% 86.5% sensitivity (target >90%). Rather than balance all 5 classes equally,
% specifically boost referable classes (2,3,4) and ease off non-referable
% (0,1) - this trades back some of the specificity surplus for sensitivity,
% targeting the actual metric the problem statement cares about.
grade_values = double(string(labelCounts.Label));
referable_mask = grade_values >= 2;
REFERABLE_BOOST = 1.4;
NONREFERABLE_REDUCE = 0.75;
classWeights(referable_mask) = classWeights(referable_mask) * REFERABLE_BOOST;
classWeights(~referable_mask) = classWeights(~referable_mask) * NONREFERABLE_REDUCE;

fprintf('\nClass weights (higher = model penalized more for getting this class wrong):\n');
disp(table(labelCounts.Label, classWeights', 'VariableNames', {'Grade', 'Weight'}));

%% 4. Set image size (smaller = faster training, less memory)
inputSize = [224 224 3];

% Data augmentation: small random flips/rotations/shifts.
% This artificially expands a small dataset and reduces overfitting.
augmenter = imageDataAugmenter( ...
    'RandXReflection', true, ...
    'RandRotation', [-15 15], ...
    'RandXTranslation', [-10 10], ...
    'RandYTranslation', [-10 10]);

augmentedTrain = augmentedImageDatastore(inputSize(1:2), imdsTrain, ...
    'ColorPreprocessing', 'gray2rgb', ...
    'DataAugmentation', augmenter);

augmentedVal = augmentedImageDatastore(inputSize(1:2), imdsVal, ...
    'ColorPreprocessing', 'gray2rgb');

%% 5. Build the network
usePretrained = false;
try
    pretrained = resnet18;  % will error if support package is missing
    usePretrained = true;
    fprintf('\nUsing pretrained ResNet-18 (transfer learning).\n');
catch
    fprintf('\nPretrained ResNet-18 not available - building a custom CNN from scratch instead.\n');
    fprintf('(This works fine and requires no downloads.)\n');
end

if usePretrained
    inputSize = pretrained.Layers(1).InputSize;
    lgraph = layerGraph(pretrained);
    newFC = fullyConnectedLayer(numClasses, 'Name', 'new_fc', ...
        'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10);
    lgraph = replaceLayer(lgraph, 'fc1000', newFC);
    lgraph = replaceLayer(lgraph, 'ClassificationLayer_predictions', ...
        classificationLayer('Name', 'new_classoutput', 'Classes', labelCounts.Label, 'ClassWeights', classWeights));
    layers_to_train = lgraph;
else
    % ---- Custom CNN, no downloads needed ----
    % 4 convolution blocks, each halving the image size and doubling the filters.
    % The layer named 'last_conv' is what Grad-CAM will visualize later.
    layers_to_train = [
        imageInputLayer(inputSize, 'Name', 'input')

        convolution2dLayer(3, 16, 'Padding', 'same', 'Name', 'conv_1')
        batchNormalizationLayer('Name', 'bn_1')
        reluLayer('Name', 'relu_1')
        maxPooling2dLayer(2, 'Stride', 2, 'Name', 'pool_1')

        convolution2dLayer(3, 32, 'Padding', 'same', 'Name', 'conv_2')
        batchNormalizationLayer('Name', 'bn_2')
        reluLayer('Name', 'relu_2')
        maxPooling2dLayer(2, 'Stride', 2, 'Name', 'pool_2')

        convolution2dLayer(3, 64, 'Padding', 'same', 'Name', 'conv_3')
        batchNormalizationLayer('Name', 'bn_3')
        reluLayer('Name', 'relu_3')
        maxPooling2dLayer(2, 'Stride', 2, 'Name', 'pool_3')

        convolution2dLayer(3, 128, 'Padding', 'same', 'Name', 'last_conv')
        batchNormalizationLayer('Name', 'bn_4')
        reluLayer('Name', 'relu_4')

        globalAveragePooling2dLayer('Name', 'gap')
        dropoutLayer(0.4, 'Name', 'dropout')
        fullyConnectedLayer(numClasses, 'Name', 'fc_out')
        softmaxLayer('Name', 'softmax')
        classificationLayer('Name', 'output', 'Classes', labelCounts.Label, 'ClassWeights', classWeights)
        ];
end

%% 6. Training options
options = trainingOptions('adam', ...
    'MiniBatchSize', 16, ...
    'MaxEpochs', 30, ...
    'InitialLearnRate', 1e-3, ...
    'Shuffle', 'every-epoch', ...
    'ValidationData', augmentedVal, ...
    'ValidationFrequency', 20, ...
    'Verbose', true, ...
    'Plots', 'training-progress');

% Pretrained networks need a much lower learning rate than a from-scratch CNN
if usePretrained
    options.InitialLearnRate = 1e-4;
    options.MaxEpochs = 10;
end

%% 7. Train
fprintf('\nStarting training...\n');
net = trainNetwork(augmentedTrain, layers_to_train, options);

%% 8. Evaluate on the validation set
[predicted, scores] = classify(net, augmentedVal);  % scores = probability per class
actual = imdsVal.Labels;
accuracy = mean(predicted == actual);
fprintf('\nValidation accuracy: %.1f%%\n', accuracy * 100);

% Confusion matrix - shows which grades get confused with which
figure('Name', 'Confusion Matrix');
confusionchart(actual, predicted);
title(sprintf('DR Grading - Validation Accuracy %.1f%%', accuracy * 100));

% ---- The metric that actually matters for this problem statement: ----
% Referable DR (Grade 2+) vs Not Referable (Grade 0-1). The PS targets
% >90% sensitivity and >85% specificity on THIS, not on 5-class accuracy.
actual_referable = double(actual) - 1 >= 2;       % true if actual grade >= 2
predicted_referable = double(predicted) - 1 >= 2; % true if predicted grade >= 2

true_positives  = sum(actual_referable & predicted_referable);
false_negatives = sum(actual_referable & ~predicted_referable);
true_negatives  = sum(~actual_referable & ~predicted_referable);
false_positives = sum(~actual_referable & predicted_referable);

sensitivity = true_positives / (true_positives + false_negatives);
specificity = true_negatives / (true_negatives + false_positives);

fprintf('\n--- Referable DR (Grade 2+) performance - this is the PS target metric ---\n');
fprintf('Sensitivity: %.1f%%  (target: >90%%)\n', sensitivity * 100);
fprintf('Specificity: %.1f%%  (target: >85%%)\n', specificity * 100);

% ---- ROC curve and AUC (Statistics and Machine Learning Toolbox) ----
% Uses actual class probabilities (not just the final predicted label) to
% show how well-separated referable vs non-referable predictions are
% across every possible decision threshold - a standard metric in
% published DR screening research (IDx-DR, EyeArt, etc. all report this).
class_order = double(string(categories(actual)));  % e.g. [0 1 2 3 4]
referable_col_idx = find(class_order >= 2);
referable_scores = sum(scores(:, referable_col_idx), 2);

[rocX, rocY, ~, AUC] = perfcurve(actual_referable, referable_scores, true);

figure('Name', 'ROC Curve - Referable DR Detection');
plot(rocX, rocY, 'LineWidth', 2);
hold on;
plot([0 1], [0 1], '--', 'Color', [0.6 0.6 0.6]);  % random-chance reference line
xlabel('False Positive Rate (1 - Specificity)');
ylabel('True Positive Rate (Sensitivity)');
title(sprintf('ROC Curve - Referable DR Detection (AUC = %.3f)', AUC));
legend('Model', 'Random chance', 'Location', 'southeast');
grid on;

fprintf('AUC (Area Under ROC Curve): %.3f\n', AUC);
fprintf('(Published referable-DR screening systems typically report AUC 0.94-0.99)\n');

%% 9. Save the trained model
if ~isfolder('models')
    mkdir('models');
end
save(fullfile('models', 'dr_model.mat'), 'net');
fprintf('\nModel saved to models/dr_model.mat\n');
fprintf('gradeDR.m and explainResult.m will now use this model automatically.\n');
fprintf('Next: drop test images into sample_images/ and run testPipeline.m\n');