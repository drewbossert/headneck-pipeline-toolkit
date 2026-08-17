%%                         batch_run_process_1.m                         %%
% ======================================================================= %
% Run model A IK and validate outputs in batch process                    %
%                                                                         %
% This script will initialize and run OpenSim Inverse Kinematics per      %
% condition and trial in parallel with n workers as defined by config     %
% param: cfg.batchProcessing.maxWorkers. Initial IK runs will prepare the %
% model file for locked coordinates IK downstream by determining the      %
% initial pose state of the model at t=0.                                 %
%                                                                         %
% REQUIRED TOOLKIT PACKAGES                                               %
%   +opensimio                                                            %
%   +modelprep                                                            %
%   +opensimrun                                                           %
%                                                                         %
% REQUIRED INPUTS                                                         %
%   1) Clean scaled 4-month-old base model                                %
%   2) Trial marker .trc file                                             %
%   3) A known-working IK setup XML template with the correct IK task set %
%                                                                         %
% The template must contain exactly one each of:                          %
%   <model_file>                                                          %
%   <marker_file>                                                         %
%   <time_range>                                                          %
%   <output_motion_file>                                                  %
% ======================================================================= %

%% SECTION 0 — PROJECT CONFIGURATION

clear;
clc;
dbstop if error

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

processCfg.markerDirectory = fullfile( ...
    projectCfg.inputDirectory, ...
    "trial_data");

processCfg.ikTemplateFile = fullfile( ...
    projectCfg.inputDirectory, ...
    "templates", ...
    "ik_setup_template.xml");

processCfg.executeIK = true;

processCfg.initialTime = 0.00;
processCfg.finalTime   = 19.99;

processCfg.expectedCoordinateCount = 30;
processCfg.expectedConstraintCount = 18;

% Coordinates highlighted in the first-pass audit.
processCfg.reviewCoordinates = [ ...
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

%% TODO define output paths
analysisDirectory = string(fullfile( ...
    projectCfg.outputRoot));

if ~isfolder(analysisDirectory)
    mkdir(analysisDirectory);
end
% Exact output paths (i.e. condition\trial\results) will be created in the
% parallel process respective of that run

%% TODO define parallel pool workers
nWorkers = projectCfg.batchProcessing.maxWorkers;

% pool = gcp("nocreate");
% 
% if isempty(pool)
%     parpool("local", nWorkers);
% elseif pool.NumWorkers ~= nWorkers
%     delete(pool);
%     parpool("local", nWorkers);
% end

%% TODO run parfor IK
nConds = numel(projectCfg.conditions);
nTrials = numel(projectCfg.trials);

fprintf("Running initialization IK for %d conditions " + ...
    "and %d trials.\n\n", ...
    nConds, nTrials); % TODO workshop this fprintf... (very yikes)

parfor i = 1:numel(nConds)
    for j = 1:numel(nTrials)
        % Perform IK process on this trial for parallel condition. 
        % Reuse script logic from run_single_trial_initialization_ik.m
        % minus qc tables and qc outputs (these have already been verified).
        % Structure output locations here via naming sequence defined by
        % projectCfg.conditions and projectCfg.trials
        % Store performance metrics (tic toc) 
        % and summary tables here to print later
    end
end

% TODO include fprintf messages for progress reporting. 
% NOTE: fprintf, sprintf, and any other string input types 
% spanning multiple lines of code MUST be formatted like 
% "first line of code" + ...
% "second line of code"; 
% Formatting strings as vectors DOES NOT pass the
% correct string type as an argument handle, i.e. 
% ["first line ", ...
% "second line]; 
% The former is the only way to properly join strings within
% arguments in R2026a.