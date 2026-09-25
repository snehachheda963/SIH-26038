% SORTAPTOSDATASET  Reads the APTOS 2019 train.csv and copies each image
% into data/train/<grade>/, ADDING to whatever's already there from IDRiD -
% this grows your training set rather than replacing it.

dataset_folder = dir('aptos*');
if isempty(dataset_folder)
    error('Could not find a folder starting with "aptos" in your SIH26038 folder.');
end
dataset_name = dataset_folder(1).name;

images_folder = fullfile(dataset_name, 'train_images');
csv_path = fullfile(dataset_name, 'train.csv');

if ~isfolder(images_folder)
    error('Images folder not found:\n%s', images_folder);
end
if ~isfile(csv_path)
    error('CSV file not found:\n%s', csv_path);
end

labels = readtable(csv_path);

% APTOS's CSV has columns 'id_code' and 'diagnosis' - check what readtable
% actually named them, in case of any auto-sanitizing.
var_names = labels.Properties.VariableNames;
id_col = var_names{contains(lower(var_names), 'id')};
diagnosis_col = var_names{contains(lower(var_names), 'diagn')};

fprintf('Using columns: "%s" (image id) and "%s" (grade)\n', id_col, diagnosis_col);

image_ids = labels.(id_col);
grades = labels.(diagnosis_col);

copied = 0;
skipped = 0;

for i = 1:height(labels)
    grade = grades(i);
    src_name = string(image_ids(i)) + ".png";
    src_path = fullfile(images_folder, src_name);

    dest_folder = fullfile('data', 'train', num2str(grade));
    if ~isfolder(dest_folder)
        mkdir(dest_folder);
    end

    if isfile(src_path)
        % Prefix filenames so they never collide with IDRiD's IDRiD_XXX names
        copyfile(src_path, fullfile(dest_folder, "aptos_" + src_name));
        copied = copied + 1;
    else
        skipped = skipped + 1;
    end
end

fprintf('\nDone. Copied %d images, skipped %d missing files.\n', copied, skipped);
fprintf('Check data/train/0 ... data/train/4 - counts should be noticeably higher now.\n');

fprintf('\nNew total images per class:\n');
for g = 0:4
    n = numel(dir(fullfile('data', 'train', num2str(g), '*.*'))) - 2;  % -2 for . and ..
    fprintf('Grade %d: %d images\n', g, n);
end
