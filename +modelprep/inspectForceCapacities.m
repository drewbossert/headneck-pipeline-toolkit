function result = inspectForceCapacities(modelFile, varargin)
%INSPECTFORCECAPACITIES Inspect every direct object in an OpenSim ForceSet.
%
% result = modelprep.inspectForceCapacities(modelFile)
%
% Every direct child of <ForceSet><objects> becomes one row.
%
% IMPORTANT:
% OpenSim::Force defines appliesForce with a default value of true. Models
% may therefore omit <appliesForce> when the default applies. This function
% reports the effective state and also whether the tag was explicitly
% serialized in the XML.
%
% Primary scalar mappings:
%   *Muscle            -> max_isometric_force [N]
%   PointActuator      -> optimal_force [N]
%   TorqueActuator     -> optimal_force [N*m]
%   CoordinateActuator -> optimal_force [generalized force]
%
% Objects without one meaningful scalar capacity (for example BushingForce)
% are still listed and can have appliesForce toggled.
%
% Returned table columns:
%   Select
%   Name
%   ObjectType
%   Category
%   Group
%   AppliesForce
%   AppliesForceExplicit
%   ProposedAppliesForce
%   CapacityParameter
%   CurrentValue
%   ProposedValue
%   UnitNote
%   HasScalarCapacity

    parser = inputParser;
    parser.FunctionName = ...
        "modelprep.inspectForceCapacities";

    addRequired(parser, "modelFile", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "FlexionGroupName", "flexion", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "ExtensionGroupName", "extension", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    parse(parser, modelFile, varargin{:});

    modelFile = string(parser.Results.modelFile);

    assert(isfile(modelFile), ...
        "ForceCapacity:ModelMissing", ...
        "Model file was not found:\n%s", modelFile);

    %% Functional muscle groups.

    flexion = modelprep.getBilateralMuscleGroupMembers( ...
        modelFile, ...
        string(parser.Results.FlexionGroupName), ...
        "RequireBilateral", true);

    extension = modelprep.getBilateralMuscleGroupMembers( ...
        modelFile, ...
        string(parser.Results.ExtensionGroupName), ...
        "RequireBilateral", true);

    flexionNames = string(flexion.ResolvedMembers(:));
    extensionNames = string(extension.ResolvedMembers(:));

    overlap = intersect(flexionNames, extensionNames);

    assert(isempty(overlap), ...
        "ForceCapacity:MuscleGroupOverlap", ...
        "Muscles occur in both flexion and extension groups: %s", ...
        strjoin(overlap, ", "));

    %% Parse direct ForceSet objects.

    xmlData = opensimio.readXml(modelFile);
    document = xmlData.Document;

    forceSetNodes = document.getElementsByTagName("ForceSet");

    assert(forceSetNodes.getLength() == 1, ...
        "ForceCapacity:ForceSetCount", ...
        "Expected exactly one <ForceSet>; found %d.", ...
        forceSetNodes.getLength());

    objectsNode = localGetUniqueDirectChild( ...
        forceSetNodes.item(0), "objects");

    childNodes = objectsNode.getChildNodes();

    names = strings(0,1);
    objectTypes = strings(0,1);
    categories = strings(0,1);
    groups = strings(0,1);
    appliesForce = false(0,1);
    appliesForceExplicit = false(0,1);
    capacityParameters = strings(0,1);
    currentValues = zeros(0,1);
    unitNotes = strings(0,1);
    hasScalarCapacity = false(0,1);

    for iNode = 0:(childNodes.getLength()-1)

        objectNode = childNodes.item(iNode);

        if objectNode.getNodeType() ~= 1
            continue;
        end

        objectType = string(char(objectNode.getNodeName()));
        objectName = string(char(objectNode.getAttribute("name")));

        assert(strlength(objectName) > 0, ...
            "ForceCapacity:UnnamedForceObject", ...
            "A ForceSet object of type '%s' has no name.", ...
            objectType);

        [enabledText, enabledFound] = ...
            localGetOptionalDirectChildText( ...
                objectNode, "appliesForce");

        if enabledFound
            enabled = localParseBoolean(enabledText);
            enabledExplicit = true;
        else
            % OpenSim::Force::constructProperties():
            % constructProperty_appliesForce(true)
            enabled = true;
            enabledExplicit = false;
        end

        [category, groupName] = ...
            localClassifyObject( ...
                objectType, ...
                objectName, ...
                flexionNames, ...
                extensionNames);

        [parameterName, scalarValue, unitNote, adjustable] = ...
            localGetPrimaryCapacity( ...
                objectNode, objectType);

        names(end+1,1) = objectName; %#ok<AGROW>
        objectTypes(end+1,1) = objectType; %#ok<AGROW>
        categories(end+1,1) = category; %#ok<AGROW>
        groups(end+1,1) = groupName; %#ok<AGROW>
        appliesForce(end+1,1) = enabled; %#ok<AGROW>
        appliesForceExplicit(end+1,1) = enabledExplicit; %#ok<AGROW>
        capacityParameters(end+1,1) = parameterName; %#ok<AGROW>
        currentValues(end+1,1) = scalarValue; %#ok<AGROW>
        unitNotes(end+1,1) = unitNote; %#ok<AGROW>
        hasScalarCapacity(end+1,1) = adjustable; %#ok<AGROW>
    end

    assert(~isempty(names), ...
        "ForceCapacity:EmptyForceSet", ...
        "No direct objects were found under ForceSet/objects.");

    capacities = table( ...
        false(numel(names),1), ...
        names, ...
        objectTypes, ...
        categories, ...
        groups, ...
        appliesForce, ...
        appliesForceExplicit, ...
        appliesForce, ...
        capacityParameters, ...
        currentValues, ...
        currentValues, ...
        unitNotes, ...
        hasScalarCapacity, ...
        'VariableNames', { ...
            'Select', ...
            'Name', ...
            'ObjectType', ...
            'Category', ...
            'Group', ...
            'AppliesForce', ...
            'AppliesForceExplicit', ...
            'ProposedAppliesForce', ...
            'CapacityParameter', ...
            'CurrentValue', ...
            'ProposedValue', ...
            'UnitNote', ...
            'HasScalarCapacity'});

    summary = groupsummary( ...
        capacities, ...
        ["ObjectType","Category","Group","AppliesForce"]);

    result = struct;
    result.ModelFile = modelFile;
    result.Capacities = capacities;
    result.Summary = summary;
    result.Flexion = flexion;
    result.Extension = extension;
end


function [category, groupName] = localClassifyObject( ...
        objectType, objectName, flexionNames, extensionNames)

    lowerType = lower(objectType);

    if endsWith(lowerType, "muscle")

        category = "Muscle";

        if ismember(objectName, flexionNames)
            groupName = "Flexion";
        elseif ismember(objectName, extensionNames)
            groupName = "Extension";
        else
            groupName = "Excluded/other";
        end

    elseif contains(lowerType, "actuator")

        category = "Actuator";

        if strcmpi(objectType, "TorqueActuator")
            groupName = "Torque actuator";
        elseif strcmpi(objectType, "PointActuator")
            groupName = "Point actuator";
        elseif strcmpi(objectType, "CoordinateActuator")
            groupName = "Coordinate actuator";
        else
            groupName = "Other actuator";
        end

    elseif contains(lowerType, "bushing")

        category = "Passive force";
        groupName = "Bushing";

    else

        category = "Other force";
        groupName = objectType;
    end
end


function [parameterName, value, unitNote, adjustable] = ...
        localGetPrimaryCapacity(objectNode, objectType)

    parameterName = "";
    value = NaN;
    unitNote = "";
    adjustable = false;

    lowerType = lower(objectType);

    if endsWith(lowerType, "muscle")

        [textValue, found] = ...
            localGetOptionalDirectChildText( ...
                objectNode, "max_isometric_force");

        if found
            parameterName = "max_isometric_force";
            value = str2double(textValue);
            unitNote = "N";
            adjustable = isfinite(value);
        end

        return;
    end

    if contains(lowerType, "actuator")

        [textValue, found] = ...
            localGetOptionalDirectChildText( ...
                objectNode, "optimal_force");

        if found
            parameterName = "optimal_force";
            value = str2double(textValue);

            if strcmpi(objectType, "TorqueActuator")
                unitNote = "N*m";
            elseif strcmpi(objectType, "PointActuator")
                unitNote = "N";
            else
                unitNote = "generalized force";
            end

            adjustable = isfinite(value);
        end

        return;
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


function node = localGetUniqueDirectChild(parentNode, childName)

    childNodes = parentNode.getChildNodes();
    matches = cell(0,1);

    for iNode = 0:(childNodes.getLength()-1)

        child = childNodes.item(iNode);

        if child.getNodeType() ~= 1
            continue;
        end

        if strcmp(char(child.getNodeName()), char(childName))
            matches{end+1,1} = child; %#ok<AGROW>
        end
    end

    assert(numel(matches) == 1, ...
        "ForceCapacity:DirectChildCount", ...
        "Expected exactly one direct <%s> child; found %d.", ...
        string(childName), ...
        numel(matches));

    node = matches{1};
end


function [value, found] = ...
        localGetOptionalDirectChildText(parentNode, childName)

    childNodes = parentNode.getChildNodes();

    value = "";
    found = false;

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
        end
    end
end
