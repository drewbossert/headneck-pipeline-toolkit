function result = runBodyKinematics( ...
        modelFile, coordinatesFile, resultsDirectory, varargin)
%RUNBODYKINEMATICS Run BodyKinematics through the OpenSim AnalyzeTool.
%
% result = opensimrun.runBodyKinematics( ...
%     modelFile, coordinatesFile, resultsDirectory)
%
% All options accepted by createBodyKinematicsTool() are supported.
% Additional option:
%   Overwrite  true
%
% The returned result includes PositionFile, VelocityFile,
% AccelerationFile, and OutputFiles. PositionFile is the file used by the
% HSF package to obtain the skull center-of-mass trajectory.

    parser = inputParser;
    parser.FunctionName = "opensimrun.runBodyKinematics";
    parser.KeepUnmatched = true;

    addRequired(parser, "modelFile");
    addRequired(parser, "coordinatesFile");
    addRequired(parser, "resultsDirectory");
    addParameter(parser, "Overwrite", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, modelFile, coordinatesFile, ...
        resultsDirectory, varargin{:});

    resultsDirectory = string(resultsDirectory);
    toolName = opensimrun.internal.getUnmatchedOption( ...
        parser.Unmatched, "ToolName", "body_kinematics");

    expectedPattern = string(toolName) + "_BodyKinematics_*.sto";
    previousFiles = dir(fullfile(resultsDirectory, expectedPattern));

    if ~parser.Results.Overwrite && ~isempty(previousFiles)
        error("opensimrun:ExistingAnalysisFiles", ...
            ["BodyKinematics output files already exist in:\n%s\n" ...
             "Set Overwrite=true or use another ToolName."], ...
            resultsDirectory);
    end

    if parser.Results.Overwrite
        for fileIndex = 1:numel(previousFiles)
            delete(fullfile(previousFiles(fileIndex).folder, ...
                previousFiles(fileIndex).name));
        end
    end

    forwarded = opensimrun.internal.structToNameValue( ...
        parser.Unmatched);

    configured = opensimrun.createBodyKinematicsTool( ...
        modelFile, coordinatesFile, resultsDirectory, ...
        forwarded{:});

    runSucceeded = logical(configured.Tool.run());

    if ~runSucceeded
        error("opensimrun:AnalysisFailed", ...
            "OpenSim AnalyzeTool returned false for BodyKinematics.");
    end

    outputListing = dir(fullfile(resultsDirectory, ...
        string(toolName) + "_BodyKinematics_*.sto"));

    if isempty(outputListing)
        % Some OpenSim versions use the analysis name in the result files
        % but retain a different tool base name. Search more broadly.
        outputListing = dir(fullfile(resultsDirectory, ...
            "*BodyKinematics*.sto"));
    end

    if isempty(outputListing)
        error("opensimrun:AnalysisOutputMissing", ...
            ["AnalyzeTool completed but no BodyKinematics .sto files " ...
             "were found in:\n%s"], ...
            resultsDirectory);
    end

    outputFiles = strings(numel(outputListing), 1);

    for fileIndex = 1:numel(outputListing)
        outputFiles(fileIndex) = string(fullfile( ...
            outputListing(fileIndex).folder, ...
            outputListing(fileIndex).name));
    end

    positionFile = opensimrun.internal.selectBodyKinematicsFile( ...
        outputFiles, "pos");
    velocityFile = opensimrun.internal.selectBodyKinematicsFile( ...
        outputFiles, "vel");
    accelerationFile = opensimrun.internal.selectBodyKinematicsFile( ...
        outputFiles, "acc");

    result = configured;
    result.RunSucceeded = runSucceeded;
    result.OutputFiles = outputFiles;
    result.PositionFile = positionFile;
    result.VelocityFile = velocityFile;
    result.AccelerationFile = accelerationFile;
end
