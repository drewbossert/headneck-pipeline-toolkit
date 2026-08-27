%% batch_run_process_3.m
% Batch Process 3:
%   Model C + Body Kinematics + HSF + ExternalLoads + SO setup.
%
% Thin interactive wrapper around:
%
%   pipeline.runStaticOptimizationPrepBatch
%
% Use the package function directly when an in-memory projectCfg must be
% preserved, such as from the automated strength-grid search controller.

clear;
clc;
dbstop if error

projectCfg = ...
    load_project_config();

batchResult = ...
    pipeline.runStaticOptimizationPrepBatch( ...
        projectCfg);
