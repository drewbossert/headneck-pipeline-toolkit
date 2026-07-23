function result = generateTrial( ...
        modelFile, ikMotionFile, outputDirectory, ...
        conditionAngleDeg, varargin)
%GENERATETRIAL Run skull CoM analysis and generate the HSF .mot file.
%
% result = hsf.generateTrial( ...
%     modelFile, ikMotionFile, outputDirectory, conditionAngleDeg)
%
% Name-value options:
%   BodyName
%   SkullMassKg              [] extracts body mass from model
%   GravityY
%   OutputMotName            "head_support_force.mot"
%   AnalysisToolName         "skull_com"
%   AnalysisSetupFile        "" or path
%   ExistingPositionFile     "" to run BodyKinematics
%   TargetRateHz
%   OffIntervals
%   RampDuration
%   RampShape
%   RadialSign
%   AzimuthConvention
%   InterpolationMethod
%   ForcePrefix
%   PointPrefix
%   TorquePrefix
%   IncludeTorque
%
% Intermediate BodyKinematics outputs are retained in:
%   outputDirectory/body_kinematics/

    defaults = hsf.defaultParameters();

    parser = inputParser;
    parser.FunctionName = "hsf.generateTrial";

    addRequired(parser, "modelFile");
    addRequired(parser, "ikMotionFile");
    addRequired(parser, "outputDirectory");
    addRequired(parser, "conditionAngleDeg");

    addParameter(parser, "BodyName", defaults.BodyName);
    addParameter(parser, "SkullMassKg", []);
    addParameter(parser, "GravityY", defaults.GravityY);
    addParameter(parser, "OutputMotName", "head_support_force.mot");
    addParameter(parser, "AnalysisToolName", "skull_com");
    addParameter(parser, "AnalysisSetupFile", "");
    addParameter(parser, "ExistingPositionFile", "");
    addParameter(parser, "TargetRateHz", defaults.TargetRateHz);
    addParameter(parser, "OffIntervals", zeros(0,2));
    addParameter(parser, "RampDuration", defaults.RampDuration);
    addParameter(parser, "RampShape", defaults.RampShape);
    addParameter(parser, "RadialSign", defaults.RadialSign);
    addParameter(parser, "AzimuthConvention", defaults.AzimuthConvention);
    addParameter(parser, "InterpolationMethod", defaults.InterpolationMethod);
    addParameter(parser, "ForcePrefix", defaults.ForcePrefix);
    addParameter(parser, "PointPrefix", defaults.PointPrefix);
    addParameter(parser, "TorquePrefix", defaults.TorquePrefix);
    addParameter(parser, "IncludeTorque", defaults.IncludeTorque);

    parse(parser, modelFile, ikMotionFile, ...
        outputDirectory, conditionAngleDeg, varargin{:});

    outputDirectory = string(outputDirectory);

    if ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end

    bodyKinematicsDirectory = fullfile( ...
        outputDirectory, "body_kinematics");

    if ~isfolder(bodyKinematicsDirectory)
        mkdir(bodyKinematicsDirectory);
    end

    existingPositionFile = string( ...
        parser.Results.ExistingPositionFile);

    if strlength(existingPositionFile) == 0
        setupFile = string(parser.Results.AnalysisSetupFile);

        if strlength(setupFile) == 0
            setupFile = fullfile( ...
                bodyKinematicsDirectory, ...
                "analyze_body_kinematics.xml");
        end

        analysisResult = opensimrun.runBodyKinematics( ...
            modelFile, ikMotionFile, bodyKinematicsDirectory, ...
            "BodyNames", parser.Results.BodyName, ...
            "ToolName", parser.Results.AnalysisToolName, ...
            "AnalysisName", "BodyKinematics", ...
            "ExpressResultsInLocalFrame", false, ...
            "RecordModelCenterOfMass", false, ...
            "SetupFile", setupFile, ...
            "Overwrite", true);

        positionFile = analysisResult.PositionFile;
    else
        assert(isfile(existingPositionFile), ...
            "hsf:PositionFileNotFound", ...
            "Existing BodyKinematics position file was not found:\n%s", ...
            existingPositionFile);

        analysisResult = struct;
        analysisResult.PositionFile = existingPositionFile;
        analysisResult.RunSucceeded = NaN;
        positionFile = existingPositionFile;
    end

    if strlength(positionFile) == 0
        error("hsf:PositionOutputMissing", ...
            "BodyKinematics did not provide a position output file.");
    end

    skullMassKg = parser.Results.SkullMassKg;

    if isempty(skullMassKg)
        skullMassKg = hsf.getBodyMass( ...
            modelFile, parser.Results.BodyName);
    end

    outputMotFile = fullfile( ...
        outputDirectory, string(parser.Results.OutputMotName));

    generationResult = hsf.generateFromBodyKinematics( ...
        positionFile, ikMotionFile, outputMotFile, ...
        conditionAngleDeg, ...
        "BodyName", parser.Results.BodyName, ...
        "SkullMassKg", skullMassKg, ...
        "GravityY", parser.Results.GravityY, ...
        "TargetRateHz", parser.Results.TargetRateHz, ...
        "OffIntervals", parser.Results.OffIntervals, ...
        "RampDuration", parser.Results.RampDuration, ...
        "RampShape", parser.Results.RampShape, ...
        "RadialSign", parser.Results.RadialSign, ...
        "AzimuthConvention", parser.Results.AzimuthConvention, ...
        "InterpolationMethod", ...
        parser.Results.InterpolationMethod, ...
        "ForcePrefix", parser.Results.ForcePrefix, ...
        "PointPrefix", parser.Results.PointPrefix, ...
        "TorquePrefix", parser.Results.TorquePrefix, ...
        "IncludeTorque", parser.Results.IncludeTorque);

    result = generationResult;
    result.ModelFile = string(modelFile);
    result.OutputDirectory = outputDirectory;
    result.BodyKinematics = analysisResult;
    result.SkullMassKg = skullMassKg;
end
