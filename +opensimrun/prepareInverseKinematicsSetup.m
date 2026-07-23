function result = prepareInverseKinematicsSetup( ...
        templateFile, outputSetupFile, varargin)
%PREPAREINVERSEKINEMATICSSETUP Copy and patch an OpenSim IK setup XML.
%
% result = opensimrun.prepareInverseKinematicsSetup( ...
%     templateFile, outputSetupFile, ...
%     "ModelFile", modelFile, ...
%     "MarkerFile", markerFile, ...
%     "OutputMotionFile", outputMotionFile, ...
%     "TimeRange", [initialTime finalTime])
%
% Required name-value options:
%   ModelFile
%   MarkerFile
%   OutputMotionFile
%   TimeRange
%
% Optional name-value options:
%   CoordinateFile  "" leaves the template value unchanged
%   ResultsDirectory "" patches <results_directory> only when that tag exists
%   ToolName         "" leaves the template tool name unchanged
%   Overwrite        true
%
% This function preserves the template's IK task set, marker weights,
% constraint weight, accuracy, and other project-specific settings.

    parser = inputParser;
    parser.FunctionName = ...
        "opensimrun.prepareInverseKinematicsSetup";

    addRequired(parser, "templateFile", ...
        @opensimrun.internal.isTextScalar);

    addRequired(parser, "outputSetupFile", ...
        @opensimrun.internal.isTextScalar);

    addParameter(parser, "ModelFile", "", ...
        @opensimrun.internal.isTextScalar);

    addParameter(parser, "MarkerFile", "", ...
        @opensimrun.internal.isTextScalar);

    addParameter(parser, "OutputMotionFile", "", ...
        @opensimrun.internal.isTextScalar);

    addParameter(parser, "TimeRange", [], ...
        @(x) isnumeric(x) && numel(x) == 2 && ...
        all(isfinite(x)) && x(2) >= x(1));

    addParameter(parser, "CoordinateFile", "", ...
        @opensimrun.internal.isTextScalar);

    addParameter(parser, "ResultsDirectory", "", ...
        @opensimrun.internal.isTextScalar);

    addParameter(parser, "ToolName", "", ...
        @opensimrun.internal.isTextScalar);

    addParameter(parser, "Overwrite", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, templateFile, outputSetupFile, varargin{:});

    templateFile = string(templateFile);
    outputSetupFile = string(outputSetupFile);
    modelFile = string(parser.Results.ModelFile);
    markerFile = string(parser.Results.MarkerFile);
    outputMotionFile = string(parser.Results.OutputMotionFile);
    timeRange = double(parser.Results.TimeRange(:)).';

    assert(isfile(templateFile), ...
        "opensimrun:IkTemplateNotFound", ...
        "IK setup template was not found:\n%s", templateFile);

    requiredValues = [modelFile, markerFile, outputMotionFile];

    if any(strlength(requiredValues) == 0)
        error("opensimrun:MissingIkSetupValue", ...
            ["ModelFile, MarkerFile, and OutputMotionFile must " ...
             "all be supplied."]);
    end

    assert(isfile(modelFile), ...
        "opensimrun:ModelFileNotFound", ...
        "Model file was not found:\n%s", modelFile);

    assert(isfile(markerFile), ...
        "opensimrun:MarkerFileNotFound", ...
        "Marker file was not found:\n%s", markerFile);

    if isfile(outputSetupFile) && ~parser.Results.Overwrite
        error("opensimrun:IkSetupExists", ...
            "Output IK setup already exists:\n%s", outputSetupFile);
    end

    parentFolder = fileparts(outputSetupFile);

    if strlength(parentFolder) > 0 && ~isfolder(parentFolder)
        mkdir(parentFolder);
    end

    outputMotionFolder = fileparts(outputMotionFile);

    if strlength(outputMotionFolder) > 0 && ...
            ~isfolder(outputMotionFolder)
        mkdir(outputMotionFolder);
    end

    xmlData = opensimio.readXml(templateFile);
    document = xmlData.Document;

    patchReport = strings(0, 3);
    patchReport(end+1,:) = patchRequiredTag( ...
        document, "model_file", modelFile);

    patchReport(end+1,:) = patchRequiredTag( ...
        document, "marker_file", markerFile);

    patchReport(end+1,:) = patchRequiredTag( ...
        document, "output_motion_file", outputMotionFile);

    timeRangeText = sprintf("%.15g %.15g", ...
        timeRange(1), timeRange(2));

    patchReport(end+1,:) = patchRequiredTag( ...
        document, "time_range", string(timeRangeText));

    coordinateFile = string(parser.Results.CoordinateFile);

    if strlength(coordinateFile) > 0
        assert(isfile(coordinateFile), ...
            "opensimrun:CoordinateFileNotFound", ...
            "Coordinate file was not found:\n%s", coordinateFile);

        patchReport(end+1,:) = patchOptionalTag( ...
            document, "coordinate_file", coordinateFile);
    end

    resultsDirectory = string(parser.Results.ResultsDirectory);

    if strlength(resultsDirectory) > 0
        if ~isfolder(resultsDirectory)
            mkdir(resultsDirectory);
        end

        patchReport(end+1,:) = patchOptionalTag( ...
            document, "results_directory", resultsDirectory);
    end

    toolName = string(parser.Results.ToolName);

    if strlength(toolName) > 0
        rootElement = document.getDocumentElement();
        objectNodes = rootElement.getElementsByTagName( ...
            "InverseKinematicsTool");

        if objectNodes.getLength() == 0 && ...
                string(char(rootElement.getNodeName())) == ...
                "InverseKinematicsTool"
            toolNode = rootElement;
        elseif objectNodes.getLength() >= 1
            toolNode = objectNodes.item(0);
        else
            error("opensimrun:IkToolNodeMissing", ...
                "Could not locate the InverseKinematicsTool element.");
        end

        toolNode.setAttribute("name", char(toolName));
    end

    opensimio.writeXml(outputSetupFile, xmlData);

    if ~isfile(outputSetupFile)
        error("opensimrun:IkSetupWriteFailed", ...
            "Patched IK setup file was not written:\n%s", ...
            outputSetupFile);
    end

    patchTable = table( ...
        patchReport(:,1), ...
        patchReport(:,2), ...
        str2double(patchReport(:,3)), ...
        'VariableNames', ...
        {'Tag', 'Value', 'NodeCount'});

    result = struct;
    result.TemplateFile = templateFile;
    result.OutputSetupFile = outputSetupFile;
    result.ModelFile = modelFile;
    result.MarkerFile = markerFile;
    result.OutputMotionFile = outputMotionFile;
    result.TimeRange = timeRange;
    result.PatchReport = patchTable;
end

function row = patchRequiredTag(document, tagName, value)

    nodes = document.getElementsByTagName(char(tagName));
    nodeCount = nodes.getLength();

    if nodeCount ~= 1
        error("opensimrun:UnexpectedIkTagCount", ...
            ["Expected exactly one <%s> tag but found %d. " ...
             "Check the IK template structure."], ...
            tagName, nodeCount);
    end

    nodes.item(0).setTextContent(char(value));

    row = [string(tagName), string(value), string(nodeCount)];
end

function row = patchOptionalTag(document, tagName, value)

    nodes = document.getElementsByTagName(char(tagName));
    nodeCount = nodes.getLength();

    if nodeCount > 1
        error("opensimrun:UnexpectedIkTagCount", ...
            "Expected at most one <%s> tag but found %d.", ...
            tagName, nodeCount);
    end

    if nodeCount == 1
        nodes.item(0).setTextContent(char(value));
    end

    row = [string(tagName), string(value), string(nodeCount)];
end
