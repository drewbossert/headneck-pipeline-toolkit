function result = runBodyKinematicsForCom( ...
        modelFile, coordinatesFile, resultsDirectory, varargin)
%RUNBODYKINEMATICSFORCOM Run Body Kinematics for HSF CoM extraction.
%
% result = opensimrun.runBodyKinematicsForCom( ...
%     modelFile, coordinatesFile, resultsDirectory, ...)
%
% This is a narrow workflow wrapper for the HSF stage. It runs an OpenSim
% AnalyzeTool containing one BodyKinematics analysis configured to:
%   - record one requested body;
%   - record the body's center of mass;
%   - express results in ground rather than the body's local frame.
%
% REQUIRED INPUTS
%   modelFile
%       Model C .osim file.
%
%   coordinatesFile
%       Validated Model B final-IK .mot file used as the prescribed
%       coordinate trajectory.
%
%   resultsDirectory
%       Directory for Body Kinematics result files.
%
% NAME-VALUE OPTIONS
%   BodyName
%       Body whose CoM is required. Default: "skull".
%
%   TimeRange
%       [startTime endTime]. Default: complete coordinates file.
%
%   ToolName
%       AnalyzeTool name. Default: "body_kinematics_for_hsf".
%
%   SetupFile
%       Optional path for writing the generated AnalyzeTool XML.
%
%   Overwrite
%       Allow existing setup/result files to be replaced. Default: false.
%
%   LowpassCutoffHz
%       AnalyzeTool coordinates-file low-pass cutoff. Default: -1
%       (no additional filtering at this stage).
%
%   OutputPrecision
%       OpenSim output precision. Default: 10.
%
% OUTPUT
%   result.SetupFile
%   result.ModelFile
%   result.CoordinatesFile
%   result.ResultsDirectory
%   result.PositionFile
%   result.BodyName
%   result.TimeRange
%   result.RunSucceeded
%   result.DurationSeconds
%
% OpenSim 4.5 API notes:
%   BodyKinematics supports setRecordCenterOfMass(),
%   setBodiesToRecord(), and setExpressResultsInLocalFrame().
%   AnalyzeTool accepts a coordinates file and results directory.
%
% This function intentionally does not interpret the resulting STO. Use
% hsf.readBodyCom (or equivalent downstream parsing) for that step.

    parser = inputParser;
    parser.FunctionName = ...
        "opensimrun.runBodyKinematicsForCom";

    addRequired(parser, "modelFile", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addRequired(parser, "coordinatesFile", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addRequired(parser, "resultsDirectory", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "BodyName", "skull", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "TimeRange", [], ...
        @(x) isempty(x) || ...
        (isnumeric(x) && numel(x) == 2 && ...
         isfinite(x(1)) && isfinite(x(2)) && ...
         x(2) > x(1)));

    addParameter(parser, "ToolName", ...
        "body_kinematics_for_hsf", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "SetupFile", "", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "Overwrite", false, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "LowpassCutoffHz", -1, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x));

    addParameter(parser, "OutputPrecision", 10, ...
        @(x) isnumeric(x) && isscalar(x) && ...
        isfinite(x) && x >= 1 && mod(x,1) == 0);

    parse(parser, modelFile, coordinatesFile, ...
        resultsDirectory, varargin{:});

    modelFile = string(parser.Results.modelFile);
    coordinatesFile = ...
        string(parser.Results.coordinatesFile);
    resultsDirectory = ...
        string(parser.Results.resultsDirectory);

    bodyName = string(parser.Results.BodyName);
    toolName = string(parser.Results.ToolName);
    setupFile = string(parser.Results.SetupFile);

    overwrite = parser.Results.Overwrite;
    lowpassCutoffHz = ...
        parser.Results.LowpassCutoffHz;
    outputPrecision = ...
        parser.Results.OutputPrecision;

    assert(isfile(modelFile), ...
        "BodyKinematicsForCom:ModelMissing", ...
        "Model file was not found:\n%s", ...
        modelFile);

    assert(isfile(coordinatesFile), ...
        "BodyKinematicsForCom:CoordinatesMissing", ...
        "Coordinates file was not found:\n%s", ...
        coordinatesFile);

    if ~isfolder(resultsDirectory)
        mkdir(resultsDirectory);
    end

    coordinates = ...
        opensimio.readMot(coordinatesFile);

    if isempty(parser.Results.TimeRange)
        timeRange = [ ...
            coordinates.Time(1), ...
            coordinates.Time(end)];
    else
        timeRange = ...
            double(parser.Results.TimeRange(:).');
    end

    assert( ...
        timeRange(1) >= coordinates.Time(1) && ...
        timeRange(2) <= coordinates.Time(end), ...
        "BodyKinematicsForCom:TimeRangeOutsideMotion", ...
        ["Requested time range [%.9g %.9g] is outside " ...
         "coordinates range [%.9g %.9g]."], ...
        timeRange(1), timeRange(2), ...
        coordinates.Time(1), coordinates.Time(end));

    if strlength(setupFile) > 0

        [setupParent, ~, setupExtension] = ...
            fileparts(setupFile);

        assert(strcmpi(setupExtension, ".xml"), ...
            "BodyKinematicsForCom:InvalidSetupExtension", ...
            "SetupFile must use the .xml extension.");

        if strlength(string(setupParent)) > 0 && ...
                ~isfolder(setupParent)
            mkdir(setupParent);
        end

        if isfile(setupFile) && ~overwrite
            error( ...
                "BodyKinematicsForCom:SetupExists", ...
                ["Body Kinematics setup already exists:\n%s\n" ...
                 "Set Overwrite=true to replace it."], ...
                setupFile);
        end
    end

    % Remove stale position outputs only when overwriting. We avoid deleting
    % unrelated Body Kinematics outputs from the directory.
    existingPositionFiles = ...
        localFindPositionFiles(resultsDirectory);

    if ~isempty(existingPositionFiles) && ~overwrite
        error( ...
            "BodyKinematicsForCom:ResultsExist", ...
            ["One or more Body Kinematics position files already exist " ...
             "in:\n%s\nSet Overwrite=true or use a fresh results folder."], ...
            resultsDirectory);
    end

    if overwrite
        for iFile = 1:numel(existingPositionFiles)
            delete(existingPositionFiles(iFile));
        end
    end

    import org.opensim.modeling.*

    model = Model(char(modelFile));
    model.finalizeConnections();

    % Fail early if the requested body does not exist.
    bodySet = model.getBodySet();

    try
        bodySet.get(char(bodyName));
    catch
        error( ...
            "BodyKinematicsForCom:BodyMissing", ...
            "Body '%s' does not exist in model:\n%s", ...
            bodyName, modelFile);
    end

    bodyList = ArrayStr();
    bodyList.append(char(bodyName));

    bodyKinematics = BodyKinematics();

    % Attach the actual in-memory Model to the Analysis. The model filename
    % alone is not sufficient when the AnalyzeTool is constructed
    % programmatically.
    bodyKinematics.setModel(model);

    bodyKinematics.setName("BodyKinematics");
    bodyKinematics.setBodiesToRecord(bodyList);
    bodyKinematics.setRecordCenterOfMass(true);
    bodyKinematics.setExpressResultsInLocalFrame(false);
    bodyKinematics.setOn(true);
    bodyKinematics.setStartTime(timeRange(1));
    bodyKinematics.setEndTime(timeRange(2));
    bodyKinematics.setStepInterval(1);
    bodyKinematics.setInDegrees(true);

    % IMPORTANT:
    % AnalyzeTool(Model&) executes analyses stored on the MODEL's
    % AnalysisSet, not analyses appended to the AnalyzeTool object itself.
    % Therefore BodyKinematics must be added to model.updAnalysisSet()
    % before tool.run().
    appended = ...
        model.updAnalysisSet().cloneAndAppend( ...
            bodyKinematics);

    assert(logical(appended), ...
        "BodyKinematicsForCom:AnalysisAppendFailed", ...
        "Could not append BodyKinematics analysis to the Model.");

    % Re-finalize after modifying the model's AnalysisSet.
    model.finalizeConnections();

    % Construct the AnalyzeTool with the in-memory Model. setModelFilename()
    % below is retained so the generated XML contains the correct model_file
    % path; it does NOT substitute for attaching the Model object.
    tool = AnalyzeTool(model);

    tool.setName(char(toolName));
    tool.setModelFilename(char(modelFile));
    tool.setCoordinatesFileName(char(coordinatesFile));

    % AnalyzeTool(Model&) attaches the model but deliberately defaults
    % loadModelAndInput to false. When false, tool.run() does NOT convert
    % coordinates_file into the states storage required by the analyses.
    % Enable input loading explicitly so the final IK .mot is loaded and
    % converted to model states at run time.
    tool.setLoadModelAndInput(true);
    tool.setResultsDir(char(resultsDirectory));
    tool.setInitialTime(timeRange(1));
    tool.setFinalTime(timeRange(2));
    tool.setLowpassCutoffFrequency(lowpassCutoffHz);
    tool.setOutputPrecision(outputPrecision);
    tool.setSolveForEquilibrium(false);
    tool.setPrintResultFiles(true);

    % Confirm the Model contains an active BodyKinematics analysis.
    modelAnalysisSet = model.updAnalysisSet();

    bodyKinematicsIndex = ...
        modelAnalysisSet.getIndex("BodyKinematics");

    assert(bodyKinematicsIndex >= 0, ...
        "BodyKinematicsForCom:ModelAnalysisMissing", ...
        ["BodyKinematics was not found on the Model AnalysisSet. " ...
         "AnalyzeTool(Model&) would therefore have nothing to execute."]);

    activeBodyKinematics = ...
        BodyKinematics.safeDownCast( ...
            modelAnalysisSet.get(bodyKinematicsIndex));

    assert(~isempty(activeBodyKinematics), ...
        "BodyKinematicsForCom:AnalysisDowncastFailed", ...
        "Could not downcast the model analysis to BodyKinematics.");

    assert(logical(activeBodyKinematics.getOn()), ...
        "BodyKinematicsForCom:AnalysisDisabled", ...
        "BodyKinematics exists on the Model but is disabled.");

    fprintf("\nModel AnalysisSet contains active BodyKinematics.\n");

    % Fail here rather than inside tool.run() if the AnalyzeTool somehow
    % lost its model association.
    try
        attachedModel = tool.getModel(); %#ok<NASGU>
    catch ME
        error( ...
            "BodyKinematicsForCom:AnalyzeToolModelMissing", ...
            ["AnalyzeTool does not have an in-memory Model attached.\n" ...
             "%s"], ...
            ME.message);
    end

    if strlength(setupFile) > 0
        tool.print(char(setupFile));

        assert(isfile(setupFile), ...
            "BodyKinematicsForCom:SetupWriteFailed", ...
            "Body Kinematics setup XML was not written:\n%s", ...
            setupFile);
    end

    % Verify the critical AnalyzeTool runtime inputs before execution.
    configuredCoordinatesFile = ...
        string(char(tool.getCoordinatesFileName()));

    configuredLoadModelAndInput = ...
        logical(tool.getLoadModelAndInput());

    assert(configuredCoordinatesFile == coordinatesFile, ...
        "BodyKinematicsForCom:CoordinatesFileNotConfigured", ...
        ["AnalyzeTool coordinates file does not match the requested " ...
         "final IK motion.\nExpected:\n%s\nObserved:\n%s"], ...
        coordinatesFile, ...
        configuredCoordinatesFile);

    assert(configuredLoadModelAndInput, ...
        "BodyKinematicsForCom:InputLoadingDisabled", ...
        ["AnalyzeTool loadModelAndInput is false. The coordinates file " ...
         "would not be converted into the states storage required by " ...
         "tool.run()."]);

    fprintf("\nBody Kinematics AnalyzeTool inputs:\n");
    fprintf("  Model:       %s\n", modelFile);
    fprintf("  Coordinates: %s\n", configuredCoordinatesFile);
    fprintf("  Load input:  %d\n", configuredLoadModelAndInput);
    fprintf("  Time range:  %.9g to %.9g s\n", ...
        timeRange(1), timeRange(2));

    fprintf( ...
        "Running Body Kinematics for %s...\n", ...
        bodyName);

    tic;
    runSucceeded = logical(tool.run());
    durationSeconds = toc;

    assert(runSucceeded, ...
        "BodyKinematicsForCom:RunFailed", ...
        "OpenSim AnalyzeTool reported Body Kinematics failure.");

    % Inspect the BodyKinematics storage directly from the Model's
    % AnalysisSet. This distinguishes "analysis did not record" from
    % "analysis recorded but automatic file printing failed".
    modelAnalysisSetAfterRun = ...
        model.updAnalysisSet();

    bodyKinematicsIndexAfterRun = ...
        modelAnalysisSetAfterRun.getIndex("BodyKinematics");

    assert(bodyKinematicsIndexAfterRun >= 0, ...
        "BodyKinematicsForCom:AnalysisMissingAfterRun", ...
        "BodyKinematics disappeared from the Model AnalysisSet.");

    bodyKinematicsAfterRun = ...
        BodyKinematics.safeDownCast( ...
            modelAnalysisSetAfterRun.get( ...
                bodyKinematicsIndexAfterRun));

    positionStoragePointer = ...
        bodyKinematicsAfterRun.getPositionStorage();

    positionStorageSize = ...
        positionStoragePointer.getSize();

    assert(positionStorageSize > 0, ...
        "BodyKinematicsForCom:NoRecordedPositionData", ...
        ["BodyKinematics was present and tool.run() completed, but its " ...
         "position storage contains zero rows."]);

    fprintf( ...
        "BodyKinematics recorded %d position rows.\n", ...
        positionStorageSize);

    positionFiles = ...
        localFindPositionFiles(resultsDirectory);

    if isempty(positionFiles)

        warning( ...
            "BodyKinematicsForCom:AutomaticPrintMissing", ...
            ["BodyKinematics recorded data, but AnalyzeTool did not " ...
             "produce a position STO automatically. Attempting direct " ...
             "BodyKinematics.printResults()."]);

        printStatus = ...
            bodyKinematicsAfterRun.printResults( ...
                char(toolName), ...
                char(resultsDirectory), ...
                -1.0, ...
                ".sto");

        assert(printStatus == 0, ...
            "BodyKinematicsForCom:ManualPrintFailed", ...
            "BodyKinematics.printResults() returned status %d.", ...
            printStatus);

        positionFiles = ...
            localFindPositionFiles(resultsDirectory);
    end

    assert(~isempty(positionFiles), ...
        "BodyKinematicsForCom:PositionOutputMissing", ...
        ["Body Kinematics recorded %d rows but no position STO was found " ...
         "under:\n%s"], ...
        positionStorageSize, ...
        resultsDirectory);

    if numel(positionFiles) > 1

        % Prefer a global position result because that is the required HSF
        % point-expression frame.
        globalMask = contains( ...
            lower(positionFiles), ...
            "global");

        if nnz(globalMask) == 1
            positionFile = ...
                positionFiles(globalMask);
        else
            error( ...
                "BodyKinematicsForCom:AmbiguousPositionOutput", ...
                ["Multiple candidate Body Kinematics position files were " ...
                 "found:\n%s"], ...
                strjoin(positionFiles, newline));
        end

    else
        positionFile = positionFiles(1);
    end

    % Basic structural read-back.
    positionStorage = ...
        opensimio.readSto(positionFile);

    assert(positionStorage.NumRows >= 2, ...
        "BodyKinematicsForCom:TooFewRows", ...
        "Body Kinematics position output contains too few samples.");

    assert(all(isfinite(positionStorage.Time)), ...
        "BodyKinematicsForCom:NonfiniteTime", ...
        "Body Kinematics position output contains nonfinite time values.");

    assert(all(diff(positionStorage.Time) > 0), ...
        "BodyKinematicsForCom:NonmonotonicTime", ...
        "Body Kinematics position output time is not strictly increasing.");

    result = struct;

    result.SetupFile = setupFile;
    result.ModelFile = modelFile;
    result.CoordinatesFile = ...
        coordinatesFile;
    result.ResultsDirectory = ...
        resultsDirectory;
    result.PositionFile = ...
        positionFile;
    result.BodyName = bodyName;
    result.TimeRange = timeRange;
    result.RunSucceeded = ...
        runSucceeded;
    result.DurationSeconds = ...
        durationSeconds;
    result.PositionSummary = struct( ...
        "NumRows", positionStorage.NumRows, ...
        "NumColumns", positionStorage.NumColumns, ...
        "StartTime", positionStorage.Time(1), ...
        "EndTime", positionStorage.Time(end), ...
        "Labels", string(positionStorage.Labels));

end


function files = localFindPositionFiles(resultsDirectory)
%LOCALFINDPOSITIONFILES Find Body Kinematics position STO outputs.

    listing = [
        dir(fullfile(resultsDirectory, "*pos*.sto"))
        dir(fullfile(resultsDirectory, "*Pos*.sto"))
        dir(fullfile(resultsDirectory, "*POS*.sto"))
    ];

    if isempty(listing)
        files = strings(0, 1);
        return;
    end

    paths = strings(numel(listing), 1);

    for iFile = 1:numel(listing)
        paths(iFile) = string(fullfile( ...
            listing(iFile).folder, ...
            listing(iFile).name));
    end

    files = unique(paths, "stable");

end
