% CREATEDISTRICTROLLOUTMODEL  Builds a Simulink model that estimates the
% staffing/processing needs for rolling out the DR screening pipeline
% across a district.
%
% Run this ONCE. It creates and saves DistrictRolloutModel.slx in this
% folder, and opens it automatically. After that, just open
% DistrictRolloutModel.slx directly whenever you want to use it - you
% don't need to re-run this script again.
%
% HOW TO USE THE MODEL ONCE IT'S OPEN:
%   Double-click any of the six blue "Constant" input blocks on the left
%   to change its value (e.g. try changing NumReviewers from 3 to 5), then
%   press the Run (play) button at the top. The Display blocks on the
%   right update to show the recalculated results - this is your live,
%   interactive "what-if" demo for judges.

model_name = 'DistrictRolloutModel';

% Close and delete any previous version so this can be re-run cleanly
if bdIsLoaded(model_name)
    close_system(model_name, 0);
end
if isfile([model_name '.slx'])
    delete([model_name '.slx']);
end

new_system(model_name);
open_system(model_name);

%% ---- Input blocks (edit these values by double-clicking in the model) ----
% These are placeholder assumptions - adjust them to match your actual
% target district's numbers for your report/presentation.
inputs = struct( ...
    'ImagesPerDay',        struct('value', 300,  'desc', 'Patients screened per day'), ...
    'ProcessingTimeSec',   struct('value', 5,    'desc', 'AI processing time per image (sec)'), ...
    'ReferralRate',        struct('value', 0.35, 'desc', 'Fraction of images needing doctor review (0-1)'), ...
    'ReviewTimeMin',       struct('value', 3,    'desc', 'Doctor review time per referred case (min)'), ...
    'NumReviewers',        struct('value', 3,    'desc', 'Number of reviewing doctors/staff available'), ...
    'WorkingHoursPerDay',  struct('value', 8,    'desc', 'Working hours per staff member per day') ...
    );

input_names = fieldnames(inputs);
y_pos = 40;
input_ports = cell(numel(input_names), 1);

for i = 1:numel(input_names)
    name = input_names{i};
    block_path = [model_name '/' name];
    add_block('simulink/Sources/Constant', block_path, ...
        'Value', num2str(inputs.(name).value), ...
        'Position', [40, y_pos, 160, y_pos + 30]);
    input_ports{i} = block_path;
    y_pos = y_pos + 60;
end

%% ---- MATLAB Function block: does all the calculations in one place ----
calc_block = [model_name '/DistrictCalculator'];
add_block('simulink/User-Defined Functions/MATLAB Function', calc_block, ...
    'Position', [260, 20, 520, 20 + 60 * numel(input_names)]);

calc_script = [ ...
    'function [reqProcessingHrs, referableImages, reqReviewHrs, reviewerCapacityHrs, staffShortfallHrs, recommendedReviewers] = ', ...
    'districtCalc(imagesPerDay, procTimeSec, referralRate, reviewTimeMin, numReviewers, workHours)\n' ...
    '%% Hours of AI processing time needed per day\n' ...
    'reqProcessingHrs = imagesPerDay * procTimeSec / 3600;\n\n' ...
    '%% How many of those images actually need a human doctor to look\n' ...
    'referableImages = imagesPerDay * referralRate;\n\n' ...
    '%% Hours of doctor review time needed per day\n' ...
    'reqReviewHrs = referableImages * reviewTimeMin / 60;\n\n' ...
    '%% Hours of review capacity the current staff actually provides\n' ...
    'reviewerCapacityHrs = numReviewers * workHours;\n\n' ...
    '%% If required > available, this is how many hours short you are\n' ...
    'staffShortfallHrs = max(0, reqReviewHrs - reviewerCapacityHrs);\n\n' ...
    '%% How many reviewers you would actually need to keep up\n' ...
    'recommendedReviewers = ceil(reqReviewHrs / workHours);\n' ...
    'end' ...
    ];

root = sfroot;
chart = root.find('-isa', 'Stateflow.EMChart', 'Path', calc_block);
chart.Script = sprintf(calc_script);

%% ---- Wire inputs into the calculator ----
for i = 1:numel(input_names)
    add_line(model_name, [input_names{i} '/1'], ...
        ['DistrictCalculator/' num2str(i)], 'autorouting', 'on');
end

%% ---- Output Display blocks ----
output_names = {'ReqProcessingHrs', 'ReferableImagesPerDay', 'ReqReviewHrs', ...
    'ReviewerCapacityHrs', 'StaffShortfallHrs', 'RecommendedReviewers'};

y_pos = 20;
for i = 1:numel(output_names)
    block_path = [model_name '/' output_names{i}];
    add_block('simulink/Sinks/Display', block_path, ...
        'Position', [600, y_pos, 760, y_pos + 30]);
    add_line(model_name, ['DistrictCalculator/' num2str(i)], ...
        [output_names{i} '/1'], 'autorouting', 'on');
    y_pos = y_pos + 60;
end

%% ---- Save ----
save_system(model_name, fullfile(pwd, [model_name '.slx']));
fprintf('Model created and saved: %s.slx\n', model_name);
fprintf('Press the Run button in the Simulink window to see calculated results.\n');
fprintf('Double-click any input block to change its value and re-run for a "what-if" scenario.\n');
