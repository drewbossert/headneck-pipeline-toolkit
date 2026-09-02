function tests = test_write_static_optimization_analysis_provenance
%TEST_WRITE_STATIC_OPTIMIZATION_ANALYSIS_PROVENANCE Provenance tests.

    tests = functiontests(localfunctions);
end


function testConfiguredProvenanceWritesCsvAndMat(testCase)

    [cfg, context, root, cleanup] = ...
        localFixture(); %#ok<ASGLU>

    result = ...
        pipeline.writeStaticOptimizationAnalysisProvenance( ...
            cfg, ...
            context, ...
            root);

    verifyTrue(testCase, result.Written);
    verifyTrue(testCase, isfile(result.CsvFile));
    verifyTrue(testCase, isfile(result.MatFile));

    flat = readtable( ...
        result.CsvFile, ...
        "TextType", "string");

    verifyEqual(testCase, height(flat), 1);
    verifyEqual(testCase, flat.config_id, "m20p_a35p");
    verifyEqual(testCase, flat.muscle_percent, 20);
    verifyEqual(testCase, flat.actuator_percent, 35);
    verifyTrue(testCase, flat.is_feasible);
    verifyEqual(testCase, ...
        flat.normalized_breaks_percent, ...
        "0 20 80 100");
    verifyEqual(testCase, ...
        flat.statistics_window_percent, ...
        "20 80");
end


function testMatPreservesStructuredVectors(testCase)

    [cfg, context, root, cleanup] = ...
        localFixture(); %#ok<ASGLU>

    result = ...
        pipeline.writeStaticOptimizationAnalysisProvenance( ...
            cfg, ...
            context, ...
            root);

    loaded = load(result.MatFile, "provenance");

    verifyEqual(testCase, ...
        loaded.provenance.ProjectDataset.ConditionsDeg, ...
        [0 15 30 45]);

    verifyEqual(testCase, ...
        loaded.provenance.ProjectDataset.Trials, ...
        1:5);

    verifyEqual(testCase, ...
        loaded.provenance.AnalysisSettings.NormalizedBreaksPercent, ...
        [0 20 80 100]);

    verifyEqual(testCase, ...
        loaded.provenance.AnalysisSettings.PointsPerPhase, ...
        [200 600 200]);

    verifyEqual(testCase, ...
        loaded.provenance.AnalysisSettings.ExcludedTrials, ...
        [15 3; 45 2]);
end


function testDisabledManifestWritesNothing(testCase)

    [cfg, context, root, cleanup] = ...
        localFixture(); %#ok<ASGLU>

    cfg.analysis.staticOptimization.writeContextManifest = false;

    result = ...
        pipeline.writeStaticOptimizationAnalysisProvenance( ...
            cfg, ...
            context, ...
            root);

    verifyFalse(testCase, result.Written);
    verifyFalse(testCase, isfile(result.CsvFile));
    verifyFalse(testCase, isfile(result.MatFile));
end


function testLegacyContextIsRepresented(testCase)

    [cfg, context, root, cleanup] = ...
        localFixture(); %#ok<ASGLU>

    context.Configured = false;
    context.Legacy = true;
    context.ConfigId = "";
    context.MusclePercent = NaN;
    context.ActuatorPercent = NaN;
    context.DisplayName = ...
        "Legacy unconfigured Static Optimization results";
    context.AssessmentComplete = false;
    context.IsFeasible = false;
    context.FeasibilityStatus = "LEGACY_UNASSESSED";
    context.FeasibilityReason = "Legacy result set.";

    result = ...
        pipeline.writeStaticOptimizationAnalysisProvenance( ...
            cfg, ...
            context, ...
            root);

    flat = readtable( ...
        result.CsvFile, ...
        "TextType", "string");

    verifyTrue(testCase, flat.legacy);
    verifyFalse(testCase, flat.configured);
    verifyTrue(testCase, ...
        ismissing(flat.config_id) || ...
        strlength(flat.config_id) == 0);
    verifyTrue(testCase, isnan(flat.muscle_percent));
    verifyEqual(testCase, ...
        flat.feasibility_status, ...
        "LEGACY_UNASSESSED");
end


function [cfg, context, root, cleanup] = localFixture()

    root = string(fullfile( ...
        tempdir, ...
        "headneck_so_analysis_provenance_" + ...
        string(java.util.UUID.randomUUID())));

    mkdir(root);
    cleanup = onCleanup(@() localRemoveTree(root));

    cfg = struct;
    cfg.configSchemaVersion = 3;
    cfg.outputRoot = root;
    cfg.conditions = [0 15 30 45];
    cfg.trials = 1:5;

    cfg.analysis = struct;
    cfg.analysis.staticOptimization = struct;

    analysisCfg = cfg.analysis.staticOptimization;
    analysisCfg.writeContextManifest = true;
    analysisCfg.normalizedBreaksPercent = [0 20 80 100];
    analysisCfg.pointsPerPhase = [200 600 200];
    analysisCfg.statisticsWindowPercent = [20 80];
    analysisCfg.motionOutputWindowPercent = [0 100];
    analysisCfg.extensorLandmarkPercent = 50;
    analysisCfg.excludedTrials = [15 3; 45 2];
    analysisCfg.flexionGroupName = "flexion";
    analysisCfg.extensionGroupName = "extension";
    analysisCfg.expectedFlexorCount = 16;
    analysisCfg.expectedExtensorCount = 36;
    analysisCfg.topReserveCount = 10;

    cfg.analysis.staticOptimization = analysisCfg;

    context = struct;
    context.SchemaVersion = 1;
    context.RequestedMode = "prompt";
    context.ResolvedMode = "config";
    context.Configured = true;
    context.Legacy = false;
    context.ConfigId = "m20p_a35p";
    context.MusclePercent = 20;
    context.ActuatorPercent = 35;
    context.DisplayName = ...
        "m20p_a35p (20% muscle, 35% actuator)";
    context.AssessmentComplete = true;
    context.IsFeasible = true;
    context.FeasibilityStatus = "FEASIBLE";
    context.FeasibilityReason = ...
        "All expected trials completed and passed.";
    context.SearchRoot = string(fullfile( ...
        root, ...
        "static_optimization_configs", ...
        "m20p_a35p"));
    context.AnalysisDirectory = root;
end


function localRemoveTree(root)

    if isfolder(root)
        rmdir(root, "s");
    end
end
