% SORTIDRIDDATASET  Reads the IDRiD grading CSV and copies each image
% into data/train/<grade>/ so trainDRModel.m can use it directly.
%
% BEFORE RUNNING: edit the two paths below to match where you unzipped
% the IDRiD dataset and what the CSV/image folders are actually called.
% IDRiD's standard structure looks like:
%
%   idrid_dataset/
%     B. Disease Grading/
%       1. Original Images/
%         a. Training Set/            <- the actual .jpg images
%       2. Groundtruths/
%         a. IDRiD_Disease Grading_Training Labels.csv   <- the grade labels
%
% If your unzipped folder looks different, open it in File Explorer,
% find the folder full of .jpg images and the .csv file with grades,
% and update the two paths below to match exactly.

images_folder = fullfile('idrid_dataset', ...
    '1. Original Images', 'a. Training Set');

csv_path = fullfile('idrid_dataset', ...
    '2. Groundtruths', 'a. IDRiD_Disease Grading_Training Labels.csv');

%% Check the paths exist before doing anything
if ~isfolder(images_folder)
    error('Images folder not found:\n%s\nOpen your idrid_dataset folder in File Explorer and fix this path.', images_folder);
end
if ~isfile(csv_path)
    error('CSV file not found:\n%s\nOpen your idrid_dataset folder in File Explorer and fix this path.', csv_path);
end

%% Read the labels
labels = readtable(csv_path);

% IDRiD's CSV usually has columns named 'Image name' and 'Retinopathy grade'.
% If readtable gives different column names (check with: labels.Properties.VariableNames),
% update the two lines below to match.
image_names = labels.ImageName;         % e.g. "IDRiD_001"
grades      = labels.RetinopathyGrade;  % e.g. 0,1,2,3,4

%% Copy each image into the matching graded folder
copied = 0;
skipped = 0;

for i = 1:height(labels)
    grade = grades(i);
    src_name = string(image_names(i)) + ".jpg";
    src_path = fullfile(images_folder, src_name);

    dest_folder = fullfile('data', 'train', num2str(grade));
    if ~isfolder(dest_folder)
        mkdir(dest_folder);
    end

    if isfile(src_path)
        copyfile(src_path, dest_folder);
        copied = copied + 1;
    else
        fprintf('Skipping missing file: %s\n', src_path);
        skipped = skipped + 1;
    end
end

fprintf('\nDone. Copied %d images, skipped %d missing files.\n', copied, skipped);
fprintf('Check data/train/0 ... data/train/4 - each should now have images in it.\n');