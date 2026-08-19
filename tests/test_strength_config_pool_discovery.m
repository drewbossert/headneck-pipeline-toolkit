function tests = test_strength_config_pool_discovery
%TEST_STRENGTH_CONFIG_POOL_DISCOVERY Tests candidate JSON-pool discovery.

    tests = functiontests(localfunctions);
end


function testDiscoversCompleteCartesianPool(testCase)

    [cfg, configDirectory, cleanup] = ...
        localCreateProject(); %#ok<ASGLU>

    muscleGrid = [10 15 20 25 50];
    actuatorGrid = [5 10 15 20 25 50 75];

    for muscle = muscleGrid
        for actuator = actuatorGrid

            localTouchJson( ...
                configDirectory, ...
                composeConfigName( ...
                    muscle, ...
                    actuator));
        end
    end

    pool = soopt.discoverStrengthConfigPool(cfg);

    verifyEqual(testCase, ...
        pool.DiscoveredConfigurationCount, ...
        35);

    verifyEqual(testCase, ...
        pool.ExpectedCartesianCount, ...
        35);

    verifyTrue(testCase, ...
        pool.IsCompleteCartesianGrid);

    verifyEqual(testCase, ...
        pool.MuscleGrid, ...
        muscleGrid.');

    verifyEqual(testCase, ...
        pool.ActuatorGrid, ...
        actuatorGrid.');

    verifyEqual(testCase, ...
        height(pool.MissingCombinations), ...
        0);
end


function testDefaultDirectoryComesFromActiveConfigFile(testCase)

    [cfg, configDirectory, cleanup] = ...
        localCreateProject(); %#ok<ASGLU>

    localTouchJson( ...
        configDirectory, ...
        "m25p_a50p.json");

    pool = soopt.discoverStrengthConfigPool(cfg);

    verifyEqual(testCase, ...
        pool.ConfigDirectory, ...
        configDirectory);
end


function testExplicitDirectoryOverridesProjectConfig(testCase)

    [cfg, ~, cleanup] = ...
        localCreateProject(); %#ok<ASGLU>

    overrideDirectory = string(fullfile( ...
        tempdir, ...
        "headneck_strength_pool_override_" + ...
        string(java.util.UUID.randomUUID())));

    mkdir(overrideDirectory);

    overrideCleanup = ...
        onCleanup(@() localRemoveTree(overrideDirectory)); %#ok<NASGU>

    localTouchJson( ...
        overrideDirectory, ...
        "m20p_a15p.json");

    pool = soopt.discoverStrengthConfigPool( ...
        cfg, ...
        "ConfigDirectory", ...
        overrideDirectory);

    verifyEqual(testCase, ...
        pool.ConfigDirectory, ...
        overrideDirectory);

    verifyEqual(testCase, ...
        pool.Configurations.ConfigId, ...
        "m20p_a15p");
end


function testNoncanonicalJsonFilesAreIgnored(testCase)

    [cfg, configDirectory, cleanup] = ...
        localCreateProject(); %#ok<ASGLU>

    localTouchJson(configDirectory, "m25p_a50p.json");
    localTouchJson(configDirectory, "notes.json");
    localTouchJson(configDirectory, "muscle25_actuator50.json");

    pool = soopt.discoverStrengthConfigPool(cfg);

    verifyEqual(testCase, ...
        pool.DiscoveredConfigurationCount, ...
        1);

    verifyEqual(testCase, ...
        pool.Configurations.ConfigId, ...
        "m25p_a50p");
end


function testMissingCartesianCombinationIsReported(testCase)

    [cfg, configDirectory, cleanup] = ...
        localCreateProject(); %#ok<ASGLU>

    localTouchJson(configDirectory, "m10p_a10p.json");
    localTouchJson(configDirectory, "m10p_a25p.json");
    localTouchJson(configDirectory, "m25p_a10p.json");

    pool = soopt.discoverStrengthConfigPool(cfg);

    verifyFalse(testCase, ...
        pool.IsCompleteCartesianGrid);

    verifyEqual(testCase, ...
        pool.ExpectedCartesianCount, ...
        4);

    verifyEqual(testCase, ...
        pool.DiscoveredConfigurationCount, ...
        3);

    verifyEqual(testCase, ...
        pool.MissingCombinations.MusclePercent, ...
        25);

    verifyEqual(testCase, ...
        pool.MissingCombinations.ActuatorPercent, ...
        25);
end


function testDuplicateNumericCoordinateIsRejected(testCase)

    [cfg, configDirectory, cleanup] = ...
        localCreateProject(); %#ok<ASGLU>

    localTouchJson(configDirectory, "m25p_a5p.json");
    localTouchJson(configDirectory, "m25p_a05p.json");

    verifyError(testCase, ...
        @() soopt.discoverStrengthConfigPool(cfg), ...
        "StrengthConfigPool:DuplicateCoordinates");
end


function testEmptyCanonicalPoolIsSupported(testCase)

    [cfg, configDirectory, cleanup] = ...
        localCreateProject(); %#ok<ASGLU>

    localTouchJson(configDirectory, "notes.json");

    pool = soopt.discoverStrengthConfigPool(cfg);

    verifyEqual(testCase, ...
        pool.DiscoveredConfigurationCount, ...
        0);

    verifyEmpty(testCase, ...
        pool.MuscleGrid);

    verifyEmpty(testCase, ...
        pool.ActuatorGrid);

    verifyTrue(testCase, ...
        pool.IsCompleteCartesianGrid);
end


function testMissingConfigDirectoryIsRejected(testCase)

    cfg = struct;
    cfg.forceCapacity = struct;

    cfg.forceCapacity.configFile = string(fullfile( ...
        tempdir, ...
        "headneck_missing_config_pool", ...
        "m25p_a50p.json"));

    verifyError(testCase, ...
        @() soopt.discoverStrengthConfigPool(cfg), ...
        "StrengthConfigPool:ConfigDirectoryNotFound");
end


function [cfg, configDirectory, cleanup] = localCreateProject()

    root = string(fullfile( ...
        tempdir, ...
        "headneck_strength_pool_" + ...
        string(java.util.UUID.randomUUID())));

    configDirectory = string(fullfile( ...
        root, ...
        "force_configs"));

    mkdir(configDirectory);

    cleanup = onCleanup(@() localRemoveTree(root));

    cfg = struct;
    cfg.forceCapacity = struct;

    cfg.forceCapacity.configFile = string(fullfile( ...
        configDirectory, ...
        "m25p_a50p.json"));
end


function fileName = composeConfigName(musclePercent, actuatorPercent)

    if actuatorPercent < 10
        actuatorText = compose("%02d", actuatorPercent);
    else
        actuatorText = compose("%d", actuatorPercent);
    end

    fileName = ...
        "m" + string(musclePercent) + ...
        "p_a" + string(actuatorText) + ...
        "p.json";
end


function localTouchJson(directory, fileName)

    filePath = string(fullfile( ...
        directory, ...
        fileName));

    fid = fopen(filePath, "w");

    assert(fid >= 0, ...
        "StrengthConfigPoolTest:FileCreateFailed", ...
        "Could not create synthetic JSON file:\n%s", ...
        filePath);

    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, "{}\n");
end


function localRemoveTree(root)

    if isfolder(root)
        rmdir(root, "s");
    end
end
