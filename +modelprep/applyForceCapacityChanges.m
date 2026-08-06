function result = applyForceCapacityChanges( ...
        modelFile, outputModelFile, changes, varargin)
%APPLYFORCECAPACITYCHANGES Apply ForceSet capacity and appliesForce edits.
%
% The XML tree is edited directly. Missing <appliesForce> is interpreted as
% OpenSim's default true. If a missing/default-enabled object is explicitly
% disabled, this function inserts <appliesForce>false</appliesForce>.
%
% changes must contain:
%   Name
%   ObjectType
%   ProposedAppliesForce
%   CapacityParameter
%   ProposedValue
%
% Objects without a supported scalar capacity can still have appliesForce
% edited.

    parser = inputParser;
    parser.FunctionName = ...
        "modelprep.applyForceCapacityChanges";

    addRequired(parser, "modelFile", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addRequired(parser, "outputModelFile", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addRequired(parser, "changes", @istable);

    addParameter(parser, "Overwrite", false, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "AuditFile", "", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "MinimumValue", eps, ...
        @(x) isnumeric(x) && isscalar(x) && ...
        isfinite(x) && x >= 0);

    parse(parser, modelFile, outputModelFile, changes, varargin{:});

    modelFile = string(parser.Results.modelFile);
    outputModelFile = string(parser.Results.outputModelFile);
    auditFile = string(parser.Results.AuditFile);
    overwrite = parser.Results.Overwrite;
    minimumValue = double(parser.Results.MinimumValue);

    assert(isfile(modelFile), ...
        "ForceCapacity:ModelMissing", ...
        "Input model was not found:\n%s", modelFile);

    requiredColumns = [ ...
        "Name"
        "ObjectType"
        "ProposedAppliesForce"
        "CapacityParameter"
        "ProposedValue"
    ];

    assert(all(ismember( ...
        requiredColumns, ...
        string(changes.Properties.VariableNames))), ...
        "ForceCapacity:ChangeColumnsMissing", ...
        "changes must contain Name, ObjectType, ProposedAppliesForce, CapacityParameter, and ProposedValue.");

    assert(height(changes) > 0, ...
        "ForceCapacity:NoChanges", ...
        "No changes were provided.");

    xmlData = opensimio.readXml(modelFile);
    document = xmlData.Document;

    forceSetNodes = document.getElementsByTagName("ForceSet");

    assert(forceSetNodes.getLength() == 1, ...
        "ForceCapacity:ForceSetCount", ...
        "Expected exactly one ForceSet; found %d.", ...
        forceSetNodes.getLength());

    objectsNode = localGetUniqueDirectChild( ...
        forceSetNodes.item(0), "objects");

    objectNodes = localCollectDirectForceObjects(objectsNode);

    auditName = strings(height(changes),1);
    auditType = strings(height(changes),1);
    auditParameter = strings(height(changes),1);
    oldEnabled = false(height(changes),1);
    oldEnabledExplicit = false(height(changes),1);
    newEnabled = false(height(changes),1);
    oldValue = nan(height(changes),1);
    newValue = nan(height(changes),1);

    for iRow = 1:height(changes)

        name = string(changes.Name(iRow));
        objectType = string(changes.ObjectType(iRow));

        objectNode = localFindForceObject( ...
            objectNodes, name, objectType);

        [enabledText, enabledFound, appliesForceNode] = ...
            localGetOptionalDirectChild( ...
                objectNode, "appliesForce");

        if enabledFound
            oldEnabled(iRow) = ...
                localParseBoolean(enabledText);
            oldEnabledExplicit(iRow) = true;
        else
            oldEnabled(iRow) = true;
            oldEnabledExplicit(iRow) = false;
        end

        newEnabled(iRow) = ...
            logical(changes.ProposedAppliesForce(iRow));

        if enabledFound

            appliesForceNode.setTextContent( ...
                char(localBooleanText( ...
                    newEnabled(iRow))));

        elseif ~newEnabled(iRow)

            % Default true is currently implicit. Insert an explicit false
            % only because the requested state differs from the default.
            newNode = document.createElement("appliesForce");
            newNode.setTextContent("false");

            firstElement = ...
                localFindFirstElementChild(objectNode);

            if isempty(firstElement)
                objectNode.appendChild(newNode);
            else
                objectNode.insertBefore(newNode, firstElement);
            end
        end

        parameterName = ...
            string(changes.CapacityParameter(iRow));

        if strlength(parameterName) > 0

            proposedValue = ...
                double(changes.ProposedValue(iRow));

            assert(isfinite(proposedValue) && ...
                   proposedValue > minimumValue, ...
                "ForceCapacity:InvalidProposedValue", ...
                "Proposed value for '%s' must be finite and greater than %.9g.", ...
                name, minimumValue);

            parameterNode = ...
                localGetUniqueDirectChild( ...
                    objectNode, parameterName);

            oldValue(iRow) = str2double( ...
                string(char( ...
                    parameterNode.getTextContent())));

            assert(isfinite(oldValue(iRow)), ...
                "ForceCapacity:InvalidExistingValue", ...
                "Existing %s for '%s' is not numeric.", ...
                parameterName, name);

            newValue(iRow) = proposedValue;

            parameterNode.setTextContent( ...
                sprintf("%.17g", proposedValue));
        end

        auditName(iRow) = name;
        auditType(iRow) = objectType;
        auditParameter(iRow) = parameterName;
    end

    if isfile(outputModelFile) && ~overwrite
        error( ...
            "ForceCapacity:OutputExists", ...
            "Output model already exists:\n%s\nSet Overwrite=true to replace it.", ...
            outputModelFile);
    end

    [outputFolder,~,extension] = ...
        fileparts(outputModelFile);

    assert(strcmpi(extension, ".osim"), ...
        "ForceCapacity:InvalidOutputExtension", ...
        "Output model must use the .osim extension.");

    if strlength(string(outputFolder)) > 0 && ...
            ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    localWriteXml(document, outputModelFile);

    assert(isfile(outputModelFile), ...
        "ForceCapacity:WriteFailed", ...
        "Modified model was not written:\n%s", ...
        outputModelFile);

    %% Verify OpenSim can load the written model.

    import org.opensim.modeling.*

    verificationModel = Model(char(outputModelFile));
    verificationModel.finalizeConnections();

    %% Reinspect written effective states/values.

    verification = ...
        modelprep.inspectForceCapacities( ...
            outputModelFile);

    verifyTable = verification.Capacities;

    verifiedEnabled = false(height(changes),1);
    verifiedEnabledExplicit = false(height(changes),1);
    verifiedValue = nan(height(changes),1);
    verificationPassed = false(height(changes),1);

    for iRow = 1:height(changes)

        match = ...
            verifyTable.Name == auditName(iRow) & ...
            verifyTable.ObjectType == auditType(iRow);

        assert(nnz(match) == 1, ...
            "ForceCapacity:VerificationLookupFailed", ...
            "Could not uniquely verify '%s' (%s).", ...
            auditName(iRow), auditType(iRow));

        verifiedEnabled(iRow) = ...
            verifyTable.AppliesForce(match);

        verifiedEnabledExplicit(iRow) = ...
            verifyTable.AppliesForceExplicit(match);

        if strlength(auditParameter(iRow)) > 0

            verifiedValue(iRow) = ...
                verifyTable.CurrentValue(match);

            valuePassed = ...
                abs(verifiedValue(iRow) - newValue(iRow)) <= ...
                max(1e-12, 1e-10 * abs(newValue(iRow)));
        else
            valuePassed = true;
        end

        enabledPassed = ...
            verifiedEnabled(iRow) == newEnabled(iRow);

        verificationPassed(iRow) = ...
            valuePassed && enabledPassed;
    end

    audit = table( ...
        auditName, ...
        auditType, ...
        auditParameter, ...
        oldEnabled, ...
        oldEnabledExplicit, ...
        newEnabled, ...
        verifiedEnabled, ...
        verifiedEnabledExplicit, ...
        oldValue, ...
        newValue, ...
        verifiedValue, ...
        verificationPassed, ...
        'VariableNames', { ...
            'Name', ...
            'ObjectType', ...
            'CapacityParameter', ...
            'OldAppliesForce', ...
            'OldAppliesForceExplicit', ...
            'NewAppliesForce', ...
            'VerifiedAppliesForce', ...
            'VerifiedAppliesForceExplicit', ...
            'OldValue', ...
            'NewValue', ...
            'VerifiedValue', ...
            'VerificationPassed'});

    assert(all(audit.VerificationPassed), ...
        "ForceCapacity:VerificationFailed", ...
        "One or more ForceSet changes failed verification.");

    if strlength(auditFile) > 0

        [auditFolder,~,~] = ...
            fileparts(auditFile);

        if strlength(string(auditFolder)) > 0 && ...
                ~isfolder(auditFolder)
            mkdir(auditFolder);
        end

        writetable(audit, auditFile);
    end

    result = struct;
    result.InputModelFile = modelFile;
    result.OutputModelFile = outputModelFile;
    result.AuditFile = auditFile;
    result.Audit = audit;
    result.VerificationPassed = ...
        all(audit.VerificationPassed);
end


function nodes = localCollectDirectForceObjects(objectsNode)

    children = objectsNode.getChildNodes();
    nodes = cell(0,1);

    for iNode = 0:(children.getLength()-1)

        child = children.item(iNode);

        if child.getNodeType() ~= 1
            continue;
        end

        nodes{end+1,1} = child; %#ok<AGROW>
    end
end


function node = localFindForceObject(nodes, name, objectType)

    matches = false(numel(nodes),1);

    for iNode = 1:numel(nodes)

        thisNode = nodes{iNode};

        thisType = string(char(thisNode.getNodeName()));
        thisName = string(char(thisNode.getAttribute("name")));

        matches(iNode) = ...
            thisType == objectType && ...
            thisName == name;
    end

    assert(nnz(matches) == 1, ...
        "ForceCapacity:ObjectLookupFailed", ...
        "Could not uniquely locate ForceSet object '%s' of type '%s'.", ...
        name, objectType);

    node = nodes{find(matches,1)};
end


function node = localGetUniqueDirectChild(parentNode, childName)

    [~, found, node] = ...
        localGetOptionalDirectChild( ...
            parentNode, childName);

    assert(found, ...
        "ForceCapacity:DirectChildMissing", ...
        "Required direct <%s> child was not found.", ...
        string(childName));
end


function [value, found, node] = ...
        localGetOptionalDirectChild(parentNode, childName)

    childNodes = parentNode.getChildNodes();

    value = "";
    found = false;
    node = [];

    for iNode = 0:(childNodes.getLength()-1)

        child = childNodes.item(iNode);

        if child.getNodeType() ~= 1
            continue;
        end

        if strcmp(char(child.getNodeName()), char(childName))

            assert(~found, ...
                "ForceCapacity:DuplicateDirectChild", ...
                "Multiple direct <%s> children were found.", ...
                string(childName));

            value = strtrim(string(char(child.getTextContent())));
            found = true;
            node = child;
        end
    end
end


function firstElement = localFindFirstElementChild(parentNode)

    childNodes = parentNode.getChildNodes();
    firstElement = [];

    for iNode = 0:(childNodes.getLength()-1)

        child = childNodes.item(iNode);

        if child.getNodeType() == 1
            firstElement = child;
            return;
        end
    end
end


function tf = localParseBoolean(textValue)

    textValue = lower(strtrim(string(textValue)));

    if textValue == "true" || textValue == "1"
        tf = true;
    elseif textValue == "false" || textValue == "0"
        tf = false;
    else
        error( ...
            "ForceCapacity:InvalidBoolean", ...
            "Could not parse boolean value '%s'.", ...
            textValue);
    end
end


function textValue = localBooleanText(tf)

    if tf
        textValue = "true";
    else
        textValue = "false";
    end
end


function localWriteXml(document, outputFile)

    if exist("xmlwrite", "file") == 2
        xmlwrite(char(outputFile), document);
        return;
    end

    factory = ...
        javax.xml.transform.TransformerFactory.newInstance();

    transformer = factory.newTransformer();

    source = ...
        javax.xml.transform.dom.DOMSource(document);

    output = ...
        javax.xml.transform.stream.StreamResult( ...
            java.io.File(char(outputFile)));

    transformer.transform(source, output);
end
