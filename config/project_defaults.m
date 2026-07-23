%% project_defaults.m
% Shared, version-controlled project configuration.
%
% This script is called from load_project_config(). The variables cfg and
% projectRoot already exist when this script runs.

%% Repository directories

cfg.modelsDirectory = fullfile( ...
    projectRoot, ...
    "models");

cfg.inputDirectory = fullfile( ...
    projectRoot, ...
    "input");

cfg.templatesDirectory = fullfile( ...
    cfg.inputDirectory, ...
    "templates");

cfg.examplesDirectory = fullfile( ...
    projectRoot, ...
    "examples");

% Default output location. A local config may override this.
cfg.outputRoot = fullfile( ...
    projectRoot, ...
    "output");

%% Shared model files

% Update these names to match the files currently in models/.
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

%% Default execution behavior

cfg.overwriteExisting = false;
cfg.enableParallel = false;
cfg.maxWorkers = 4;

%% Expected project resources

cfg.requireKinematicBaseModel = true;
cfg.requireScalingBaseModel = true;
cfg.requireInitializationIkTemplate = true;

%% Locked-coordinate audit criteria

cfg.qc.lockAudit = struct;

cfg.qc.lockAudit.statistic = "median";

cfg.qc.lockAudit.rotationRangeTolerance = 1e-6;
cfg.qc.lockAudit.translationRangeToleranceM = 1e-10;
cfg.qc.lockAudit.otherRangeToleranceSI = 1e-10;

cfg.qc.lockAudit.rotationMatchToleranceDeg = 1e-5;
cfg.qc.lockAudit.translationMatchToleranceM = 1e-9;
cfg.qc.lockAudit.otherMatchToleranceSI = 1e-9;

cfg.qc.lockAudit.minimumSamples = 2;
cfg.qc.lockAudit.requirePass = true;

%% Model B lock-value extraction criteria

cfg.qc.lockExtraction = struct;

% Statistic used to define the coordinate default and lock value.
cfg.qc.lockExtraction.statistic = "median";

% Maximum coordinate range allowed within the selected initial support window before the value is considered unstable.
cfg.qc.lockExtraction.rotationToleranceDeg = 0.05;
cfg.qc.lockExtraction.translationToleranceM = 1e-5;
cfg.qc.lockExtraction.otherToleranceSI = 1e-8;

cfg.qc.lockExtraction.minimumSamples = 10;
cfg.qc.lockExtraction.requireStable = true;