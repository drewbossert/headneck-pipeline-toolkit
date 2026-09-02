function tests = test_resolve_static_optimization_analysis_context
%TEST_RESOLVE_STATIC_OPTIMIZATION_ANALYSIS_CONTEXT Resolver contract tests.

    tests = functiontests(localfunctions);
end


function testConfigModeResolvesExactConfiguration(testCase)

    [cfg, root, cleanup] = localFixture(); %#ok<ASGLU>
    summary = localSummary(root);

    cfg.analysis.staticOptimization.selection.mode = "config";
    cfg.analysis.staticOptimization.selection.configId = "m20p_a35p";

    context = pipeline.resolveStaticOptimizationAnalysisContext( ...
        cfg, ...
        "ConfigurationSummary", summary);

    verifyEqual(testCase, context.ResolvedMode, "config");
    verifyTrue(testCase, context.Configured);
    verifyEqual(testCase, context.ConfigId, "m20p_a35p");
    verifyEqual(testCase, context.MusclePercent, 20);
    verifyEqual(testCase, context.ActuatorPercent, 35);
    verifyEqual(testCase, ...
        context.SearchRoot, ...
        string(fullfile( ...
            root, "static_optimization_configs", "m20p_a35p")));
    verifyEqual(testCase, ...
        context.AnalysisDirectory, ...
        string(fullfile( ...
            root, "static_optimization_configs", "m20p_a35p", ...
            "static_optimization_analysis")));
end


function testConfigModeRejectsInfeasibleConfiguration(testCase)

    [cfg, root, cleanup] = localFixture(); %#ok<ASGLU>
    summary = localSummary(root);

    cfg.analysis.staticOptimization.selection.mode = "config";
    cfg.analysis.staticOptimization.selection.configId = "m15p_a25p";

    verifyError(testCase, ...
        @() pipeline.resolveStaticOptimizationAnalysisContext( ...
            cfg, ...
            "ConfigurationSummary", summary), ...
        "SOAnalysisContext:ConfigurationInfeasible");
end


function testConfigModeCanAllowInfeasibleConfiguration(testCase)

    [cfg, root, cleanup] = localFixture(); %#ok<ASGLU>
    summary = localSummary(root);

    cfg.analysis.staticOptimization.selection.mode = "config";
    cfg.analysis.staticOptimization.selection.configId = "m15p_a25p";
    cfg.analysis.staticOptimization.selection.requireFeasible = false;

    context = pipeline.resolveStaticOptimizationAnalysisContext( ...
        cfg, ...
        "ConfigurationSummary", summary);

    verifyEqual(testCase, context.ConfigId, "m15p_a25p");
    verifyFalse(testCase, context.IsFeasible);
    verifyEqual(testCase, ...
        context.FeasibilityStatus, ...
        "INFEASIBLE_SO_FAILURE");
end


function testConfigModeRejectsIncompleteAssessment(testCase)

    [cfg, root, cleanup] = localFixture(); %#ok<ASGLU>
    summary = localSummary(root);

    cfg.analysis.staticOptimization.selection.mode = "config";
    cfg.analysis.staticOptimization.selection.configId = "m10p_a60p";
    cfg.analysis.staticOptimization.selection.requireFeasible = false;

    verifyError(testCase, ...
        @() pipeline.resolveStaticOptimizationAnalysisContext( ...
            cfg, ...
            "ConfigurationSummary", summary), ...
        "SOAnalysisContext:AssessmentIncomplete");
end


function testPromptAutoSelectsSingleEligibleConfiguration(testCase)

    [cfg, root, cleanup] = localFixture(); %#ok<ASGLU>
    summary = localSummary(root);

    cfg.analysis.staticOptimization.selection.mode = "prompt";

    context = pipeline.resolveStaticOptimizationAnalysisContext( ...
        cfg, ...
        "ConfigurationSummary", summary);

    verifyEqual(testCase, context.RequestedMode, "prompt");
    verifyEqual(testCase, context.ResolvedMode, "config");
    verifyEqual(testCase, context.ConfigId, "m20p_a35p");
    verifyEqual(testCase, height(context.EligibleConfigurations), 1);
end


function testPromptSelectionIndexSelectsRequestedCandidate(testCase)

    [cfg, root, cleanup] = localFixture(); %#ok<ASGLU>
    summary = localSummary(root);

    cfg.analysis.staticOptimization.selection.mode = "prompt";
    cfg.analysis.staticOptimization.selection.requireFeasible = false;
    cfg.analysis.staticOptimization.selection.requireAssessmentComplete = true;

    context = pipeline.resolveStaticOptimizationAnalysisContext( ...
        cfg, ...
        "ConfigurationSummary", summary, ...
        "PromptSelectionIndex", 2);

    % Complete candidates sort m15p_a25p, then m20p_a35p.
    verifyEqual(testCase, context.ConfigId, "m20p_a35p");
end


function testLegacyModeResolvesBaseOutputTree(testCase)

    [cfg, root, cleanup] = localFixture(); %#ok<ASGLU>
    localCreateLegacyForceFile(root);

    cfg.analysis.staticOptimization.selection.mode = "legacy";

    context = pipeline.resolveStaticOptimizationAnalysisContext(cfg);

    verifyTrue(testCase, context.Legacy);
    verifyFalse(testCase, context.Configured);
    verifyEqual(testCase, context.SearchRoot, string(root));
    verifyEqual(testCase, ...
        context.AnalysisDirectory, ...
        string(fullfile(root, "static_optimization_analysis")));
end


function testLegacyModeRequiresLegacyResults(testCase)

    [cfg, ~, cleanup] = localFixture(); %#ok<ASGLU>

    cfg.analysis.staticOptimization.selection.mode = "legacy";

    verifyError(testCase, ...
        @() pipeline.resolveStaticOptimizationAnalysisContext(cfg), ...
        "SOAnalysisContext:LegacyResultsNotFound");
end


function testConfigModeRejectsUnknownConfigId(testCase)

    [cfg, root, cleanup] = localFixture(); %#ok<ASGLU>
    summary = localSummary(root);

    cfg.analysis.staticOptimization.selection.mode = "config";
    cfg.analysis.staticOptimization.selection.configId = "m50p_a50p";

    verifyError(testCase, ...
        @() pipeline.resolveStaticOptimizationAnalysisContext( ...
            cfg, ...
            "ConfigurationSummary", summary), ...
        "SOAnalysisContext:ConfigNotFound");
end


function [cfg, root, cleanup] = localFixture()

    root = string(fullfile( ...
        tempdir, ...
        "headneck_so_analysis_context_" + ...
        string(java.util.UUID.randomUUID())));

    mkdir(root);
    cleanup = onCleanup(@() localRemoveTree(root));

    cfg = struct;
    cfg.outputRoot = root;
    cfg.analysis = struct;
    cfg.analysis.staticOptimization = struct;

    cfg.analysis.staticOptimization.selection = struct( ...
        "mode", "prompt", ...
        "configId", "", ...
        "requireAssessmentComplete", true, ...
        "requireFeasible", true, ...
        "includeLegacyInPrompt", false, ...
        "autoSelectSingleCandidate", true);
end


function summary = localSummary(root)

    ConfigId = [ ...
        "m10p_a60p"
        "m15p_a25p"
        "m20p_a35p"
    ];

    MusclePercent = [10; 15; 20];
    ActuatorPercent = [60; 25; 35];

    AssessmentComplete = [false; true; true];
    IsFeasible = [false; false; true];

    FeasibilityStatus = [ ...
        "INCOMPLETE_MISSING_BATCH_SUMMARY"
        "INFEASIBLE_SO_FAILURE"
        "FEASIBLE"
    ];

    FeasibilityReason = [ ...
        "Process-4 batch summary CSV was not found."
        "One or more trials failed Static Optimization."
        "All expected trials completed and passed."
    ];

    n = numel(ConfigId);
    ConfigRoot = strings(n,1);
    AnalysisDirectory = strings(n,1);

    for i = 1:n
        ConfigRoot(i) = string(fullfile( ...
            root, ...
            "static_optimization_configs", ...
            ConfigId(i)));

        mkdir(ConfigRoot(i));

        AnalysisDirectory(i) = string(fullfile( ...
            ConfigRoot(i), ...
            "static_optimization_analysis"));
    end

    summary = table( ...
        ConfigId, ...
        MusclePercent, ...
        ActuatorPercent, ...
        ConfigRoot, ...
        AnalysisDirectory, ...
        AssessmentComplete, ...
        IsFeasible, ...
        FeasibilityStatus, ...
        FeasibilityReason);
end


function localCreateLegacyForceFile(root)

    resultsDirectory = string(fullfile( ...
        root, ...
        "00deg", ...
        "trial01", ...
        "04_static_optimization", ...
        "results"));

    mkdir(resultsDirectory);

    forceFile = string(fullfile( ...
        resultsDirectory, ...
        "SO_00deg_trial01_StaticOptimization_force.sto"));

    fid = fopen(forceFile, "w");

    assert(fid >= 0, ...
        "SOAnalysisContextTest:FileCreateFailed", ...
        "Could not create test force file.");

    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, "test");
end


function localRemoveTree(root)

    if isfolder(root)
        rmdir(root, "s");
    end
end
