%% batch_run_process_4.m
% Batch Process 4:
%   execute and audit Static Optimization.
%
% Thin interactive wrapper around:
%
%   pipeline.runStaticOptimizationBatch
%
% Use the package function directly when an in-memory projectCfg must be
% preserved, such as from the automated strength-grid search controller.

clear;
clc;
dbstop if error

projectCfg = ...
    load_project_config();

batchResult = ...
    pipeline.runStaticOptimizationBatch( ...
        projectCfg);
