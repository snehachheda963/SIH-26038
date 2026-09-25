function retinaScreeningApp
% RETINASCREENINGAPP  Frontend for the DR screening pipeline.
%
% Run this by typing: retinaScreeningApp
%
% v2: adds patient info capture, a visible image-quality verdict,
% step-by-step pipeline display (instead of one final dump), a
% session history log, and a "Save Report (PDF)" export.
%
% Calls your existing modules directly (checkImageQuality, segmentStructures,
% gradeDR, explainResult, loadTrainedModel) instead of going through
% runPipeline.m, so each stage can update the UI as it happens.

    fig = uifigure('Name', 'DR Screening Tool', 'Position', [60 60 1280 760]);

    mainGrid = uigridlayout(fig, [8, 1]);
    mainGrid.RowHeight = {70, 80, '1x', 20, 45, 72, 80, 130};
    mainGrid.RowSpacing = 8;

    % ---- Header ----
    headerGrid = uigridlayout(mainGrid, [2, 1]);
    headerGrid.Layout.Row = 1; headerGrid.Layout.Column = 1;
    headerGrid.RowHeight = {30, 20};
    headerGrid.Padding = [0 0 0 0];

    uilabel(headerGrid, 'Text', 'Diabetic Retinopathy Screening Tool', ...
        'FontSize', 18, 'FontWeight', 'bold');
    uilabel(headerGrid, 'Text', 'Explainable AI screening prototype - SIH26038', ...
        'FontSize', 11, 'FontColor', [0.4 0.4 0.4]);

    % ---- Patient info panel (labels row + inputs row, so every field is identified) ----
    patientGrid = uigridlayout(mainGrid, [2, 5]);
    patientGrid.Layout.Row = 2; patientGrid.Layout.Column = 1;
    patientGrid.ColumnWidth = {'1x', '1.4x', 90, 150, '1x'};
    patientGrid.RowHeight = {16, '1x'};
    patientGrid.RowSpacing = 2;
    patientGrid.Padding = [0 0 0 0];

    lblCap = @(txt, col) setLayout(uilabel(patientGrid, 'Text', txt, 'FontSize', 10, ...
        'FontColor', [0.45 0.45 0.45]), 1, col);
    lblCap('Patient ID', 1);
    lblCap('Patient Name', 2);
    lblCap('Age', 3);
    lblCap('Eye', 4);
    lblCap('Image Quality', 5);

    edPatientID = uieditfield(patientGrid, 'text', 'Value', '');
    edPatientID.Layout.Row = 2; edPatientID.Layout.Column = 1;
    edPatientID.Placeholder = 'e.g. 001';

    edPatientName = uieditfield(patientGrid, 'text', 'Value', '');
    edPatientName.Layout.Row = 2; edPatientName.Layout.Column = 2;
    edPatientName.Placeholder = 'e.g. Sneha';

    edPatientAge = uieditfield(patientGrid, 'numeric', 'Value', 0, 'Limits', [0 120]);
    edPatientAge.Layout.Row = 2; edPatientAge.Layout.Column = 3;

    ddEye = uidropdown(patientGrid, 'Items', {'OD (Right Eye)', 'OS (Left Eye)'});
    ddEye.Layout.Row = 2; ddEye.Layout.Column = 4;

    lblQuality = uilabel(patientGrid, 'Text', 'Quality: -', 'FontSize', 13, 'FontWeight', 'bold');
    lblQuality.Layout.Row = 2; lblQuality.Layout.Column = 5;

    function obj = setLayout(obj, row, col)
        obj.Layout.Row = row; obj.Layout.Column = col;
    end

    % ---- Image panels (3 across, resize together) ----
    imageGrid = uigridlayout(mainGrid, [1, 3]);
    imageGrid.Layout.Row = 3; imageGrid.Layout.Column = 1;
    imageGrid.ColumnWidth = {'1x', '1x', '1x'};
    imageGrid.Padding = [0 0 0 0];

    ax1 = uiaxes(imageGrid); ax1.Layout.Row = 1; ax1.Layout.Column = 1;
    title(ax1, 'Uploaded Image'); ax1.XTick = []; ax1.YTick = [];

    ax3 = uiaxes(imageGrid); ax3.Layout.Row = 1; ax3.Layout.Column = 2;
    title(ax3, 'Detected Structures'); ax3.XTick = []; ax3.YTick = [];

    ax2 = uiaxes(imageGrid); ax2.Layout.Row = 1; ax2.Layout.Column = 3;
    title(ax2, 'AI Explanation (Heatmap)'); ax2.XTick = []; ax2.YTick = [];

    % ---- Legend ----
    lblLegend = uilabel(mainGrid, 'Text', ...
        'Cyan=vessels  Yellow=microaneurysms  Orange=hemorrhages  Magenta=exudates  Green dot=optic disc', ...
        'FontSize', 10, 'FontColor', [0.4 0.4 0.4]);
    lblLegend.Layout.Row = 4; lblLegend.Layout.Column = 1;

    % ---- Buttons ----
    buttonGrid = uigridlayout(mainGrid, [1, 4]);
    buttonGrid.Layout.Row = 5; buttonGrid.Layout.Column = 1;
    buttonGrid.ColumnWidth = {170, 160, 170, '1x'};
    buttonGrid.Padding = [0 0 0 0];

    btnUpload = uibutton(buttonGrid, 'Text', 'Upload Retina Image', 'FontSize', 13, ...
        'ButtonPushedFcn', @(btn, event) uploadImage());
    btnUpload.Layout.Row = 1; btnUpload.Layout.Column = 1;

    btnAnalyze = uibutton(buttonGrid, 'Text', 'Run Analysis', 'FontSize', 13, 'Enable', 'off', ...
        'ButtonPushedFcn', @(btn, event) analyzeImage());
    btnAnalyze.Layout.Row = 1; btnAnalyze.Layout.Column = 2;

    btnSave = uibutton(buttonGrid, 'Text', 'Save Report (PDF)', 'FontSize', 13, 'Enable', 'off', ...
        'ButtonPushedFcn', @(btn, event) saveReport());
    btnSave.Layout.Row = 1; btnSave.Layout.Column = 3;

    % ---- Results ----
    resultGrid = uigridlayout(mainGrid, [3, 2]);
    resultGrid.Layout.Row = 6; resultGrid.Layout.Column = 1;
    resultGrid.ColumnWidth = {'2x', '1x'};
    resultGrid.RowHeight = {24, 24, 40};
    resultGrid.Padding = [0 0 0 0];

    lblStatus = uilabel(resultGrid, 'Text', 'Status: waiting for an image...', 'FontSize', 12);
    lblStatus.Layout.Row = 1; lblStatus.Layout.Column = [1 2];

    lblResult = uilabel(resultGrid, 'Text', 'Result: -', 'FontSize', 15, 'FontWeight', 'bold');
    lblResult.Layout.Row = 2; lblResult.Layout.Column = 1;

    lblConfidence = uilabel(resultGrid, 'Text', 'Confidence: -', 'FontSize', 13);
    lblConfidence.Layout.Row = 2; lblConfidence.Layout.Column = 2;

    lblReferable = uilabel(resultGrid, 'Text', 'Referable: -', 'FontSize', 15, 'FontWeight', 'bold');
    lblReferable.Layout.Row = 3; lblReferable.Layout.Column = 1;

    % ---- Auto-generated report text ----
    txtReport = uitextarea(mainGrid, 'Value', 'Report will appear here after analysis.', ...
        'Editable', 'off', 'FontSize', 12);
    txtReport.Layout.Row = 7; txtReport.Layout.Column = 1;

    % ---- Session history (kept in memory for this run; export via Save Report) ----
    historyTable = uitable(mainGrid, ...
        'ColumnName', {'Patient ID', 'Name', 'Eye', 'Grade', 'Confidence', 'Referable', 'Time'}, ...
        'Data', cell(0, 7));
    historyTable.Layout.Row = 8; historyTable.Layout.Column = 1;

    current_image_path = '';
    lastResult = [];   % struct populated after a successful (non-reject) analysis

    %% ---- Callbacks ----
    function uploadImage()
        [file, filepath] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif', 'Image Files'}, ...
            'Select a retina image');
        if isequal(file, 0)
            return;
        end
        current_image_path = fullfile(filepath, file);

        img = imread(current_image_path);
        imshow(img, 'Parent', ax1);
        ax1.XLim = [0 size(img, 2)]; ax1.YLim = [0 size(img, 1)];
        title(ax1, 'Uploaded Image');
        cla(ax3); title(ax3, 'Detected Structures');
        cla(ax2); title(ax2, 'AI Explanation (Heatmap)');
        drawnow;

        btnAnalyze.Enable = 'on';
        btnSave.Enable = 'off';
        lastResult = [];
        lblQuality.Text = 'Quality: -';
        lblQuality.FontColor = [0 0 0];
        lblStatus.Text = 'Status: Image loaded. Click "Run Analysis".';
        lblResult.Text = 'Result: -';
        lblConfidence.Text = 'Confidence: -';
        lblReferable.Text = 'Referable: -';
        lblReferable.FontColor = [0 0 0];
        txtReport.Value = 'Report will appear here after analysis.';
    end

    function analyzeImage()
        if isempty(current_image_path)
            return;
        end

        img = imread(current_image_path);

        % ---- Stage 1: Quality check (visible, with rejection path) ----
        lblStatus.Text = 'Status: Checking image quality...';
        drawnow;

        [status, cleaned_image, reject_reason] = checkImageQuality(img);

        switch status
            case 'pass'
                lblQuality.Text = 'Quality: Good';
                lblQuality.FontColor = [0 0.55 0];
            case 'enhanced'
                lblQuality.Text = 'Quality: Enhanced (auto-corrected)';
                lblQuality.FontColor = [0.85 0.55 0];
            case 'reject'
                lblQuality.Text = ['Quality: Rejected - ' reject_reason];
                lblQuality.FontColor = [0.75 0 0];
        end
        drawnow;

        if strcmp(status, 'reject')
            lblStatus.Text = 'Status: Screening halted - image rejected.';
            lblResult.Text = 'Result: N/A';
            lblConfidence.Text = 'Confidence: N/A';
            lblReferable.Text = 'Referable: N/A';
            lblReferable.FontColor = [0 0 0];
            txtReport.Value = ['Image rejected: ' reject_reason ' Please upload a clearer photo.'];
            cla(ax3); title(ax3, 'No result (image rejected)');
            cla(ax2); title(ax2, 'No result (image rejected)');
            btnSave.Enable = 'off';
            drawnow;
            return;
        end

        % ---- Stage 2: Structure segmentation ----
        lblStatus.Text = 'Status: Segmenting vessels, optic disc, lesions...';
        drawnow;

        structures = segmentStructures(cleaned_image);

        overlay = cleaned_image;
        overlay = imoverlay(overlay, structures.vessel_mask, [0 1 1]);
        overlay = imoverlay(overlay, structures.lesion_map.microaneurysms, [1 1 0]);
        overlay = imoverlay(overlay, structures.lesion_map.hemorrhages, [1 0.5 0]);
        overlay = imoverlay(overlay, structures.lesion_map.exudates, [1 0 1]);
        [xx, yy] = meshgrid(1:size(cleaned_image, 2), 1:size(cleaned_image, 1));
        disc_marker = sqrt((xx - structures.optic_disc_location(1)).^2 + ...
                            (yy - structures.optic_disc_location(2)).^2) <= 8;
        overlay = imoverlay(overlay, disc_marker, [0 1 0]);

        imshow(overlay, 'Parent', ax3);
        ax3.XLim = [0 size(overlay, 2)]; ax3.YLim = [0 size(overlay, 1)];
        title(ax3, 'Detected Structures');
        drawnow;

        % ---- Stage 3: DR severity grading ----
        lblStatus.Text = 'Status: Grading DR severity...';
        drawnow;

        [dr_level, confidence_score, is_referable] = gradeDR(cleaned_image, structures.lesion_map);

        severity_names = {'No DR', 'Mild', 'Moderate', 'Severe', 'Proliferative DR'};
        lblResult.Text = ['Result: ' severity_names{dr_level + 1} ' (Level ' num2str(dr_level) ')'];
        lblConfidence.Text = ['Confidence: ' num2str(round(confidence_score * 100)) '%'];

        if is_referable
            lblReferable.Text = 'Referable: YES - needs doctor review';
            lblReferable.FontColor = [0.75 0 0];
        else
            lblReferable.Text = 'Referable: No';
            lblReferable.FontColor = [0 0.55 0];
        end
        drawnow;

        % ---- Stage 4: Explainability (Grad-CAM + narrative) ----
        lblStatus.Text = 'Status: Generating explainability heatmap...';
        drawnow;

        net = loadTrainedModel();
        [heatmap_image, report_text] = explainResult(cleaned_image, dr_level, confidence_score, ...
            net, structures, status);

        imshow(heatmap_image, 'Parent', ax2);
        [hh, ww, ~] = size(heatmap_image);
        ax2.XLim = [0 ww]; ax2.YLim = [0 hh];
        title(ax2, 'AI Explanation (Heatmap)');

        txtReport.Value = report_text;
        lblStatus.Text = 'Status: Screening complete.';
        drawnow;

        % ---- Log to session history ----
        newRow = {edPatientID.Value, edPatientName.Value, ddEye.Value, ...
                  severity_names{dr_level + 1}, sprintf('%.0f%%', confidence_score * 100), ...
                  mat2str(is_referable), datestr(now, 'HH:MM:SS')}; %#ok<TNOW1,DATST>
        historyTable.Data = [historyTable.Data; newRow];

        % ---- Stash everything Save Report needs ----
        lastResult = struct( ...
            'patientID', edPatientID.Value, 'patientName', edPatientName.Value, ...
            'patientAge', edPatientAge.Value, 'patientEye', ddEye.Value, ...
            'quality_status', status, 'grade', severity_names{dr_level + 1}, ...
            'dr_level', dr_level, 'confidence', confidence_score, 'is_referable', is_referable, ...
            'report_text', report_text, ...
            'original', img, 'structures_overlay', overlay, 'heatmap', heatmap_image);
        btnSave.Enable = 'on';
    end

    function saveReport()
        if isempty(lastResult)
            uialert(fig, 'Run an analysis first before saving a report.', 'No result yet');
            return;
        end

        defaultName = sprintf('DR_Report_%s.pdf', ...
            regexprep(lastResult.patientID, '[^\w-]', '_'));
        if isempty(lastResult.patientID)
            defaultName = 'DR_Report.pdf';
        end
        % Pin the save dialog to this project's folder (pwd) instead of letting
        % it default to whatever folder MATLAB happened to be in - that
        % unpredictability is why saved reports can seem to "go missing".
        [file, filepath] = uiputfile(fullfile(pwd, '*.pdf'), 'Save Screening Report', ...
            fullfile(pwd, defaultName));
        if isequal(file, 0)
            return;
        end
        outPath = fullfile(filepath, file);

        r = lastResult;
        f = figure('Visible', 'off', 'Units', 'normalized', 'Position', [0 0 1 1], 'Color', 'w');

        sgtitle(sprintf('Diabetic Retinopathy Screening Report\nPatient: %s (%s)   Age: %s   Eye: %s   %s', ...
            r.patientName, r.patientID, num2str(r.patientAge), r.patientEye, ...
            datestr(now, 'dd-mmm-yyyy HH:MM'))); %#ok<TNOW1,DATST>

        subplot(2,2,1); imshow(r.original);          title('Original Image');
        subplot(2,2,2); imshow(r.structures_overlay); title('Detected Structures');
        subplot(2,2,3); imshow(r.heatmap);            title('Grad-CAM Heatmap');

        subplot(2,2,4); axis off;
        summaryStr = sprintf(['Image Quality: %s\n\n' ...
            'DR Grade: %s\nConfidence: %.0f%%\nReferable: %s\n\n%s'], ...
            r.quality_status, r.grade, r.confidence * 100, mat2str(r.is_referable), ...
            wrapText(r.report_text, 60));
        text(0, 1, summaryStr, 'VerticalAlignment', 'top', 'FontSize', 9, 'Units', 'normalized');

        try
            exportgraphics(f, outPath, 'ContentType', 'vector');
            close(f);
            % Confirm it actually landed on disk before telling the user it worked
            if isfile(outPath)
                uialert(fig, sprintf('Report saved to:\n%s', outPath), 'Saved', 'Icon', 'success');
            else
                uialert(fig, sprintf(['Export ran but no file was found at:\n%s\n' ...
                    'Try saving to a simpler path (e.g. your Desktop) and avoid special characters in the Patient ID.'], ...
                    outPath), 'Save uncertain', 'Icon', 'warning');
            end
        catch ME
            close(f);
            uialert(fig, sprintf('Could not save report: %s', ME.message), 'Save failed', 'Icon', 'error');
        end
    end

    function wrapped = wrapText(txt, width)
        words = strsplit(txt, ' ');
        wrapped = ''; lineLen = 0;
        for i = 1:numel(words)
            w = words{i};
            if lineLen + numel(w) + 1 > width
                wrapped = [wrapped, newline, w]; %#ok<AGROW>
                lineLen = numel(w);
            else
                if isempty(wrapped)
                    wrapped = w;
                else
                    wrapped = [wrapped, ' ', w]; %#ok<AGROW>
                end
                lineLen = lineLen + numel(w) + 1;
            end
        end
    end
end