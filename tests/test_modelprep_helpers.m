function tests = test_modelprep_helpers
%TEST_MODELPREP_HELPERS Unit tests that do not require a project model.

    tests = functiontests(localfunctions);
end

function testCoordinateGroups(testCase)

    groups = modelprep.coordinateGroups();

    verifyEqual(testCase, numel(groups.Root), 6);
    verifyEqual(testCase, numel(groups.IndependentOutOfPlane), 4);
    verifyEqual(testCase, numel(groups.DependentOutOfPlane), 12);
    verifyEqual(testCase, numel(groups.FinalIkLocked), 10);
    verifyEqual(testCase, numel(groups.StaticOptimizationLocked), 22);

    verifyEmpty(testCase, intersect( ...
        groups.Sagittal, groups.AllOutOfPlane));

    verifyEqual(testCase, numel(unique( ...
        groups.StaticOptimizationLocked)), ...
        numel(groups.StaticOptimizationLocked));
end

function testMakeLockConfiguration(testCase)

    Coordinate = ["gndpitch"; "roll1"];
    ValueSI = [1.0; 2.0];

    values = table( ...
        Coordinate, ValueSI, ...
        'VariableNames', {'Coordinate', 'ValueSI'});

    configuration = modelprep.makeLockConfiguration(values);

    verifyEqual(testCase, configuration.Coordinate, Coordinate);
    verifyEqual(testCase, configuration.DefaultValueSI, ValueSI);
    verifyTrue(testCase, all(configuration.Locked));
    verifyFalse(testCase, any(configuration.Clamped));
    verifyFalse(testCase, any(configuration.Prescribed));
end
