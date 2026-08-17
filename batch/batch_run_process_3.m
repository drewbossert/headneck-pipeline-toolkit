%%                         batch_run_process_3.m                         %%
% ======================================================================= %
% Process 3 description here                                              %
%                                                                         %
%                                                                         %
%                                                                         %
%                                                                         %
%                                                                         %
%                                                                         %
%                                                                         %
%                                                                         %
%                                                                         %
%                                                                         %
%                                                                         %
%                                                                         %
% ======================================================================= %

%% SECTION 0 — PROJECT CONFIGURATION

clear; clc; dbstop if error

activeFile = string( ...
    matlab.desktop.editor.getActiveFilename);

assert(strlength(activeFile) > 0 && isfile(activeFile), ...
    "BatchProcessing:ActiveScriptUnknown", ...
    "Open and save this script in the MATLAB Editor before running.");

batchDirectory = string(fileparts(activeFile));
projectRoot = string(fileparts(batchDirectory));

addpath(projectRoot);

projectCfg = load_project_config();

%% TODO define any necessary script-specific config params
processCfg = struct;
processCfg.overwriteExisting = ...
    projectCfg.overwriteExisting;

nConds = numel(projectCfg.conditions);
nTrials = numel(projectCfg.trials);

processCfg.overwriteExisting = ...
    projectCfg.overwriteExisting;

processCfg.executeBodyKinematics = true;

% Setting lowpass cutoff frequency to -1 disables additional filtering
processCfg.bodyKinematicsLowpassHzCutoff = -1;

% Empty array defaults to full IK range
processCfg.timeRange = [];

processCfg.eventDetection = ...
    projectCfg.qc.hsfEventDetection;

%% TODO Create/validate I/O paths

%% TODO initialize pool
nWorkers = projectCfg.batchProcessing.maxWorkers;

% pool = gcp("nocreate");
% 
% if isempty(pool)
%     parpool("local", nWorkers);
% elseif pool.NumWorkers ~= nWorkers
%     delete(pool);
%     parpool("local", nWorkers);
% end

%% TODO run parfor SO setup using model B and hsf configs
fprintf("Running static optimization prep for %d conditions " + ...
    "and %d trials.\n\n", ...
    nConds, nTrials); % Seriously still workshopping this...

parfor i = 1:nConds
    for j = 1:nTrials
        % Run static optimization setup generation on this trial for
        % parallel condition.
        % Reuse script logic from
        % run_single_trial_static_optimization_prep_force_config_test.m
        % minus qc tables and qc outputs (these have already been verified).
        % Structure output locations here via naming sequence defined by
        % projectCfg.conditions and projectCfg.trials
        % Store performance metrics (tic toc) 
        % and summary tables here to print later
    end
end