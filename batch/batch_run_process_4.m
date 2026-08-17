%%                         batch_run_process_4.m                         %%
% ======================================================================= %
% Process 4 description here                                              %
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

processCfg.executeStaticOptimization = true;

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

%% TODO Run parfor SO runs on all trials 
% NOTE: this task is big, each run can take up to 20 minutes. 
% Check the value for step_interval in the SO setup
% template (default located in ..\input\templates\so_setup_template.xml).
% The object for this value is located in the tree at
% OpenSimDocument>AnalyzeTool>AnalysisSet>objects>StaticOptimization>step_interval
assert(processCfg.executeStaticOptimization, ...
    "BatchProcessing:StaticOptimizationNotEnabled", ...
    "Running static optimization is currently disabled.\n" + ...
    "Enable static optimization analyses by setting\n\n" + ...
    "    processCfg.executeStaticOptimization = true");

fprintf("Running static optimization analyses on %d conditions and " + ...
    "%d trials.\nThis process may take a while... You may track analysis " + ...
    "progress by inspecting the output at ../opensim.log.\n\n", ...
    nConds, nTrials);