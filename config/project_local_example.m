%% project_local_example.m
% Copy this file to:
%
%   config/project_local.m
%
% Edit only project_local.m. The local file is excluded from Git.
%
% project_local.m should contain MACHINE-SPECIFIC settings only.
% Study/scientific settings belong in project_defaults.m so different
% machines cannot silently run different experimental configurations.

%% Machine identity

cfg.machineName = "my-machine-name";

%% Raw data location

cfg.rawDataRoot = ...
    "C:\path\to\experimental\data";

%% Output location

% Leave commented to use:
%   <repository>\output
%
% cfg.outputRoot = ...
%     "D:\headneck_pipeline_outputs";

%% OpenSim installation

% Leave empty if OpenSim is already configured when MATLAB starts.
cfg.opensimRoot = "";

% Optional explicit paths when manual OpenSim configuration is required.
cfg.openSimJavaJar = "";
cfg.openSimBinDirectory = "";

%% Shared local execution behavior

cfg.overwriteExisting = false;

%% Batch runtime settings

cfg.batchProcessing.enableParallel = false;
cfg.batchProcessing.maxWorkers = 4;
cfg.batchProcessing.continueOnError = true;
cfg.batchProcessing.poolProfile = "local";
cfg.batchProcessing.closePoolWhenFinished = false;

%% Optional force-capacity profile
%
% This is an appropriate local override when running a specific sensitivity
% profile from a machine-local or ignored JSON configuration.
%
% cfg.forceCapacity.enabled = true;
% cfg.forceCapacity.configFile = ...
%     "C:\path\to\force_capacity_profile.json";
% cfg.forceCapacity.applyMode = "target";
% cfg.forceCapacity.requireAllEntries = true;
% cfg.forceCapacity.applyStages = "modelC";

%% Intentionally NOT overridden here
%
% Keep the following in project_defaults.m:
%
%   cfg.conditions
%   cfg.trials
%   cfg.pipeline.*
%   cfg.qc.*
%   cfg.hsf.*
%   cfg.analysis.*
%
% For a temporary smoke-test subset, pass explicit conditions/trials to the
% example/batch orchestration layer rather than changing project_local.m.