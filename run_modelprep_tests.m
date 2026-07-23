function results = run_modelprep_tests(baseModelFile)
%RUN_MODELPREP_TESTS Run modelprep unit tests and optional model smoke test.
%
% results = run_modelprep_tests()
% results = run_modelprep_tests(baseModelFile)
%
% Supplying a real .osim file additionally exercises:
%   - model loading;
%   - coordinate unlocking;
%   - constraint enabling;
%   - model writing; and
%   - model reloading.

    toolkitRoot = fileparts(mfilename("fullpath"));
    addpath(toolkitRoot);

    testFile = fullfile( ...
        toolkitRoot, "tests", "test_modelprep_helpers.m");

    if ~isfile(testFile)
        error("modelprep:TestFileMissing", ...
            "Test file was not found:\n%s", testFile);
    end

    results = runtests(testFile);
    disp(table(results));

    if isempty(results)
        error("modelprep:NoTestsFound", ...
            "No modelprep tests were found.");
    end

    if any([results.Failed]) || any([results.Incomplete])
        error("modelprep:TestsFailed", ...
            "One or more modelprep unit tests failed or were incomplete.");
    end

    if nargin >= 1 && strlength(string(baseModelFile)) > 0
        smokeReport = modelprep.smokeTestModel(baseModelFile);

        fprintf([ ...
            "Model smoke test passed: unlocked=%d, " ...
            "constraints enabled=%d.\n"], ...
            smokeReport.AllCoordinatesUnlocked, ...
            smokeReport.AllConstraintsEnabled);
    end

    fprintf("All %d modelprep unit tests passed.\n", numel(results));
end
