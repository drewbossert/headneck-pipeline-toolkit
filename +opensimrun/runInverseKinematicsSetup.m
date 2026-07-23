function result = runInverseKinematicsSetup(setupFile, varargin)
%RUNINVERSEKINEMATICSSETUP Execute a saved OpenSim IK setup XML.
%
% result = opensimrun.runInverseKinematicsSetup(setupFile)
%
% Name-value options:
%   ExpectedOutputMotionFile  "" reads <output_motion_file> from XML
%   Overwrite                 true
%
% The returned result includes Tool, SetupFile, OutputMotionFile,
% RunSucceeded, Motion, and DurationSeconds.

    import org.opensim.modeling.*

    parser = inputParser;
    parser.FunctionName = ...
        "opensimrun.runInverseKinematicsSetup";

    addRequired(parser, "setupFile", ...
        @opensimrun.internal.isTextScalar);

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

    tool = InverseKinematicsTool(char(setupFile));

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
    result.RunSucceeded = runSucceeded;
    result.DurationSeconds = durationSeconds;
    result.Motion = motion;
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
