%%                         batch_run_process_2.m                         %%
% ======================================================================= %
% Process 2 description here                                              %
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

processCfg.baseModelFile = fullfile( ...
    projectCfg.modelsDirectory, ...
    "4-mo_kine-only.osim");

processCfg.lockWindow = [0.10 0.15]; % Seems to work universally for all trials with minimal noise error

nConds = numel(projectCfg.conditions);
nTrials = numel(projectCfg.trials);

processCfg.overwriteExisting = ...
    projectCfg.overwriteExisting;
processCfg.executeFinalIK = true;

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

%% TODO run parfor IK model B
fprintf("Running model B generation for %d conditions " + ...
    "and %d trials.\n\n", ...
    nConds, nTrials); % Still workshopping this...

parfor i = 1:nConds
    for j = 1:nTrials
        % Run model B generation on this trial for parallel condition.
        % Reuse script logic from run_single_trial_model_b_filtered.m
        % minus qc tables and qc outputs (these have already been verified).
        % Structure output locations here via naming sequence defined by
        % projectCfg.conditions and projectCfg.trials
        % Store performance metrics (tic toc) 
        % and summary tables here to print later
    end
end