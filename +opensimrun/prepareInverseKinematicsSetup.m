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
%   MarkerFile
%   OutputMotionFile
%   TimeRange
%
% Optional name-value options:
%   ModelFile        If <model_file> exists, patch it. If the tag is absent,
%                    retain the model path only for the returned metadata;
%                    pass the model separately to runInverseKinematicsSetup.
%   CoordinateFile   "" leaves the template value unchanged
%   ResultsDirectory "" patches <results_directory> only when present
%   ToolName         "" leaves the template tool name unchanged
%   Overwrite        true
%
% The template's task set, weights, constraint weight, accuracy, and other
% project-specific settings are preserved.

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

    requiredValues = [markerFile, outputMotionFile];

    if any(strlength(requiredValues) == 0)
        error("opensimrun:MissingIkSetupValue", ...
            "MarkerFile and OutputMotionFile must both be supplied.");
    end

    if isempty(timeRange)
        error("opensimrun:MissingIkTimeRange", ...
            "TimeRange must be supplied.");
    end

    if strlength(modelFile) > 0
        assert(isfile(modelFile), ...
            "opensimrun:ModelFileNotFound", ...
            "Model file was not found:\n%s", modelFile);
    end

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

    patchReport = strings(0, 4);

    if strlength(modelFile) > 0
        patchReport(end+1,:) = patchTag( ...
            document, "model_file", modelFile, false);
    else
        patchReport(end+1,:) = inspectTag( ...
            document, "model_file");
    end

    patchReport(end+1,:) = patchTag( ...
        document, "marker_file", markerFile);

    patchReport(end+1,:) = patchTag( ...
        document, "output_motion_file", outputMotionFile);

    timeRangeText = sprintf("%.15g %.15g", ...
        timeRange(1), timeRange(2));

    patchReport(end+1,:) = patchTag( ...
        document, "time_range", string(timeRangeText));

    coordinateFile = string(parser.Results.CoordinateFile);

    if strlength(coordinateFile) > 0
        assert(isfile(coordinateFile), ...
            "opensimrun:CoordinateFileNotFound", ...
            "Coordinate file was not found:\n%s", coordinateFile);

        patchReport(end+1,:) = patchTag( ...
            document, "coordinate_file", coordinateFile);
    end

    resultsDirectory = string(parser.Results.ResultsDirectory);

    if strlength(resultsDirectory) > 0
        if ~isfolder(resultsDirectory)
            mkdir(resultsDirectory);
        end

        patchReport(end+1,:) = patchTag( ...
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
        patchReport(:,4), ...
        'VariableNames', ...
        {'Tag', 'Value', 'NodeCount', 'Action'});

    modelTagCount = str2double( ...
        patchReport(patchReport(:,1) == "model_file", 3));

    result = struct;
    result.TemplateFile = templateFile;
    result.OutputSetupFile = outputSetupFile;
    result.ModelFile = modelFile;
    result.SetupContainsModelFile = modelTagCount == 1;
    result.ModelInjectionRequired = ...
        strlength(modelFile) > 0 && modelTagCount == 0;
    result.MarkerFile = markerFile;
    result.OutputMotionFile = outputMotionFile;
    result.TimeRange = timeRange;
    result.PatchReport = patchTable;
end

function row = patchTag(document, tagName, value, required)

    nodes = document.getElementsByTagName(char(tagName));
    nodeCount = nodes.getLength();

    if nodeCount > 1
        error("opensimrun:UnexpectedIkTagCount", ...
            "Expected at most one <%s> tag but found %d.", ...
            tagName, nodeCount);
    end

    if nodeCount == 0
        if required
            error("opensimrun:RequiredIkTagMissing", ...
                ["Required IK tag <%s> was not found. " ...
                 "Check the template structure."], ...
                tagName);
        end

        row = [ ...
            string(tagName), ...
            string(value), ...
            "0", ...
            "absent_not_patched"];
        return;
    end

    nodes.item(0).setTextContent(char(value));

    row = [ ...
        string(tagName), ...
        string(value), ...
        "1", ...
        "patched"];
end

function row = inspectTag(document, tagName)

    nodes = document.getElementsByTagName(char(tagName));
    nodeCount = nodes.getLength();

    if nodeCount > 1
        error("opensimrun:UnexpectedIkTagCount", ...
            "Expected at most one <%s> tag but found %d.", ...
            tagName, nodeCount);
    end

    if nodeCount == 1
        value = strtrim(string(char( ...
            nodes.item(0).getTextContent())));
        action = "retained";
    else
        value = "";
        action = "absent";
    end

    row = [ ...
        string(tagName), ...
        value, ...
        string(nodeCount), ...
        action];
end