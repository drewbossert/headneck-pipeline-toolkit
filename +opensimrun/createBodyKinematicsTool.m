function result = createBodyKinematicsTool( ...
        modelFile, coordinatesFile, resultsDirectory, varargin)
%CREATEBODYKINEMATICSTOOL Configure an OpenSim AnalyzeTool.
%
% result = opensimrun.createBodyKinematicsTool( ...
%     modelFile, coordinatesFile, resultsDirectory)
%
% Name-value options:
%   BodyNames                  "skull"
%   ToolName                   "body_kinematics"
%   AnalysisName               "BodyKinematics"
%   InitialTime                [] (first coordinate-file time)
%   FinalTime                  [] (last coordinate-file time)
%   LowpassCutoffFrequency     -1
%   ExpressResultsInLocalFrame false
%   RecordModelCenterOfMass    false
%   OutputAnglesInDegrees      true
%   OutputPrecision            12
%   SetupFile                  "" (do not print)
%
% Returned structure:
%   Tool, Model, Analysis, InitialTime, FinalTime, SetupFile,
%   ModelFile, CoordinatesFile, ResultsDirectory, BodyNames
%
% The configured BodyKinematics analysis records body center-of-mass
% positions in ground when ExpressResultsInLocalFrame is false.

    import org.opensim.modeling.*

    parser = inputParser;
    parser.FunctionName = "opensimrun.createBodyKinematicsTool";

    addRequired(parser, "modelFile", @opensimrun.internal.isTextScalar);
    addRequired(parser, "coordinatesFile", @opensimrun.internal.isTextScalar);
    addRequired(parser, "resultsDirectory", @opensimrun.internal.isTextScalar);

    addParameter(parser, "BodyNames", "skull", ...
        @(x) ischar(x) || isstring(x) || iscellstr(x));
    addParameter(parser, "ToolName", "body_kinematics", ...
        @opensimrun.internal.isTextScalar);
    addParameter(parser, "AnalysisName", "BodyKinematics", ...
        @opensimrun.internal.isTextScalar);
    addParameter(parser, "InitialTime", [], ...
        @(x) isempty(x) || (isnumeric(x) && isscalar(x) && isfinite(x)));
    addParameter(parser, "FinalTime", [], ...
        @(x) isempty(x) || (isnumeric(x) && isscalar(x) && isfinite(x)));
    addParameter(parser, "LowpassCutoffFrequency", -1, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x));
    addParameter(parser, "ExpressResultsInLocalFrame", false, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, "RecordModelCenterOfMass", false, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, "OutputAnglesInDegrees", true, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, "OutputPrecision", 12, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(parser, "SetupFile", "", ...
        @opensimrun.internal.isTextScalar);

    parse(parser, modelFile, coordinatesFile, ...
        resultsDirectory, varargin{:});

    modelFile = string(parser.Results.modelFile);
    coordinatesFile = string(parser.Results.coordinatesFile);
    resultsDirectory = string(parser.Results.resultsDirectory);
    bodyNames = string(parser.Results.BodyNames);
    bodyNames = bodyNames(:);

    assert(isfile(modelFile), ...
        "opensimrun:ModelFileNotFound", ...
        "Model file was not found:\n%s", modelFile);

    assert(isfile(coordinatesFile), ...
        "opensimrun:CoordinatesFileNotFound", ...
        "Coordinate file was not found:\n%s", coordinatesFile);

    if ~isfolder(resultsDirectory)
        mkdir(resultsDirectory);
    end

    coordinates = opensimio.readMot(coordinatesFile);

    initialTime = parser.Results.InitialTime;
    finalTime = parser.Results.FinalTime;

    if isempty(initialTime)
        initialTime = coordinates.Time(1);
    end

    if isempty(finalTime)
        finalTime = coordinates.Time(end);
    end

    if initialTime < coordinates.Time(1) || ...
            finalTime > coordinates.Time(end) || ...
            finalTime < initialTime
        error("opensimrun:InvalidAnalysisTimeRange", ...
            ["Analysis range [%.9g, %.9g] lies outside the coordinate " ...
             "file range [%.9g, %.9g]."], ...
            initialTime, finalTime, ...
            coordinates.Time(1), coordinates.Time(end));
    end

    model = Model(char(modelFile));
    model.finalizeConnections();
    model.initSystem();

    bodySet = model.getBodySet();

    for bodyIndex = 1:numel(bodyNames)
        if ~bodySet.contains(char(bodyNames(bodyIndex)))
            error("opensimrun:BodyNotFound", ...
                "Body '%s' is not present in the model.", ...
                bodyNames(bodyIndex));
        end
    end

    bodyArray = ArrayStr();

    for bodyIndex = 1:numel(bodyNames)
        bodyArray.append(char(bodyNames(bodyIndex)));
    end

    bodyKinematics = BodyKinematics(model);
    bodyKinematics.setName(char(string(parser.Results.AnalysisName)));
    bodyKinematics.setBodiesToRecord(bodyArray);
    bodyKinematics.setExpressResultsInLocalFrame( ...
        parser.Results.ExpressResultsInLocalFrame);
    bodyKinematics.setRecordCenterOfMass( ...
        parser.Results.RecordModelCenterOfMass);
    bodyKinematics.setInDegrees( ...
        parser.Results.OutputAnglesInDegrees);
    bodyKinematics.setOn(true);
    bodyKinematics.setStartTime(initialTime);
    bodyKinematics.setEndTime(finalTime);
    bodyKinematics.setPrintResultFiles(true);

    tool = AnalyzeTool(model);
    tool.setName(char(string(parser.Results.ToolName)));
    tool.setModelFilename(char(modelFile));
    tool.setCoordinatesFileName(char(coordinatesFile));
    tool.setResultsDir(char(resultsDirectory));
    tool.setInitialTime(initialTime);
    tool.setFinalTime(finalTime);
    tool.setLowpassCutoffFrequency( ...
        parser.Results.LowpassCutoffFrequency);
    tool.setOutputPrecision(round(parser.Results.OutputPrecision));
    tool.setSolveForEquilibrium(false);
    tool.setPrintResultFiles(true);
    tool.updAnalysisSet().cloneAndAppend(bodyKinematics);

    setupFile = string(parser.Results.SetupFile);

    if strlength(setupFile) > 0
        parentDirectory = fileparts(setupFile);

        if strlength(parentDirectory) > 0 && ...
                ~isfolder(parentDirectory)
            mkdir(parentDirectory);
        end

        writeSucceeded = logical(tool.print(char(setupFile)));

        if ~writeSucceeded || ~isfile(setupFile)
            error("opensimrun:SetupWriteFailed", ...
                "Could not write AnalyzeTool setup file:\n%s", ...
                setupFile);
        end
    end

    result = struct;
    result.Tool = tool;
    result.Model = model;
    result.Analysis = bodyKinematics;
    result.InitialTime = initialTime;
    result.FinalTime = finalTime;
    result.SetupFile = setupFile;
    result.ModelFile = modelFile;
    result.CoordinatesFile = coordinatesFile;
    result.ResultsDirectory = resultsDirectory;
    result.BodyNames = bodyNames;
end
