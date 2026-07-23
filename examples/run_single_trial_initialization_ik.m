%% run_single_trial_initialization_ik.m
% Single-trial validation driver: Model A and initialization IK.
%
% Run this script one section at a time. It intentionally stops after the
% initialization IK pass so that model configuration, setup XML, marker
% errors, and cervical coordinate behavior can be reviewed before creating
% the locked final-IK model.
%
% REQUIRED TOOLKIT PACKAGES
%   +opensimio
%   +modelprep
%   +opensimrun
%
% REQUIRED INPUTS
%   1) Clean scaled 4-month-old base model
%   2) Trial marker .trc file
%   3) A known-working IK setup XML template with the correct IK task set
%
% The template must contain exactly one each of:
%   <model_file>
%   <marker_file>
%   <time_range>
%   <output_motion_file>

%% SECTION 0 — USER CONFIGURATION

clear;
clc;

% Stop exactly where an error occurs while validating the first trials.
dbstop if error

cfg = struct;

% Toolkit root: add the folder containing +opensimio, +modelprep,
% and +opensimrun. Do not add the package folders themselves.
cfg.toolkitRoot = ...
    "C:\Users\drewbossert\Code\headneck_pipeline_toolkit";

% Trial identity.
cfg.conditionDeg = 0;
cfg.trialNumber = 1;

% Clean source inputs.
cfg.baseModelFile = ...
    "C:\path\to\models\infant_4mo_scaled_base.osim";

cfg.markerFile = ...
    "C:\path\to\markers\condition00_trial01.trc";

cfg.ikTemplateFile = ...
    "C:\path\to\templates\ik_setup_template.xml";

% Time range must lie within the marker file. Enter the verified trial
% range used in the existing working IK setup.
cfg.initialTime = 0.00;
cfg.finalTime = 19.99;

% Output root for this validation project.
cfg.projectOutputRoot = ...
    "C:\path\to\infant_head_neck_reprocessing\output";

% Execution controls.
cfg.overwriteExisting = true;
cfg.executeIk = true;

% Expected model structure.
cfg.expectedCoordinateCount = 30;
cfg.expectedConstraintCount = 18;

% Coordinates highlighted in the first-pass audit.
cfg.reviewCoordinates = [ ...
    "pitch2"
    "roll2"
    "yaw2"
    "aux7jnt_r3"
    "aux7jnt_r1"
    "aux7jnt_r2"
    "aux6jnt_r3"
    "aux6jnt_r1"
    "aux6jnt_r2"
    "aux5jnt_r3"
    "aux5jnt_r1"
    "aux5jnt_r2"
    "aux4jnt_r3"
    "aux4jnt_r1"
    "aux4jnt_r2"
    "aux3jnt_r3"
    "aux3jnt_r1"
    "aux3jnt_r2"
    "pitch1"
    "roll1"
    "yaw1"
    "aux1jnt_r3"
    "aux1jnt_r1"
    "aux1jnt_r2"
];

fprintf("Configured condition %g deg, trial %d.\n", ...
    cfg.conditionDeg, cfg.trialNumber);


%% SECTION 1 — INITIALIZE TOOLKIT AND VALIDATE INPUTS

assert(isfolder(cfg.toolkitRoot), ...
    "TrialPipeline:ToolkitNotFound", ...
    "Toolkit root was not found:\n%s", cfg.toolkitRoot);

addpath(cfg.toolkitRoot);

% Confirm that MATLAB resolves the intended package functions.
requiredFunctions = [ ...
    "opensimio.readMot"
    "opensimio.readXml"
    "modelprep.buildInitializationModel"
    "modelprep.validateModelConfiguration"
    "opensimrun.prepareInverseKinematicsSetup"
    "opensimrun.runInverseKinematicsSetup"
];

for functionName = requiredFunctions.'
    resolvedFile = which(functionName);

    if isempty(resolvedFile)
        error("TrialPipeline:FunctionNotFound", ...
            "Required function is not on the MATLAB path: %s", ...
            functionName);
    end

    fprintf("%-52s %s\n", functionName, resolvedFile);
end

inputFiles = [ ...
    string(cfg.baseModelFile)
    string(cfg.markerFile)
    string(cfg.ikTemplateFile)
];

inputLabels = [ ...
    "Base model"
    "Marker file"
    "IK template"
];

for inputIndex = 1:numel(inputFiles)
    assert(isfile(inputFiles(inputIndex)), ...
        "TrialPipeline:InputNotFound", ...
        "%s was not found:\n%s", ...
        inputLabels(inputIndex), inputFiles(inputIndex));
end

assert(cfg.finalTime > cfg.initialTime, ...
    "TrialPipeline:InvalidTimeRange", ...
    "finalTime must be greater than initialTime.");

fprintf("Input validation passed.\n");


%% SECTION 2 — DEFINE TRIAL OUTPUT PATHS

conditionFolderName = sprintf( ...
    "%02ddeg", round(cfg.conditionDeg));

trialFolderName = sprintf( ...
    "trial%02d", cfg.trialNumber);

trialRoot = fullfile( ...
    cfg.projectOutputRoot, ...
    conditionFolderName, ...
    trialFolderName);

initializationDirectory = fullfile( ...
    trialRoot, ...
    "01_initialization_ik");

qcDirectory = fullfile( ...
    initializationDirectory, ...
    "qc");

if ~isfolder(initializationDirectory)
    mkdir(initializationDirectory);
end

if ~isfolder(qcDirectory)
    mkdir(qcDirectory);
end

paths = struct;

paths.trialRoot = string(trialRoot);
paths.initializationDirectory = string(initializationDirectory);
paths.qcDirectory = string(qcDirectory);

paths.modelAFile = string(fullfile( ...
    initializationDirectory, ...
    sprintf("%s_%s_modelA_initialization.osim", ...
    conditionFolderName, trialFolderName)));

paths.ikSetupFile = string(fullfile( ...
    initializationDirectory, ...
    sprintf("%s_%s_initialization_ik_setup.xml", ...
    conditionFolderName, trialFolderName)));

paths.ikMotionFile = string(fullfile( ...
    initializationDirectory, ...
    sprintf("%s_%s_initialization_ik.mot", ...
    conditionFolderName, trialFolderName)));

paths.coordinateConfigurationCsv = string(fullfile( ...
    qcDirectory, ...
    "modelA_coordinate_configuration.csv"));

paths.constraintConfigurationCsv = string(fullfile( ...
    qcDirectory, ...
    "modelA_constraint_configuration.csv"));

paths.motionCoordinateAuditCsv = string(fullfile( ...
    qcDirectory, ...
    "initialization_ik_coordinate_audit.csv"));

paths.runSummaryMat = string(fullfile( ...
    qcDirectory, ...
    "initialization_ik_checkpoint.mat"));

disp(paths);


%% SECTION 3 — BUILD MODEL A

if isfile(paths.modelAFile) && ~cfg.overwriteExisting
    error("TrialPipeline:OutputExists", ...
        "Model A already exists:\n%s", paths.modelAFile);
end

modelAResult = modelprep.buildInitializationModel( ...
    cfg.baseModelFile, ...
    paths.modelAFile);

fprintf("Model A written:\n%s\n", paths.modelAFile);

writetable( ...
    modelAResult.Inspection.Coordinates, ...
    paths.coordinateConfigurationCsv);

writetable( ...
    modelAResult.Inspection.Constraints, ...
    paths.constraintConfigurationCsv);


%% SECTION 4 — VALIDATE MODEL A CONFIGURATION

modelAInspection = modelprep.inspectModel(paths.modelAFile);

coordinateCount = height(modelAInspection.Coordinates);
constraintCount = height(modelAInspection.Constraints);

fprintf("Coordinate count: %d\n", coordinateCount);
fprintf("Constraint count: %d\n", constraintCount);

assert(coordinateCount == cfg.expectedCoordinateCount, ...
    "TrialPipeline:UnexpectedCoordinateCount", ...
    "Expected %d coordinates but found %d.", ...
    cfg.expectedCoordinateCount, coordinateCount);

assert(constraintCount == cfg.expectedConstraintCount, ...
    "TrialPipeline:UnexpectedConstraintCount", ...
    "Expected %d constraints but found %d.", ...
    cfg.expectedConstraintCount, constraintCount);

allCoordinateNames = ...
    modelAInspection.Coordinates.Coordinate;

modelAValidation = modelprep.validateModelConfiguration( ...
    paths.modelAFile, ...
    "ExpectedUnlocked", allCoordinateNames, ...
    "ExpectedConstraintsEnforced", true, ...
    "ThrowOnFailure", true);

assert(modelAValidation.Passed, ...
    "TrialPipeline:ModelAValidationFailed", ...
    "Model A configuration validation failed.");

fprintf([ ...
    "Model A validation passed: all coordinates unlocked and " ...
    "all constraints enabled.\n"]);


%% SECTION 5 — CREATE THE TRIAL-SPECIFIC IK SETUP

if isfile(paths.ikSetupFile) && ~cfg.overwriteExisting
    error("TrialPipeline:OutputExists", ...
        "IK setup already exists:\n%s", paths.ikSetupFile);
end

ikSetupResult = opensimrun.prepareInverseKinematicsSetup( ...
    cfg.ikTemplateFile, ...
    paths.ikSetupFile, ...
    "ModelFile", paths.modelAFile, ...
    "MarkerFile", cfg.markerFile, ...
    "OutputMotionFile", paths.ikMotionFile, ...
    "TimeRange", [cfg.initialTime, cfg.finalTime], ...
    "ToolName", sprintf( ...
        "%s_%s_initialization_ik", ...
        conditionFolderName, trialFolderName), ...
    "Overwrite", cfg.overwriteExisting);

disp(ikSetupResult.PatchReport);

fprintf("Patched IK setup written:\n%s\n", ...
    paths.ikSetupFile);

% CHECKPOINT:
% Open this XML and confirm that the model, marker file, output file, time
% range, marker task weights, constraint weight, and accuracy are correct
% before running SECTION 6.


%% SECTION 6 — RUN INITIALIZATION IK

if ~cfg.executeIk
    fprintf([ ...
        "IK execution is disabled. Set cfg.executeIk=true after " ...
        "reviewing the setup file.\n"]);
else
    ikRunResult = opensimrun.runInverseKinematicsSetup( ...
        paths.ikSetupFile, ...
        "ExpectedOutputMotionFile", paths.ikMotionFile, ...
        "Overwrite", cfg.overwriteExisting);

    fprintf("Initialization IK completed in %.3f seconds.\n", ...
        ikRunResult.DurationSeconds);

    fprintf("IK motion file:\n%s\n", ...
        ikRunResult.OutputMotionFile);
end


%% SECTION 7 — BASIC INITIALIZATION-IK OUTPUT AUDIT

assert(isfile(paths.ikMotionFile), ...
    "TrialPipeline:IkMotionMissing", ...
    "Initialization IK output was not found:\n%s", ...
    paths.ikMotionFile);

ikMotion = opensimio.readMot(paths.ikMotionFile);

assert(all(isfinite(ikMotion.Time)), ...
    "TrialPipeline:InvalidIkTime", ...
    "IK time vector contains non-finite values.");

assert(all(diff(ikMotion.Time) > 0), ...
    "TrialPipeline:NonmonotonicIkTime", ...
    "IK time vector is not strictly increasing.");

assert(all(isfinite(ikMotion.Data), "all"), ...
    "TrialPipeline:NonfiniteIkData", ...
    "IK output contains non-finite coordinate values.");

normalizedLabels = strings(size(ikMotion.Labels));

for labelIndex = 1:numel(ikMotion.Labels)
    label = string(ikMotion.Labels(labelIndex));
    label = regexprep(label, "/value$", "");
    labelParts = split(label, "/");
    labelParts = labelParts(strlength(labelParts) > 0);

    if isempty(labelParts)
        normalizedLabels(labelIndex) = label;
    else
        normalizedLabels(labelIndex) = labelParts(end);
    end
end

modelCoordinates = modelAInspection.Coordinates.Coordinate;

missingCoordinateColumns = setdiff( ...
    modelCoordinates, normalizedLabels, "stable");

if ~isempty(missingCoordinateColumns)
    error("TrialPipeline:MissingIkCoordinates", ...
        "IK output is missing coordinate columns: %s", ...
        strjoin(missingCoordinateColumns, ", "));
end

reviewCoordinates = intersect( ...
    cfg.reviewCoordinates, ...
    modelCoordinates, ...
    "stable");

nReviewCoordinates = numel(reviewCoordinates);

Coordinate = reviewCoordinates;
CoordinateType = strings(nReviewCoordinates, 1);
MinimumDisplay = nan(nReviewCoordinates, 1);
MaximumDisplay = nan(nReviewCoordinates, 1);
RangeDisplay = nan(nReviewCoordinates, 1);
StandardDeviationDisplay = nan(nReviewCoordinates, 1);
DisplayUnit = strings(nReviewCoordinates, 1);

for coordinateIndex = 1:nReviewCoordinates
    coordinateName = reviewCoordinates(coordinateIndex);

    motionColumn = find( ...
        normalizedLabels == coordinateName, 1);

    modelRow = find( ...
        modelAInspection.Coordinates.Coordinate == ...
        coordinateName, 1);

    coordinateType = ...
        modelAInspection.Coordinates.CoordinateType(modelRow);

    values = ikMotion.Data(:, motionColumn);

    if coordinateType == "rotation"
        if islogical(ikMotion.InDegrees) && ikMotion.InDegrees
            displayValues = values;
        else
            displayValues = rad2deg(values);
        end

        displayUnit = "deg";
    else
        displayValues = values;
        displayUnit = "m";
    end

    CoordinateType(coordinateIndex) = coordinateType;
    MinimumDisplay(coordinateIndex) = ...
        min(displayValues, [], "omitnan");
    MaximumDisplay(coordinateIndex) = ...
        max(displayValues, [], "omitnan");
    RangeDisplay(coordinateIndex) = ...
        MaximumDisplay(coordinateIndex) - ...
        MinimumDisplay(coordinateIndex);
    StandardDeviationDisplay(coordinateIndex) = ...
        std(displayValues, "omitnan");
    DisplayUnit(coordinateIndex) = displayUnit;
end

coordinateAudit = table( ...
    Coordinate, CoordinateType, ...
    MinimumDisplay, MaximumDisplay, ...
    RangeDisplay, StandardDeviationDisplay, ...
    DisplayUnit, ...
    'VariableNames', { ...
        'Coordinate', 'CoordinateType', ...
        'MinimumDisplay', 'MaximumDisplay', ...
        'RangeDisplay', 'StandardDeviationDisplay', ...
        'DisplayUnit'});

writetable( ...
    coordinateAudit, ...
    paths.motionCoordinateAuditCsv);

disp(coordinateAudit);

% Highlight C4-C5 and all out-of-plane motion for immediate review.
groups = modelprep.coordinateGroups();

attentionCoordinates = unique([ ...
    "aux4jnt_r3"
    "aux4jnt_r1"
    "aux4jnt_r2"
    groups.IndependentOutOfPlane
    groups.DependentOutOfPlane
], "stable");

attentionAudit = coordinateAudit( ...
    ismember(coordinateAudit.Coordinate, ...
    attentionCoordinates), :);

fprintf("\nCoordinates requiring immediate visual review:\n");
disp(attentionAudit);


%% SECTION 8 — SAVE CHECKPOINT AND REPORT NEXT ACTION

checkpoint = struct;
checkpoint.Configuration = cfg;
checkpoint.Paths = paths;
checkpoint.ModelAResult = modelAResult;
checkpoint.ModelAValidation = modelAValidation;
checkpoint.IkSetupResult = ikSetupResult;
checkpoint.IkMotionSummary = struct( ...
    "NumRows", ikMotion.NumRows, ...
    "NumColumns", ikMotion.NumColumns, ...
    "StartTime", ikMotion.Time(1), ...
    "EndTime", ikMotion.Time(end), ...
    "InDegrees", ikMotion.InDegrees);
checkpoint.CoordinateAudit = coordinateAudit;
checkpoint.AttentionAudit = attentionAudit;

if exist("ikRunResult", "var")
    checkpoint.IkRunResult = rmfield( ...
        ikRunResult, ...
        intersect(fieldnames(ikRunResult), ...
        {'Tool'}));
end

save(paths.runSummaryMat, "checkpoint");

fprintf("\nInitialization-IK checkpoint saved:\n%s\n", ...
    paths.runSummaryMat);

fprintf("\nNEXT MANUAL CHECKS\n");
fprintf("1. Open Model A and the initialization IK motion in OpenSim.\n");
fprintf("2. Review marker fit and the C4-C5 segmental rotations.\n");
fprintf("3. Confirm that constraints prevented nonphysiological motion.\n");
fprintf("4. Review IK marker RMS and maximum errors from the OpenSim log.\n");
fprintf("5. If acceptable, proceed to stable-window lock extraction and Model B.\n");
