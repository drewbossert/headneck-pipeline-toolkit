function results = run_opensimio_tests()
%RUN_OPENSIMIO_TESTS Run the bundled OpenSim I/O toolkit tests.
%
% results = run_opensimio_tests()
%
% Add the toolkit root to the MATLAB path, then call this function from
% any working directory. It runs every test in the toolkit's tests folder,
% displays the results, and raises an error if any test fails.

    thisFile = mfilename("fullpath");
    toolkitRoot = fileparts(thisFile);
    testsFolder = fullfile(toolkitRoot, "tests");

    addpath(toolkitRoot);

    if ~isfolder(testsFolder)
        error("opensimio:TestsFolderMissing", ...
            "The tests folder was not found:\n%s", testsFolder);
    end

    results = runtests(testsFolder, "IncludeSubfolders", true);

    disp(table(results));

    if isempty(results)
        error("opensimio:NoTestsFound", ...
            "No MATLAB tests were found in:\n%s", testsFolder);
    end

    if any([results.Failed]) || any([results.Incomplete])
        error("opensimio:TestsFailed", ...
            "One or more opensimio toolkit tests failed or were incomplete.");
    end

    fprintf("All %d opensimio tests passed.\n", numel(results));
end
