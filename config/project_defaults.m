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