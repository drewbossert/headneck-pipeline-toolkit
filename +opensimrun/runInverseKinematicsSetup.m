function result = runInverseKinematicsSetup(setupFile, varargin)
%RUNINVERSEKINEMATICSSETUP Execute a saved OpenSim IK setup XML.
%
% result = opensimrun.runInverseKinematicsSetup(setupFile)
%
% Name-value options:
%   ModelInput                "" uses <model_file> from XML
%                             May be an .osim path or OpenSim Model object
%   ExpectedOutputMotionFile  "" reads <output_motion_file> from XML
%   Overwrite                 true
%
% When ModelInput is supplied, the setup is loaded without requesting that
% OpenSim load a model from <model_file>. The supplied model is finalized,
% initialized, and attached directly through InverseKinematicsTool.setModel.

    import org.opensim.modeling.*

    parser = inputParser;
    parser.FunctionName = ...
        "opensimrun.runInverseKinematicsSetup";

    addRequired(parser, "setupFile", ...
        @opensimrun.internal.isTextScalar);

    addParameter(parser, "ModelInput", "");

    addParameter(parser, "ExpectedOutputMotionFile", "", ...
        @opensimrun.internal.isTextScalar);

    addParameter(parser, "Overwrite", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, setupFile, varargin{:});

    setupFile = string(setupFile);

    assert(isfile(setupFile), ...
        "opensimrun:IkSetupNotFound", ...
        "IK setup file was not found:\n%s", setupFile);

    outputMotionFile = string( ...
        parser.Results.ExpectedOutputMotionFile);

    if strlength(outputMotionFile) == 0
        outputMotionFile = readSingleTagText( ...
            setupFile, "output_motion_file");
    end

    if strlength(outputMotionFile) == 0
        error("opensimrun:IkOutputNotSpecified", ...
            "Could not determine the IK output motion file.");
    end

    if isfile(outputMotionFile)
        if parser.Results.Overwrite
            delete(outputMotionFile);
        else
            error("opensimrun:IkOutputExists", ...
                "IK output motion file already exists:\n%s", ...
                outputMotionFile);
        end
    end

    modelInput = parser.Results.ModelInput;
    useInjectedModel = hasModelInput(modelInput);

    if useInjectedModel
        [model, ~] = modelprep.loadModel(modelInput);

        try
            tool = InverseKinematicsTool( ...
                char(setupFile), false);
        catch exception
            error("opensimrun:IkNoLoadConstructorFailed", ...
                ["Could not construct InverseKinematicsTool with " ...
                 "aLoadModel=false. This overload is required when the " ...
                 "setup XML omits <model_file>.\n\n%s"], ...
                exception.message);
        end

        tool.setModel(model);
        modelSource = "injected";
    else
        modelFile = readSingleTagText(setupFile, "model_file");

        if strlength(modelFile) == 0
            error("opensimrun:IkModelNotSpecified", ...
                ["The IK setup does not contain <model_file>, and no " ...
                 "ModelInput was supplied.\n\nPass ModelInput as the " ...
                 "Model A .osim file or an initialized OpenSim Model."]);
        end

        tool = InverseKinematicsTool(char(setupFile));
        model = [];
        modelSource = "xml";
    end

    startTime = tic;
    runSucceeded = logical(tool.run());
    durationSeconds = toc(startTime);

    if ~runSucceeded
        error("opensimrun:IkRunFailed", ...
            "OpenSim InverseKinematicsTool returned false.");
    end

    if ~isfile(outputMotionFile)
        error("opensimrun:IkOutputMissing", ...
            ["Inverse Kinematics completed, but the expected output " ...
             "file was not found:\n%s"], ...
            outputMotionFile);
    end

    motion = opensimio.readMot(outputMotionFile);

    result = struct;
    result.SetupFile = setupFile;
    result.OutputMotionFile = outputMotionFile;
    result.Tool = tool;
    result.Model = model;
    result.ModelSource = modelSource;
    result.RunSucceeded = runSucceeded;
    result.DurationSeconds = durationSeconds;
    result.Motion = motion;
end

function tf = hasModelInput(modelInput)

    if ischar(modelInput)
        tf = ~isempty(modelInput);
    elseif isstring(modelInput)
        tf = isscalar(modelInput) && strlength(modelInput) > 0;
    else
        tf = isa(modelInput, "org.opensim.modeling.Model");
    end
end

function value = readSingleTagText(xmlFile, tagName)

    xmlData = opensimio.readXml(xmlFile);
    nodes = xmlData.Document.getElementsByTagName(char(tagName));

    if nodes.getLength() ~= 1
        value = "";
        return;
    end

    value = strtrim(string(char( ...
        nodes.item(0).getTextContent())));
end