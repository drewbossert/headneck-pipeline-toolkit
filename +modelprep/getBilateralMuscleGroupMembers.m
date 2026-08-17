function result = getBilateralMuscleGroupMembers(modelFile, groupName, varargin)
%GETBILATERALMUSCLEGROUPMEMBERS Resolve an OpenSim ObjectGroup bilaterally.
%
% result = modelprep.getBilateralMuscleGroupMembers(modelFile, groupName)
%
% Reads <ObjectGroup name="..."> from the .osim XML. The listed members
% are treated as authoritative. If only one lateral side is listed, the
% function expands each source member to its contralateral counterpart by
% comparing side-neutral names against the actual model muscle set.
%
% Name-value options:
%   RequireBilateral       true
%   ExpectedResolvedCount  []
%
% This is intentionally conservative: unrelated muscles are never added
% simply because they are absent from another functional group.

    parser = inputParser;
    parser.FunctionName = "modelprep.getBilateralMuscleGroupMembers";

    addRequired(parser, "modelFile", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addRequired(parser, "groupName", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, "RequireBilateral", true, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, "ExpectedResolvedCount", [], ...
        @(x) isempty(x) || (isnumeric(x) && isscalar(x) && ...
        isfinite(x) && x >= 0 && mod(x,1) == 0));

    parse(parser, modelFile, groupName, varargin{:});

    modelFile = string(parser.Results.modelFile);
    groupName = string(parser.Results.groupName);

    assert(isfile(modelFile), ...
        "ModelMuscleGroup:ModelMissing", ...
        "Model file was not found:\n%s", modelFile);

    %% Actual model muscle names
    import org.opensim.modeling.*

    model = Model(char(modelFile));
    model.finalizeConnections();

    muscleSet = model.getMuscles();
    numMuscles = muscleSet.getSize();
    modelMuscleNames = strings(numMuscles,1);

    for iMuscle = 0:(numMuscles-1)
        modelMuscleNames(iMuscle+1) = ...
            string(char(muscleSet.get(iMuscle).getName()));
    end

    assert(numMuscles > 0, ...
        "ModelMuscleGroup:NoMuscles", ...
        "The model contains no muscles.");

    %% Read ObjectGroup from XML
    xml = opensimio.readXml(modelFile);
    document = xml.Document;

    objectGroupNodes = document.getElementsByTagName("ObjectGroup");
    matchingIndices = [];

    for iNode = 0:(objectGroupNodes.getLength()-1)
        node = objectGroupNodes.item(iNode);
        thisName = string(char(node.getAttribute("name")));
        if strcmpi(thisName, groupName)
            matchingIndices(end+1) = iNode; %#ok<AGROW>
        end
    end

    assert(numel(matchingIndices) == 1, ...
        "ModelMuscleGroup:ObjectGroupLookupFailed", ...
        "Expected exactly one <ObjectGroup name=\'%s\'> " + ...
        "in:\n%s\nFound %d.", ...
        groupName, modelFile, numel(matchingIndices));

    groupNode = objectGroupNodes.item(matchingIndices(1));
    membersNodes = groupNode.getElementsByTagName("members");

    assert(membersNodes.getLength() == 1, ...
        "ModelMuscleGroup:MembersLookupFailed", ...
        "Expected exactly one <members> element inside ObjectGroup " + ...
        "'%s'; found %d.", ...
        groupName, membersNodes.getLength());

    membersText = strtrim(string(char( ...
        membersNodes.item(0).getTextContent())));

    assert(strlength(membersText) > 0, ...
        "ModelMuscleGroup:EmptyGroup", ...
        "ObjectGroup '%s' contains no members.", groupName);

    % OpenSim members are normally whitespace-delimited. Accept commas and
    % semicolons defensively as well.
    membersText = replace(membersText, [",", ";"], " ");
    sourceMembers = split(membersText);
    sourceMembers = strip(sourceMembers);
    sourceMembers(sourceMembers == "") = [];
    sourceMembers = unique(sourceMembers, "stable");

    %% Build side-neutral keys for all model muscles
    modelCanonical = strings(numMuscles,1);
    for iMuscle = 1:numMuscles
        modelCanonical(iMuscle) = ...
            localCanonicalSideNeutralName(modelMuscleNames(iMuscle));
    end

    resolvedMembers = strings(0,1);
    auditSource = strings(0,1);
    auditCanonical = strings(0,1);
    auditResolved = strings(0,1);
    auditIsSource = false(0,1);
    auditIsContralateral = false(0,1);

    for iMember = 1:numel(sourceMembers)
        sourceMember = sourceMembers(iMember);

        exactMatch = find(modelMuscleNames == sourceMember);
        assert(numel(exactMatch) == 1, ...
            "ModelMuscleGroup:SourceMemberMissing", ...
            "ObjectGroup '%s' lists '%s', but that muscle was not " + ...
            "found uniquely in the model muscle set.", ...
            groupName, sourceMember);

        canonicalKey = localCanonicalSideNeutralName(sourceMember);
        bilateralMatches = find(modelCanonical == canonicalKey);

        assert(~isempty(bilateralMatches), ...
            "ModelMuscleGroup:NoCanonicalMatches", ...
            "No model muscles matched canonical key '%s'.", canonicalKey);

        if numel(bilateralMatches) > 2
            error("ModelMuscleGroup:AmbiguousBilateralMatch", ...
                "Source member '%s' resolved to %d muscles after " + ...
                "side-neutral matching:\n%s", ...
                sourceMember, numel(bilateralMatches), ...
                strjoin(modelMuscleNames(bilateralMatches), ", "));
        end

        if parser.Results.RequireBilateral && localLooksSided(sourceMember)
            assert(numel(bilateralMatches) == 2, ...
                "ModelMuscleGroup:ContralateralMissing", ...
                "Source member '%s' appears sided but did not resolve " + ...
                "to exactly two bilateral model muscles. Matches: %s", ...
                sourceMember, ...
                strjoin(modelMuscleNames(bilateralMatches), ", "));
        end

        for iMatch = reshape(bilateralMatches, 1, [])
            resolvedName = modelMuscleNames(iMatch);

            resolvedMembers(end+1,1) = resolvedName; %#ok<AGROW>
            auditSource(end+1,1) = sourceMember; %#ok<AGROW>
            auditCanonical(end+1,1) = canonicalKey; %#ok<AGROW>
            auditResolved(end+1,1) = resolvedName; %#ok<AGROW>
            auditIsSource(end+1,1) = resolvedName == sourceMember; %#ok<AGROW>
            auditIsContralateral(end+1,1) = resolvedName ~= sourceMember; %#ok<AGROW>
        end
    end

    resolvedMembers = unique(resolvedMembers, "stable");

    expectedCount = parser.Results.ExpectedResolvedCount;
    if ~isempty(expectedCount)
        assert(numel(resolvedMembers) == expectedCount, ...
            "ModelMuscleGroup:UnexpectedResolvedCount", ...
            "ObjectGroup '%s' resolved to %d muscles; expected %d.", ...
            groupName, numel(resolvedMembers), expectedCount);
    end

    audit = table( ...
        auditSource, auditCanonical, auditResolved, ...
        auditIsSource, auditIsContralateral, ...
        'VariableNames', { ...
            'SourceMember', ...
            'CanonicalKey', ...
            'ResolvedMember', ...
            'IsSourceMember', ...
            'IsContralateralExpansion'});

    result = struct;
    result.GroupName = groupName;
    result.SourceMembers = sourceMembers;
    result.ResolvedMembers = resolvedMembers;
    result.Audit = audit;
    result.ModelMuscleNames = modelMuscleNames;
    result.ExcludedModelMuscles = setdiff( ...
        modelMuscleNames, resolvedMembers, "stable");
end


function key = localCanonicalSideNeutralName(name)
% Remove common right/left markers while retaining the anatomical name.

    key = lower(strtrim(string(name)));
    key = replace(key, [".", "-", " "], "_");

    key = regexprep(key, "(^|_)right(_|$)", "_");
    key = regexprep(key, "(^|_)left(_|$)", "_");

    key = regexprep(key, "^r_", "");
    key = regexprep(key, "^l_", "");
    key = regexprep(key, "_r$", "");
    key = regexprep(key, "_l$", "");

    key = regexprep(key, "right$", "");
    key = regexprep(key, "left$", "");

    key = regexprep(key, "_+", "_");
    key = regexprep(key, "^_|_$", "");
end


function tf = localLooksSided(name)

    value = lower(strtrim(string(name)));
    value = replace(value, [".", "-", " "], "_");

    tf = ...
        startsWith(value, "r_") || ...
        startsWith(value, "l_") || ...
        endsWith(value, "_r") || ...
        endsWith(value, "_l") || ...
        contains(value, "_right") || ...
        contains(value, "_left") || ...
        startsWith(value, "right_") || ...
        startsWith(value, "left_");
end
