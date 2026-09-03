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

%% Raw data location

cfg.rawDataRoot = ...
    "C:\path\to\experimental\data";

%% Output location

% Leave commented to use:
%   <repository>\output
%
% cfg.outputRoot = ...
%     "D:\headneck_pipeline_outputs";

%% Optional local execution overrides

% Uncomment only settings that differ from project_defaults.m.
%
% cfg.overwriteExisting = true;
% cfg.batchProcessing.enableParallel = true;
% cfg.batchProcessing.maxWorkers = 4;
% cfg.batchProcessing.poolProfile = "local";

%% Optional force-capacity profile
%
% This selects a profile for a direct Process-3 run. The Static Optimization
% strength-search controller uses the explicit fixedGrid and adaptiveBoundary
% paths in project_defaults.m instead.
%
% cfg.forceCapacity.enabled = true;
% cfg.forceCapacity.configFile = ...
%     "C:\path\to\force_capacity_profile.json";

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
