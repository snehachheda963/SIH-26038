% SETUPPROJECTFOLDERS  Run this ONCE to create the folder structure
% that all the other scripts expect. Run it from your project folder.
%
% After running this, your folder will look like:
%
%   SIH26038_Project/
%     data/train/0/   <- put "No DR" images here later
%     data/train/1/   <- put "Mild" images here later
%     data/train/2/   <- put "Moderate" images here later
%     data/train/3/   <- put "Severe" images here later
%     data/train/4/   <- put "Proliferative DR" images here later
%     models/         <- trained model gets saved here automatically
%     sample_images/  <- put a few test images here for quick testing
%
% This grouping-by-folder-name format (0,1,2,3,4) is what MATLAB's
% imageDatastore expects when you tell it 'LabelSource','foldernames' -
% it automatically uses APTOS2019/IDRiD-style labels this way.

folders_to_create = { ...
    fullfile('data','train','0'), ...
    fullfile('data','train','1'), ...
    fullfile('data','train','2'), ...
    fullfile('data','train','3'), ...
    fullfile('data','train','4'), ...
    'models', ...
    'sample_images' ...
    };

for i = 1:numel(folders_to_create)
    if ~isfolder(folders_to_create{i})
        mkdir(folders_to_create{i});
        fprintf('Created: %s\n', folders_to_create{i});
    else
        fprintf('Already exists: %s\n', folders_to_create{i});
    end
end

fprintf('\nDone. When your dataset is ready:\n');
fprintf('  1. Sort images into data/train/0 ... data/train/4 by DR grade.\n');
fprintf('  2. Drop a few test images into sample_images/.\n');
fprintf('  3. Run trainDRModel.m to train, then testPipeline.m to test.\n');
