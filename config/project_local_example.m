%% project_local_example.m
% Copy this file to:
%
%   config/project_local.m
%
% Edit only project_local.m. The local file is excluded from Git.
%
% Canonical configuration contract:
%   - Machine-specific paths/settings belong here.
%   - Study design (conditions/trials) lives in project_defaults.m.
%   - Batch parallel settings live under cfg.batchProcessing.
%   - Shared overwrite behavior remains cfg.overwriteExisting.

%% Machine identity

cfg.machineName = "my-machine-name";

%% Raw data location

% This can be outside the repository.
cfg.rawDataRoot = ...
    "C:\path\to\experimental\data";

%% Output location

% Leave this line commented to use:
%   <repository>\output
%
% cfg.outputRoot = ...
%     "D:\headneck_pipeline_outputs";

%% OpenSim installation

% Leave empty if OpenSim is already configured when MATLAB starts.
cfg.opensimRoot = "";

% Optional explicit paths if this machine needs manual configuration.
cfg.openSimJavaJar = "";
cfg.openSimBinDirectory = "";

%% Local runtime settings

% Shared overwrite behavior for single-trial and batch workflows.
cfg.overwriteExisting = false;

% Batch processing settings.
cfg.batchProcessing.enableParallel = false;
cfg.batchProcessing.maxWorkers = 4;

%% Optional local study subset
%
% Normally leave the version-controlled study design in project_defaults.m:
%
%   cfg.conditions = [0 15 30 45];
%   cfg.trials = 1:5;
%
% Uncomment only when intentionally restricting a machine/session to a
% subset of the study.
%
% cfg.conditions = [0 15];
% cfg.trials = 1:2;

%% Optional force-capacity profile
%
% The shared defaults leave force-capacity configuration disabled.
% Uncomment these only when this machine/session should apply a saved
% sensitivity profile.
%
% cfg.forceCapacity.enabled = true;
% cfg.forceCapacity.configFile = fullfile( ...
%     cfg.projectRoot, ...
%     "config", ...
%     "force_capacity", ...
%     "example_force_config.json");
% cfg.forceCapacity.applyMode = "target";
% cfg.forceCapacity.requireAllEntries = true;
