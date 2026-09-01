%% project_defaults.m
% Shared, version-controlled project configuration.
%
% This script is executed by load_project_config(). The variables:
%
%   cfg
%   projectRoot
%
% already exist when this script runs.
%
% Configuration philosophy:
%   - Study/scientific settings belong here and are version controlled.
%   - Machine-specific paths/runtime overrides belong in project_local.m.
%   - Per-trial identity belongs in trial context, not global config.
%   - Package-function implementation defaults remain inside the package
%     functions unless the project deliberately standardizes them.

%% Configuration metadata

cfg.configSchemaVersion = 2;
cfg.projectName = "headneck-pipeline-toolkit";

%% Repository directories

cfg.batchDirectory = fullfile( ...
    projectRoot, ...
    "batch");

cfg.configDirectory = fullfile( ...
    projectRoot, ...
    "config");
    
cfg.examplesDirectory = fullfile( ...
    projectRoot, ...
    "examples");

cfg.inputDirectory = fullfile( ...
    projectRoot, ...
    "input");
    
cfg.templatesDirectory = fullfile( ...
    cfg.inputDirectory, ...
    "templates");

cfg.modelsDirectory = fullfile( ...
    projectRoot, ...
    "models");

% Default output location. project_local.m may override this.
cfg.outputRoot = fullfile( ...
    projectRoot, ...
    "output");

cfg.testsDirectory = fullfile( ...
    projectRoot, ...
    "tests");

%% Study design

% Canonical study matrix. Batch job enumeration should use these values.
% Thin example drivers may select one trial without modifying projectCfg.
cfg.conditions = [0 15 30 45];
cfg.trials = 1:5;

%% Shared model files

cfg.kinematicBaseModel = fullfile( ...
    cfg.modelsDirectory, ...
    "4-mo_kine-only.osim");

cfg.scalingBaseModel = fullfile( ...
    cfg.modelsDirectory, ...
    "4-mo_with-scaling.osim");

%% Shared setup templates

cfg.initializationIkTemplate = fullfile( ...
    cfg.templatesDirectory, ...
    "ik_setup_template.xml");

cfg.externalLoadsTemplate = fullfile( ...
    cfg.templatesDirectory, ...
    "external_loads_template.xml");

cfg.staticOptimizationTemplate = fullfile( ...
    cfg.templatesDirectory, ...
    "so_setup_template.xml");

%% Expected project resources

cfg.requireKinematicBaseModel = true;
cfg.requireScalingBaseModel = true;
cfg.requireInitializationIkTemplate = true;
cfg.requireExternalLoadsTemplate = true;
cfg.requireStaticOptimizationTemplate = true;

%% Shared execution behavior

% All file-producing pipeline stages should consume this value explicitly.
% Package-level functions should still default to non-destructive behavior.
% project_local.m may override this to true for a machine-local workflow.
cfg.overwriteExisting = false;

%% Storage and artifact retention

cfg.storage = struct;

% ---------------------------------------------------------------------
% Static Optimization artifacts
% ---------------------------------------------------------------------

cfg.storage.staticOptimization = struct;

% OpenSim-generated controls XML can be several MB per trial and is not
% required by the current downstream QC/statistical workflow.
cfg.storage.staticOptimization.keepControlsXml = false;

% Retain reproducibility/scientific outputs by default.
cfg.storage.staticOptimization.keepSetupXml = true;
cfg.storage.staticOptimization.keepForceSto = true;
cfg.storage.staticOptimization.keepActivationSto = true;
cfg.storage.staticOptimization.keepQc = true;
cfg.storage.staticOptimization.keepCheckpoint = true;

% ---------------------------------------------------------------------
% Shared Static Optimization preparation
% ---------------------------------------------------------------------

cfg.storage.sharedStaticOptimizationPrep = struct;

% These artifacts form the reusable per-trial Process-3 cache.
% Their retention settings are intended for explicit end-of-workflow
% pruning, not immediate deletion during configuration searches.
cfg.storage.sharedStaticOptimizationPrep.keepNeutralModelC = true;
cfg.storage.sharedStaticOptimizationPrep.keepBodyKinematics = true;
cfg.storage.sharedStaticOptimizationPrep.keepComCsv = true;
cfg.storage.sharedStaticOptimizationPrep.keepEventTiming = true;
cfg.storage.sharedStaticOptimizationPrep.keepHsfMotion = true;
cfg.storage.sharedStaticOptimizationPrep.keepExternalLoadsXml = true;
cfg.storage.sharedStaticOptimizationPrep.keepQc = true;
cfg.storage.sharedStaticOptimizationPrep.keepCheckpoint = true;

%% Expected model structure

cfg.modelValidation = struct;

cfg.modelValidation.expectedCoordinateCount = 30;
cfg.modelValidation.expectedConstraintCount = 18;

%% Pipeline stage policy
%
% These fields define settings that must remain identical between thin
% example drivers and batch workers.

cfg.pipeline = struct;

% ---------------------------------------------------------------------
% Input parser parameters
% ---------------------------------------------------------------------

cfg.pipeline.trialInput = struct;

cfg.pipeline.trialInput.markerFilePattern = ...
    "%dDEG%04d.trc";
    
% ---------------------------------------------------------------------
% Process 1 / Model A / initialization IK
% ---------------------------------------------------------------------

cfg.pipeline.initializationIk = struct;

% Validated acquisition window used by the current 20-second trials.
cfg.pipeline.initializationIk.timeRangeSec = [0.00 19.99];

% Coordinates retained in the Process-1 motion audit. These do not change
% the IK solution; they define the shared QC report used by both the
% single-trial example and Batch Process 1.
cfg.pipeline.initializationIk.reviewCoordinates = [
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

% ---------------------------------------------------------------------
% Process 2 / Model B / final IK
% ---------------------------------------------------------------------

cfg.pipeline.modelB = struct;

% Supported-pose interval used for lock-value extraction.
% This is intentionally centralized so single-trial and batch workflows
% cannot silently use different intervals.
cfg.pipeline.modelB.lockWindowSec = [0.10 0.15];

% ---------------------------------------------------------------------
% Process 3 / Model C / SO preparation
% ---------------------------------------------------------------------

cfg.pipeline.staticOptimizationPrep = struct;

% -1 disables additional Body Kinematics low-pass filtering.
cfg.pipeline.staticOptimizationPrep.bodyKinematicsLowpassCutoffHz = -1;

% Empty means use the complete validated final-IK time range.
cfg.pipeline.staticOptimizationPrep.timeRangeSec = [];

cfg.pipeline.staticOptimization = struct;

% Require the two canonical Static Optimization result files.
cfg.pipeline.staticOptimization.requireForceOutput = true;
cfg.pipeline.staticOptimization.requireActivationOutput = true;

% Endpoint/path time-range validation tolerance used by the SO runner.
% The runner separately accounts for output decimation from step_interval.
cfg.pipeline.staticOptimization.timeToleranceSec = 1e-6;

% Activation/control saturation is treated as failed Static Optimization.
cfg.pipeline.staticOptimization.requireUnsaturatedActivations = true;

% Absolute activation/control limit and numerical comparison tolerance.
cfg.pipeline.staticOptimization.activationSaturationLimit = 1.0;
cfg.pipeline.staticOptimization.activationSaturationTolerance = 1e-3;

%% Locked-coordinate audit criteria

cfg.qc = struct;

cfg.qc.lockAudit = struct;

cfg.qc.lockAudit.statistic = "median";

cfg.qc.lockAudit.rotationRangeToleranceDeg = 1e-6;
cfg.qc.lockAudit.translationRangeToleranceM = 1e-8;
cfg.qc.lockAudit.otherRangeToleranceSI = 1e-10;

cfg.qc.lockAudit.rotationMatchToleranceDeg = 1e-5;
cfg.qc.lockAudit.translationMatchToleranceM = 1e-8;
cfg.qc.lockAudit.otherMatchToleranceSI = 1e-9;

cfg.qc.lockAudit.minimumSamples = 2;
cfg.qc.lockAudit.requirePass = true;

%% Model B lock-value extraction criteria

cfg.qc.lockExtraction = struct;

cfg.qc.lockExtraction.statistic = "median";

cfg.qc.lockExtraction.rotationToleranceDeg = 0.75;
cfg.qc.lockExtraction.translationToleranceM = 2e-3;
cfg.qc.lockExtraction.otherToleranceSI = 1e-8;

cfg.qc.lockExtraction.minimumSamples = 2;
cfg.qc.lockExtraction.requireStable = true;

%% Model B lock-extraction filtering

cfg.qc.lockExtractionFilter = struct;

cfg.qc.lockExtractionFilter.enabled = true;

% Channels retained for cutoff-sensitivity/QC assessment.
cfg.qc.lockExtractionFilter.assessmentCoordinates = [
    "roll1"
    "yaw1"
    "roll2"
    "yaw2"
];

% Channels filtered in the validated production workflow.
cfg.qc.lockExtractionFilter.filterCoordinates = [
    "yaw1"
    "yaw2"
];

cfg.qc.lockExtractionFilter.candidateCutoffsHz = [
    0.5
    1.0
    2.0
    3.0
];

cfg.qc.lockExtractionFilter.prototypeOrder = 2;

% Diagnostic plot interval only.
cfg.qc.lockExtractionFilter.plotWindow = [0.00 1.00];

% Validated production cutoff.
% Second-order Butterworth + filtfilt gives a fourth-order zero-phase
% magnitude response.
cfg.qc.lockExtractionFilter.selectedCutoffHz = 1.0;

%% HSF contact-event detection

cfg.qc.hsfEventDetection = struct;

% Empty -> detector uses its validated default initial baseline interval.
cfg.qc.hsfEventDetection.baselineWindow = [];

cfg.qc.hsfEventDetection.liftOffThresholdM = 0.00150;
cfg.qc.hsfEventDetection.recontactThresholdM = 0.00149;

cfg.qc.hsfEventDetection.minimumAboveDurationSec = 0.10;
cfg.qc.hsfEventDetection.minimumBelowDurationSec = 0.10;

% Detection-only moving-median window.
cfg.qc.hsfEventDetection.smoothingWindowSec = 0.05;

% Empty -> search after the baseline through the end of the trajectory.
cfg.qc.hsfEventDetection.searchWindow = [];

%% Head-support-force formulation
%
% This project-level structure mirrors the validated HSF parameter names
% used by +hsf so example and batch workers can create one identical
% Parameters struct.
%
% useModelBodyMass=true means a future pipeline worker should overwrite
% Parameters.SkullMassKg from the generated model before HSF synthesis.
% The fallback value below equals the current production skull mass.

cfg.hsf = struct;

cfg.hsf.useModelBodyMass = true;

cfg.hsf.Parameters = struct;

cfg.hsf.Parameters.BodyName = "skull";
cfg.hsf.Parameters.SkullMassKg = 1.1704014720812095;
cfg.hsf.Parameters.GravityY = -9.80665;
cfg.hsf.Parameters.TargetRateHz = 1000;
cfg.hsf.Parameters.RampDuration = 0.10;
cfg.hsf.Parameters.RampShape = "halfcosine";
cfg.hsf.Parameters.RadialSign = 1;
cfg.hsf.Parameters.AzimuthConvention = "x_cos_z_sin";
cfg.hsf.Parameters.InterpolationMethod = "pchip";
cfg.hsf.Parameters.ForcePrefix = "ground_force_1_v";
cfg.hsf.Parameters.PointPrefix = "ground_force_1_p";

%% Force-capacity configuration

cfg.forceCapacity = struct;

cfg.forceCapacity.enabled = false;
cfg.forceCapacity.configFile = "";

% "target" is recommended for pipeline use because it is idempotent.
% "scale" applies the saved factor to the target model's current value and
% can compound if applied repeatedly.
cfg.forceCapacity.applyMode = "target";

cfg.forceCapacity.requireAllEntries = true;

% Default application point. IK is force-independent, so Model C is the
% first stage that needs the configured ForceSet for the current workflow.
% Future workers may support additional stages without changing the JSON
% schema.
cfg.forceCapacity.applyStages = "modelC";

%% Static Optimization analysis / plotting

cfg.analysis = struct;
cfg.analysis.staticOptimization = struct;

analysisCfg = cfg.analysis.staticOptimization;

% Optional exclusions as [condition_deg trial_num].
analysisCfg.excludedTrials = zeros(0,2);

% Piecewise normalization:
%   0-20   initial support
%   20-80  active/off-support motion
%   80-100 final support
analysisCfg.normalizedBreaksPercent = [0 20 80 100];
analysisCfg.pointsPerPhase = [200 600 200];

% All reported force/reserve summary statistics use this ROI only.
analysisCfg.statisticsWindowPercent = [20 80];

% Lift-off-to-re-contact data are cropped from the full piecewise
% normalization and remapped to this range for pooled analysis.
analysisCfg.motionOutputWindowPercent = [0 100];

% Primary extensor landmark within the lift-off-to-re-contact motion.
analysisCfg.extensorLandmarkPercent = 50;

% Functional groups are authoritative ObjectGroups in the model.
analysisCfg.flexionGroupName = "flexion";
analysisCfg.extensionGroupName = "extension";

% Current production model:
%   flexion  = 8 unilateral members -> 16 bilateral
%   extension = 18 unilateral members -> 36 bilateral
analysisCfg.expectedFlexorCount = 16;
analysisCfg.expectedExtensorCount = 36;

analysisCfg.topReserveCount = 10;

% Plot formatting.
analysisCfg.conditionLegendOrderDeg = cfg.conditions;
analysisCfg.yAxisLowerLimit = 0;
analysisCfg.yAxisHeadroomFraction = 0.05;

cfg.analysis.staticOptimization = analysisCfg;

clear analysisCfg

%% Batch processing configuration

cfg.batchProcessing = struct;

cfg.batchProcessing.enableParallel = false;
cfg.batchProcessing.maxWorkers = 4;

% Continue other jobs when one trial fails; collect errors in the batch
% summary rather than terminating the entire study.
cfg.batchProcessing.continueOnError = true;

% MATLAB parallel profile.
cfg.batchProcessing.poolProfile = "local";

% Leave an existing pool running after the batch script finishes.
cfg.batchProcessing.closePoolWhenFinished = false;
