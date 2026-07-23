%% project_local_example.m
% Copy this file to:
%
%   config/project_local.m
%
% Edit only project_local.m. The local file is excluded from Git.

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
%    "D:\headneck_pipeline_outputs";

%% OpenSim installation

% Leave empty if OpenSim is already configured when MATLAB starts.
cfg.opensimRoot = "";

% Optional explicit paths if this machine needs manual configuration.
cfg.openSimJavaJar = "";
cfg.openSimBinDirectory = "";

%% Local runtime settings

cfg.enableParallel = false;
cfg.maxWorkers = 4;
cfg.overwriteExisting = false;