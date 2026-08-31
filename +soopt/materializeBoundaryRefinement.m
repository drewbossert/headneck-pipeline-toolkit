function selection = materializeBoundaryRefinement(projectCfg, proposals, varargin)
%MATERIALIZEBOUNDARYREFINEMENT Materialize a ranked adaptive proposal.
%
% Selects one ranked row from soopt.proposeBoundaryRefinement and creates
% or reuses its canonical JSON through soopt.writeStrengthConfiguration.

    parser = inputParser;
    parser.FunctionName = "soopt.materializeBoundaryRefinement";

    addRequired(parser, "projectCfg", @(x) isstruct(x) && isscalar(x));
    addRequired(parser, "proposals", @istable);

    addParameter(parser, "ProposalRank", 1, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && ...
        x >= 1 && x == fix(x));

    addParameter(parser, "TemplateConfigFile", "", ...
        @(x) (ischar(x) && (isrow(x) || isempty(x))) || ...
        (isstring(x) && isscalar(x) && ~ismissing(x)));

    addParameter(parser, "ConfigDirectory", "", ...
        @(x) (ischar(x) && (isrow(x) || isempty(x))) || ...
        (isstring(x) && isscalar(x) && ~ismissing(x)));

    addParameter(parser, "ReuseExisting", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, projectCfg, proposals, varargin{:});

    requestedRank = double(parser.Results.ProposalRank);
    templateConfigFile = string(parser.Results.TemplateConfigFile);
    configDirectory = string(parser.Results.ConfigDirectory);
    reuseExisting = logical(parser.Results.ReuseExisting);

    requiredVariables = [
        "PriorityRank"
        "ConfigId"
        "MusclePercent"
        "ActuatorPercent"
    ];

    missingVariables = requiredVariables( ...
        ~ismember(requiredVariables, string(proposals.Properties.VariableNames)));

    assert(isempty(missingVariables), ...
        "StrengthBoundaryMaterialize:VariablesMissing", ...
        "proposals is missing required variables: %s", ...
        strjoin(missingVariables, ", "));

    if isempty(proposals)
        error( ...
            "StrengthBoundaryMaterialize:NoProposals", ...
            "No adaptive boundary proposals are available to materialize.");
    end

    priorityRank = double(proposals.PriorityRank);

    assert(all(isfinite(priorityRank) & priorityRank >= 1 & ...
            priorityRank == fix(priorityRank)), ...
        "StrengthBoundaryMaterialize:InvalidPriorityRank", ...
        "Proposal PriorityRank values must be positive integers.");

    assert(numel(unique(priorityRank)) == height(proposals), ...
        "StrengthBoundaryMaterialize:DuplicatePriorityRank", ...
        "Proposal PriorityRank values must be unique.");

    proposalMask = priorityRank == requestedRank;

    if ~any(proposalMask)
        error( ...
            "StrengthBoundaryMaterialize:ProposalRankNotFound", ...
            "Adaptive boundary proposal rank %d is not available.", ...
            requestedRank);
    end

    proposalRowIndex = find(proposalMask, 1);
    proposal = proposals(proposalRowIndex, :);

    configId = string(proposal.ConfigId);
    musclePercent = double(proposal.MusclePercent);
    actuatorPercent = double(proposal.ActuatorPercent);

    assert(isscalar(configId) && ~ismissing(configId) && ...
            strlength(configId) > 0, ...
        "StrengthBoundaryMaterialize:InvalidConfigId", ...
        "The selected adaptive proposal has an invalid ConfigId.");

    assert(isscalar(musclePercent) && isfinite(musclePercent) && ...
            musclePercent > 0 && musclePercent == fix(musclePercent), ...
        "StrengthBoundaryMaterialize:InvalidCoordinate", ...
        "The selected adaptive proposal has an invalid MusclePercent.");

    assert(isscalar(actuatorPercent) && isfinite(actuatorPercent) && ...
            actuatorPercent > 0 && actuatorPercent == fix(actuatorPercent), ...
        "StrengthBoundaryMaterialize:InvalidCoordinate", ...
        "The selected adaptive proposal has an invalid ActuatorPercent.");

    proposalFileName = ...
        configId + ...
        ".json";
    
    parsedIdentity = pipeline.parseStrengthConfigName(proposalFileName);

    if parsedIdentity.ConfigId ~= configId || ...
            parsedIdentity.MusclePercent ~= musclePercent || ...
            parsedIdentity.ActuatorPercent ~= actuatorPercent

        error( ...
            "StrengthBoundaryMaterialize:ProposalIdentityMismatch", ...
            "Adaptive proposal %s reports coordinates (%g, %g), but " + ...
            "its canonical ConfigId represents (%g, %g).", ...
            configId, musclePercent, actuatorPercent, ...
            parsedIdentity.MusclePercent, parsedIdentity.ActuatorPercent);
    end

    writerArguments = {"ReuseExisting", reuseExisting};

    if strlength(templateConfigFile) > 0
        writerArguments(end+1:end+2) = { ...
            "TemplateConfigFile", templateConfigFile};
    end

    if strlength(configDirectory) > 0
        writerArguments(end+1:end+2) = { ...
            "ConfigDirectory", configDirectory};
    end

    writeResult = soopt.writeStrengthConfiguration( ...
        projectCfg, musclePercent, actuatorPercent, writerArguments{:});

    if writeResult.ConfigId ~= configId || ...
            writeResult.MusclePercent ~= musclePercent || ...
            writeResult.ActuatorPercent ~= actuatorPercent

        error( ...
            "StrengthBoundaryMaterialize:WriteResultMismatch", ...
            "Materialized configuration identity does not match the " + ...
            "selected adaptive proposal %s.", ...
            configId);
    end

    assert(isfile(writeResult.ConfigFile), ...
        "StrengthBoundaryMaterialize:ConfigFileMissing", ...
        "Materialized strength configuration was not found:\n%s", ...
        writeResult.ConfigFile);

    existingIncomplete = false;
    if ismember("ExistingIncomplete", string(proposal.Properties.VariableNames))
        existingIncomplete = logical(proposal.ExistingIncomplete);
    end

    existingConfigId = "";
    if ismember("ExistingConfigId", string(proposal.Properties.VariableNames))
        existingConfigId = string(proposal.ExistingConfigId);
    end

    incrementPercent = NaN;
    if ismember("IncrementPercent", string(proposal.Properties.VariableNames))
        incrementPercent = double(proposal.IncrementPercent);
    end

    selection = struct;
    selection.SchemaVersion = 1;
    selection.PriorityRank = requestedRank;
    selection.ConfigId = configId;
    selection.MusclePercent = musclePercent;
    selection.ActuatorPercent = actuatorPercent;
    selection.ExistingIncomplete = existingIncomplete;
    selection.ExistingConfigId = existingConfigId;
    selection.IncrementPercent = incrementPercent;
    selection.FileName = writeResult.FileName;
    selection.ConfigFile = writeResult.ConfigFile;
    selection.ConfigDirectory = writeResult.ConfigDirectory;
    selection.Created = writeResult.Created;
    selection.ReusedExisting = writeResult.ReusedExisting;
    selection.ProposalRowIndex = proposalRowIndex;
    selection.Proposal = proposal;
    selection.WriteResult = writeResult;
end
