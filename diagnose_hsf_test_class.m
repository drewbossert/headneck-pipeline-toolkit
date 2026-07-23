function report = diagnose_hsf_test_class()
%DIAGNOSE_HSF_TEST_CLASS Show how MATLAB resolves the HSF test class.
%
% report = diagnose_hsf_test_class()
%
% Use this only if run_hsf_tests cannot load TestHsfHelpers.

    toolkitRoot = fileparts(mfilename("fullpath"));
    testsFolder = fullfile(toolkitRoot, "tests");

    addpath(toolkitRoot);
    addpath(testsFolder);

    cleanupObject = onCleanup( ...
        @() rmpath(testsFolder)); %#ok<NASGU>

    clear TestHsfHelpers
    rehash

    resolvedFiles = string(which("TestHsfHelpers", "-all"));

    report = struct;
    report.MatlabVersion = string(version);
    report.ToolkitRoot = string(toolkitRoot);
    report.TestsFolder = string(testsFolder);
    report.ExpectedFile = string(fullfile( ...
        testsFolder, "TestHsfHelpers.m"));
    report.ResolvedFiles = resolvedFiles;
    report.ExpectedFileExists = isfile(report.ExpectedFile);
    report.ClassLoads = false;
    report.ClassName = "";
    report.LoadError = "";

    try
        metadata = ?TestHsfHelpers;
        report.ClassLoads = true;
        report.ClassName = string(metadata.Name);
    catch exception
        report.LoadError = string(exception.message);
    end

    disp(report);
end
