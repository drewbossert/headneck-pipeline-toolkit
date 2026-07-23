function results = run_hsf_tests()
%RUN_HSF_TESTS Run the HSF class-based unit tests.
%
% results = run_hsf_tests()
%
% The tests folder is temporarily added to the path and the suite is
% created directly from the TestHsfHelpers class metadata. This avoids
% MATLAB's file-extension test-discovery service.

    toolkitRoot = fileparts(mfilename("fullpath"));
    testsFolder = fullfile(toolkitRoot, "tests");

    addpath(toolkitRoot);
    addpath(testsFolder);

    cleanupObject = onCleanup( ...
        @() rmpath(testsFolder)); %#ok<NASGU>

    testFile = fullfile( ...
        testsFolder, ...
        "TestHsfHelpers.m");

    if ~isfile(testFile)
        error("hsf:TestFileMissing", ...
            "HSF test file was not found:\n%s", ...
            testFile);
    end

    clear TestHsfHelpers
    rehash

    try
        classMetadata = ?TestHsfHelpers;
    catch exception
        error("hsf:TestClassLoadFailed", ...
            ["MATLAB could not load TestHsfHelpers.\n" ...
             "File: %s\n\n%s"], ...
            testFile, exception.message);
    end

    suite = matlab.unittest.TestSuite.fromClass(classMetadata);
    results = run(suite);

    disp(table(results));

    if isempty(results)
        error("hsf:NoTestsFound", ...
            "No test methods were discovered in TestHsfHelpers.");
    end

    if any([results.Failed]) || ...
            any([results.Incomplete])
        error("hsf:TestsFailed", ...
            "One or more HSF tests failed or were incomplete.");
    end

    fprintf( ...
        "All %d HSF tests passed.\n", ...
        numel(results));
end
