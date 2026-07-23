function result = runAnalyzeSetup(setupFile)
%RUNANALYZESETUP Run a saved OpenSim AnalyzeTool XML setup.
%
% result = opensimrun.runAnalyzeSetup(setupFile)

    import org.opensim.modeling.*

    setupFile = string(setupFile);

    assert(isfile(setupFile), ...
        "opensimrun:SetupFileNotFound", ...
        "AnalyzeTool setup file was not found:\n%s", setupFile);

    tool = AnalyzeTool(char(setupFile));
    runSucceeded = logical(tool.run());

    if ~runSucceeded
        error("opensimrun:AnalysisFailed", ...
            "OpenSim AnalyzeTool returned false for:\n%s", setupFile);
    end

    result = struct;
    result.SetupFile = setupFile;
    result.Tool = tool;
    result.RunSucceeded = runSucceeded;
    result.ResultsDirectory = string(char(tool.getResultsDir()));
end
