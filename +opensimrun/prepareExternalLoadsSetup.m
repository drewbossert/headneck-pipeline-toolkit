function result = prepareExternalLoadsSetup( ...
        templateFile, outputFile, varargin)
%PREPAREEXTERNALLOADSSETUP Create a trial-specific ExternalLoads XML.
%
% result = opensimrun.prepareExternalLoadsSetup( ...
%     templateFile, outputFile, ...
%     "DataFile", hsfMotionFile)
%
% This function patches the HSF data-file path into a validated OpenSim
% ExternalLoads XML template. It intentionally does not generate or modify
% the head-support-force data itself.
%
% REQUIRED INPUTS
%   templateFile
%       Path to the shared ExternalLoads XML template.
%
%   outputFile
%       Path for the trial-specific ExternalLoads XML.
%
% NAME-VALUE OPTIONS
%   DataFile
%       Path to the generated HSF .mot file. Required.
%
%   ExternalLoadsName
%       Optional replacement for the <ExternalLoads name="..."> attribute.
%       Default: preserve the template name.
%
%   Overwrite
%       Allow an existing output XML to be replaced.
%       Default: false.
%
%   CreateFolder
%       Create the output parent directory when needed.
%       Default: true.
%
%   RequireDataFile
%       Require DataFile to exist when this function is called.
%       Default: true.
%
%   NormalizePaths
%       Replace backslashes with forward slashes in the written XML path.
%       Default: true.
%
%   ExpectedAppliedBody
%       Expected <applied_to_body> value in the template.
%       Default: "skull".
%
%   ExpectedForceIdentifier
%       Expected <force_identifier> value.
%       Default: "ground_force_1_v".
%
%   ExpectedPointIdentifier
%       Expected <point_identifier> value.
%       Default: "ground_force_1_p".
%
%   RequireEmptyTorqueIdentifier
%       Require <torque_identifier> to remain empty.
%       Default: true.
%
% OUTPUT
%   result.OutputFile
%   result.TemplateFile
%   result.DataFile
%   result.ExternalLoadsName
%   result.PatchReport
%   result.TemplateValidation
%   result.VerificationPassed
%
% The template is expected to contain one ExternalLoads object and one
% ExternalForce. The force remains applied to the skull and expressed in
% ground, with the application point also expressed in ground.
%
% The trial-specific HSF .mot file should provide columns corresponding to:
%   ground_force_1_vx
%   ground_force_1_vy
%   ground_force_1_vz
%   ground_force_1_px
%   ground_force_1_py
%   ground_force_1_pz
%
% No torque identifier is used.

    parser = inputParser;
    parser.FunctionName = ...
        "opensimrun.prepareExternalLoadsSetup";

    addRequired(parser, "templateFile", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addRequired(parser, "outputFile", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "DataFile", "", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "ExternalLoadsName", "", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "Overwrite", false, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "CreateFolder", true, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "RequireDataFile", true, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "NormalizePaths", true, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "ExpectedAppliedBody", "skull", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, ...
        "ExpectedForceIdentifier", ...
        "ground_force_1_v", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, ...
        "ExpectedPointIdentifier", ...
        "ground_force_1_p", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, ...
        "RequireEmptyTorqueIdentifier", ...
        true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, templateFile, outputFile, varargin{:});

    templateFile = string(parser.Results.templateFile);
    outputFile = string(parser.Results.outputFile);
    dataFile = string(parser.Results.DataFile);

    externalLoadsName = ...
        string(parser.Results.ExternalLoadsName);

    overwrite = parser.Results.Overwrite;
    createFolder = parser.Results.CreateFolder;
    requireDataFile = parser.Results.RequireDataFile;
    normalizePaths = parser.Results.NormalizePaths;

    expectedAppliedBody = ...
        string(parser.Results.ExpectedAppliedBody);

    expectedForceIdentifier = ...
        string(parser.Results.ExpectedForceIdentifier);

    expectedPointIdentifier = ...
        string(parser.Results.ExpectedPointIdentifier);

    requireEmptyTorqueIdentifier = ...
        parser.Results.RequireEmptyTorqueIdentifier;

    %% Validate input/output paths

    assert(isfile(templateFile), ...
        "ExternalLoadsSetup:TemplateMissing", ...
        "ExternalLoads template was not found:\n%s", ...
        templateFile);

    [~, ~, templateExtension] = fileparts(templateFile);

    assert(strcmpi(templateExtension, ".xml"), ...
        "ExternalLoadsSetup:InvalidTemplateExtension", ...
        "Template must be an XML file:\n%s", ...
        templateFile);

    [outputParent, ~, outputExtension] = ...
        fileparts(outputFile);

    assert(strcmpi(outputExtension, ".xml"), ...
        "ExternalLoadsSetup:InvalidOutputExtension", ...
        "Output file must use the .xml extension:\n%s", ...
        outputFile);

    assert(strlength(dataFile) > 0, ...
        "ExternalLoadsSetup:DataFileRequired", ...
        "The DataFile name-value argument is required.");

    if requireDataFile
        assert(isfile(dataFile), ...
            "ExternalLoadsSetup:DataFileMissing", ...
            "HSF data file was not found:\n%s", ...
            dataFile);
    end

    if isfile(outputFile) && ~overwrite
        error( ...
            "ExternalLoadsSetup:OutputExists", ...
            ["ExternalLoads output already exists:\n%s\n\n" ...
             "Set Overwrite=true to replace it."], ...
            outputFile);
    end

    if createFolder && ...
            strlength(string(outputParent)) > 0 && ...
            ~isfolder(outputParent)

        mkdir(outputParent);
    end

    %% Read template

    xmlData = opensimio.readXml(templateFile);

    assert(isstruct(xmlData) && ...
        isfield(xmlData, "Document"), ...
        "ExternalLoadsSetup:InvalidXmlReaderOutput", ...
        ["opensimio.readXml did not return the expected " ...
         "structure with a Document field."]);

    document = xmlData.Document;

    %% Validate template structure

    externalLoadsNodes = ...
        document.getElementsByTagName("ExternalLoads");

    assert(externalLoadsNodes.getLength() == 1, ...
        "ExternalLoadsSetup:ExternalLoadsCount", ...
        ["Expected exactly one <ExternalLoads> element, " ...
         "but found %d."], ...
        externalLoadsNodes.getLength());

    externalForceNodes = ...
        document.getElementsByTagName("ExternalForce");

    assert(externalForceNodes.getLength() == 1, ...
        "ExternalLoadsSetup:ExternalForceCount", ...
        ["Expected exactly one <ExternalForce> element, " ...
         "but found %d."], ...
        externalForceNodes.getLength());

    externalLoadsNode = externalLoadsNodes.item(0);

    observedAppliedBody = ...
        localGetUniqueTagText(document, "applied_to_body");

    observedForceExpressedIn = ...
        localGetUniqueTagText( ...
            document, "force_expressed_in_body");

    observedPointExpressedIn = ...
        localGetUniqueTagText( ...
            document, "point_expressed_in_body");

    observedForceIdentifier = ...
        localGetUniqueTagText(document, "force_identifier");

    observedPointIdentifier = ...
        localGetUniqueTagText(document, "point_identifier");

    observedTorqueIdentifier = ...
        localGetUniqueTagText(document, "torque_identifier");

    validationElement = [
        "applied_to_body"
        "force_expressed_in_body"
        "point_expressed_in_body"
        "force_identifier"
        "point_identifier"
        "torque_identifier"
    ];

    expectedValue = [
        expectedAppliedBody
        "ground"
        "ground"
        expectedForceIdentifier
        expectedPointIdentifier
        ""
    ];

    observedValue = [
        observedAppliedBody
        observedForceExpressedIn
        observedPointExpressedIn
        observedForceIdentifier
        observedPointIdentifier
        observedTorqueIdentifier
    ];

    passed = observedValue == expectedValue;

    if ~requireEmptyTorqueIdentifier
        torqueRow = validationElement == "torque_identifier";
        passed(torqueRow) = true;
        expectedValue(torqueRow) = "<not enforced>";
    end

    templateValidation = table( ...
        validationElement, ...
        expectedValue, ...
        observedValue, ...
        passed, ...
        'VariableNames', { ...
            'Element', ...
            'ExpectedValue', ...
            'ObservedValue', ...
            'Passed'});

    if any(~templateValidation.Passed)
        failedRows = ...
            templateValidation(~templateValidation.Passed, :);

        error( ...
            "ExternalLoadsSetup:TemplateValidationFailed", ...
            ["ExternalLoads template structure does not match the " ...
             "expected HSF interface.\nFailed elements: %s"], ...
            strjoin(failedRows.Element, ", "));
    end

    %% Prepare XML-safe path text

    dataFileForXml = dataFile;

    if normalizePaths
        dataFileForXml = replace( ...
            dataFileForXml, ...
            "\", ...
            "/");
    end

    %% Patch ExternalLoads name when requested

    oldExternalLoadsName = ...
        string(char(externalLoadsNode.getAttribute("name")));

    if strlength(externalLoadsName) > 0

        newExternalLoadsName = externalLoadsName;

        externalLoadsNode.setAttribute( ...
            "name", ...
            char(newExternalLoadsName));

        nameRequested = true;

    else

        newExternalLoadsName = oldExternalLoadsName;
        nameRequested = false;

    end

    %% Patch HSF data file

    dataFileNode = ...
        localGetUniqueTagNode(document, "datafile");

    oldDataFile = ...
        strtrim(string(char(dataFileNode.getTextContent())));

    dataFileNode.setTextContent( ...
        char(dataFileForXml));

    %% Build patch report

    element = [
        "ExternalLoads@name"
        "datafile"
    ];

    oldValue = [
        oldExternalLoadsName
        oldDataFile
    ];

    newValue = [
        newExternalLoadsName
        dataFileForXml
    ];

    requested = [
        nameRequested
        true
    ];

    changed = oldValue ~= newValue;

    patchReport = table( ...
        element, ...
        oldValue, ...
        newValue, ...
        requested, ...
        changed, ...
        'VariableNames', { ...
            'Element', ...
            'OldValue', ...
            'NewValue', ...
            'Requested', ...
            'Changed'});

    %% Write XML

    opensimio.writeXml( ...
        outputFile, ...
        xmlData);

    assert(isfile(outputFile), ...
        "ExternalLoadsSetup:WriteFailed", ...
        "ExternalLoads XML was not written:\n%s", ...
        outputFile);

    %% Re-read and verify written output

    verificationXml = ...
        opensimio.readXml(outputFile);

    verificationDocument = ...
        verificationXml.Document;

    verifiedDataFile = ...
        localGetUniqueTagText( ...
            verificationDocument, ...
            "datafile");

    dataFileVerified = ...
        verifiedDataFile == dataFileForXml;

    verifiedExternalLoadsNodes = ...
        verificationDocument.getElementsByTagName( ...
            "ExternalLoads");

    assert( ...
        verifiedExternalLoadsNodes.getLength() == 1, ...
        "ExternalLoadsSetup:VerificationStructureFailed", ...
        ["Written XML does not contain exactly one " ...
         "<ExternalLoads> element."]);

    verifiedExternalLoadsName = string(char( ...
        verifiedExternalLoadsNodes.item(0). ...
        getAttribute("name")));

    nameVerified = ...
        verifiedExternalLoadsName == ...
        newExternalLoadsName;

    verificationPassed = ...
        dataFileVerified && nameVerified;

    assert(verificationPassed, ...
        "ExternalLoadsSetup:VerificationFailed", ...
        ["Written ExternalLoads XML did not preserve the " ...
         "requested patched values."]);

    %% Return result

    result = struct;

    result.TemplateFile = templateFile;
    result.OutputFile = outputFile;
    result.DataFile = dataFile;
    result.DataFileWrittenToXml = dataFileForXml;

    result.ExternalLoadsName = ...
        newExternalLoadsName;

    result.PatchReport = patchReport;
    result.TemplateValidation = ...
        templateValidation;

    result.VerificationPassed = ...
        verificationPassed;

end


function node = localGetUniqueTagNode(document, tagName)
%LOCALGETUNIQUETAGNODE Return exactly one XML element by tag name.

    tagName = string(tagName);

    nodes = ...
        document.getElementsByTagName( ...
            char(tagName));

    assert(nodes.getLength() == 1, ...
        "ExternalLoadsSetup:UnexpectedTagCount", ...
        ["Expected exactly one <%s> element, " ...
         "but found %d."], ...
        tagName, ...
        nodes.getLength());

    node = nodes.item(0);

end


function value = localGetUniqueTagText(document, tagName)
%LOCALGETUNIQUETAGTEXT Return trimmed text from one XML element.

    node = ...
        localGetUniqueTagNode( ...
            document, tagName);

    value = ...
        strtrim(string(char( ...
            node.getTextContent())));

end
