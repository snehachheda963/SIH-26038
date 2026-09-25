% BUILDFULLDEMOSET  Automatically copies one held-out test image per DR
% grade (0-4) into sample_images/, plus keeps your reject test case, so you
% have a complete, ready-to-demo set covering every possible output.
%
% Uses IDRiD's "b. Testing Set" images (never used in training) with their
% real ground-truth grades from the testing labels CSV, so every result
% you show is on genuinely unseen data with a known correct answer.

test_images_folder = fullfile('idrid_dataset', '1. Original Images', 'b. Testing Set');
test_labels_path = fullfile('idrid_dataset', '2. Groundtruths', 'b. IDRiD_Disease Grading_Testing Labels.csv');

if ~isfolder(test_images_folder) || ~isfile(test_labels_path)
    error('IDRiD testing set not found - check idrid_dataset folder structure.');
end

labels = readtable(test_labels_path);
image_names = labels.ImageName;
grades = labels.RetinopathyGrade;

if ~isfolder('sample_images')
    mkdir('sample_images');
end

fprintf('Building a demo set with one example of each DR grade (0-4)...\n\n');

for target_grade = 0:4
    idx = find(grades == target_grade, 1);  % first match for this grade
    if isempty(idx)
        fprintf('Grade %d: no test image found, skipping.\n', target_grade);
        continue;
    end

    src_name = string(image_names(idx)) + ".jpg";
    src_path = fullfile(test_images_folder, src_name);

    if isfile(src_path)
        dest_name = sprintf('demo_grade%d_%s', target_grade, src_name);
        copyfile(src_path, fullfile('sample_images', dest_name));
        fprintf('Grade %d: copied %s -> %s (true grade confirmed: %d)\n', ...
            target_grade, src_name, dest_name, grades(idx));
    else
        fprintf('Grade %d: source file %s not found, skipping.\n', target_grade, src_name);
    end
end

fprintf('\nDone. Your sample_images folder now has one confirmed example of each DR grade (0-4),\n');
fprintf('each labeled with its TRUE grade in the filename so you know exactly what to expect\n');
fprintf('when you demo it - e.g. "demo_grade4_..." should predict Level 4.\n');
fprintf('\nUse retinaScreeningApp and upload each one in turn to build your complete demo evidence.\n');
