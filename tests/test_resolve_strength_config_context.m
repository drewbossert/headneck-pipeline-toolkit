function tests = test_resolve_strength_config_context
%TEST_RESOLVE_STRENGTH_CONFIG_CONTEXT Contract tests for strength context.

    tests = functiontests(localfunctions);
end


function testCanonicalIdentity(testCase)

    cfg = localTestConfig("m25p_a75p.json");

    context = pipeline.resolveStrengthConfigContext(cfg);

    verifyEqual(testCase, context.SchemaVersion, 1);
    verifyEqual(testCase, context.ConfigId, "m25p_a75p");
    verifyEqual(testCase, context.MusclePercent, 25);
    verifyEqual(testCase, context.ActuatorPercent, 75);
    verifyEqual(testCase, context.DisplayName, "25% muscle, 75% actuator");

    verifyEqual( ...
        testCase, ...
        context.Inputs.ConfigFile, ...
        string(cfg.forceCapacity.configFile));

    verifyEqual( ...
        testCase, ...
        context.Inputs.FileName, ...
        "m25p_a75p.json");

    verifyEqual( ...
        testCase, ...
        context.Inputs.ApplyMode, ...
        "target");
end


function testCanonicalPaths(testCase)

    cfg = localTestConfig("m50p_a25p.json");

    context = pipeline.resolveStrengthConfigContext(cfg);

    collectionRoot = string(fullfile( ...
        cfg.outputRoot, ...
        "static_optimization_configs"));

    configRoot = string(fullfile( ...
        collectionRoot, ...
        "m50p_a25p"));

    verifyEqual( ...
        testCase, ...
        context.Paths.CollectionRoot, ...
        collectionRoot);

    verifyEqual( ...
        testCase, ...
        context.Paths.ConfigRoot, ...
        configRoot);

    verifyEqual( ...
        testCase, ...
        context.Paths.BatchQcDirectory, ...
        string(fullfile(configRoot, "batch_qc")));

    verifyEqual( ...
        testCase, ...
        context.Paths.AnalysisDirectory, ...
        string(fullfile(configRoot, "static_optimization_analysis")));
end


function testResolverHasNoFilesystemSideEffects(testCase)

    cfg = localTestConfig("m25p_a50p.json");

    uniqueRoot = string(fullfile( ...
        tempdir, ...
        "headneck_strength_context_" + string(java.util.UUID.randomUUID())));

    cfg.outputRoot = uniqueRoot;

    verifyFalse(testCase, isfolder(uniqueRoot));

    pipeline.resolveStrengthConfigContext(cfg);

    verifyFalse(testCase, isfolder(uniqueRoot));
end


function testDisabledForceCapacityRejected(testCase)

    cfg = localTestConfig("m25p_a75p.json");

    cfg.forceCapacity.enabled = false;

    verifyError( ...
        testCase, ...
        @() pipeline.resolveStrengthConfigContext(cfg), ...
        "StrengthConfigContext:ForceCapacityDisabled");
end


function testEmptyConfigFileRejected(testCase)

    cfg = localTestConfig("m25p_a75p.json");

    cfg.forceCapacity.configFile = "";

    verifyError( ...
        testCase, ...
        @() pipeline.resolveStrengthConfigContext(cfg), ...
        "StrengthConfigContext:ConfigFileMissing");
end


function testScaleModeRejected(testCase)

    cfg = localTestConfig("m25p_a75p.json");

    cfg.forceCapacity.applyMode = "scale";

    verifyError( ...
        testCase, ...
        @() pipeline.resolveStrengthConfigContext(cfg), ...
        "StrengthConfigContext:NonTargetApplyMode");
end


function testInvalidCanonicalNameRejected(testCase)

    cfg = localTestConfig("muscle25_actuator75.json");

    verifyError( ...
        testCase, ...
        @() pipeline.resolveStrengthConfigContext(cfg), ...
        "StrengthConfig:InvalidName");
end


function testConfigurationRootsAreDistinct(testCase)

    cfg25_50 = localTestConfig("m25p_a50p.json");
    cfg25_75 = localTestConfig("m25p_a75p.json");

    context25_50 = pipeline.resolveStrengthConfigContext(cfg25_50);
    context25_75 = pipeline.resolveStrengthConfigContext(cfg25_75);

    verifyNotEqual( ...
        testCase, ...
        context25_50.Paths.ConfigRoot, ...
        context25_75.Paths.ConfigRoot);
end


function cfg = localTestConfig(configFileName)

    repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));

    addpath(repositoryRoot);

    cfg = load_project_config( ...
        "LocalConfigPolicy", "disabled", ...
        "ValidatePaths", false);

    cfg.outputRoot = string(fullfile( ...
        tempdir, ...
        "headneck_outputs"));

    cfg.forceCapacity.enabled = true;

    cfg.forceCapacity.configFile = string(fullfile( ...
        tempdir, ...
        "headneck_force_configs", ...
        configFileName));

    cfg.forceCapacity.applyMode = "target";
end
