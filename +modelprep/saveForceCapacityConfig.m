function result = saveForceCapacityConfig( ...
        modelFile, capacityTable, configFile, varargin)
%SAVEFORCECAPACITYCONFIG Save reusable ForceSet edits as JSON.
%
% result = modelprep.saveForceCapacityConfig( ...
%     modelFile, capacityTable, configFile)
%
% capacityTable is normally the master table from
% modelprep.interactiveForceCapacityEditor / inspectForceCapacities.
%
% By default, only rows whose capacity value and/or appliesForce state has
% changed are written to the configuration.
%
% Each capacity edit stores BOTH:
%   TargetValue  - exact desired value selected in the base model
%   ScaleFactor  - TargetValue / ReferenceValue
%
% This lets the same config later be applied using either:
%   "target" -> reproduce the exact configured value
%   "scale"  -> apply the same relative scaling to the target model
%
% NAME-VALUE OPTIONS
%   DefaultApplyMode
%       "target" (default) or "scale"
%
%   IncludeSelectedUnchanged
%       Also serialize currently selected rows even if unchanged.
%       Default false.
%
%   Description
%       Optional human-readable description.
%
% OUTPUT JSON SCHEMA
%   Schema
%   Version
%   CreatedAt
%   Description
%   SourceModel
%   DefaultApplyMode
%   EntryCount
%   Entries

    parser = inputParser;
    parser.FunctionName = ...
        "modelprep.saveForceCapacityConfig";

    addRequired(parser, "modelFile", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addRequired(parser, "capacityTable", @istable);

    addRequired(parser, "configFile", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "DefaultApplyMode", "target", ...
        @(x) any(strcmpi(string(x), ["target","scale"])));

    addParameter(parser, "IncludeSelectedUnchanged", false, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "Description", "", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    parse(parser, modelFile, capacityTable, configFile, varargin{:});

    modelFile = string(parser.Results.modelFile);
    configFile = string(parser.Results.configFile);
    defaultApplyMode = lower(string(parser.Results.DefaultApplyMode));
    includeSelectedUnchanged = ...
        parser.Results.IncludeSelectedUnchanged;
    description = string(parser.Results.Description);

    assert(isfile(modelFile), ...
        "ForceCapacityConfig:ModelMissing", ...
        "Source model was not found:\n%s", modelFile);

    requiredColumns = [ ...
        "Select"
        "Name"
        "ObjectType"
        "Category"
        "Group"
        "AppliesForce"
        "ProposedAppliesForce"
        "CapacityParameter"
        "CurrentValue"
        "ProposedValue"
        "UnitNote"
        "HasScalarCapacity"
    ];

    assert(all(ismember( ...
        requiredColumns, ...
        string(capacityTable.Properties.VariableNames))), ...
        "ForceCapacityConfig:TableColumnsMissing", ...
        "capacityTable is missing one or more required columns.");

    [configFolder,~,extension] = fileparts(configFile);

    assert(strcmpi(extension, ".json"), ...
        "ForceCapacityConfig:InvalidExtension", ...
        "Force-capacity configuration must use the .json extension.");

    if strlength(string(configFolder)) > 0 && ...
            ~isfolder(configFolder)
        mkdir(configFolder);
    end

    valueChanged = ...
        capacityTable.HasScalarCapacity & ...
        abs(capacityTable.ProposedValue - ...
            capacityTable.CurrentValue) > ...
        max(1e-12, ...
            1e-10 .* abs(capacityTable.CurrentValue));

    enabledChanged = ...
        capacityTable.ProposedAppliesForce ~= ...
        capacityTable.AppliesForce;

    includeMask = ...
        valueChanged | enabledChanged;

    if includeSelectedUnchanged
        includeMask = ...
            includeMask | logical(capacityTable.Select);
    end

    assert(any(includeMask), ...
        "ForceCapacityConfig:NoEntries", ...
        ["No changed ForceSet rows were found. Preview a capacity change " ...
         "or change appliesForce before saving a configuration."]);

    rows = capacityTable(includeMask, :);

    entries = repmat(struct( ...
        "Name", "", ...
        "ObjectType", "", ...
        "Category", "", ...
        "Group", "", ...
        "CapacityParameter", "", ...
        "CapacityAction", "preserve", ...
        "ReferenceValue", [], ...
        "TargetValue", [], ...
        "ScaleFactor", [], ...
        "UnitNote", "", ...
        "AppliesForceAction", "preserve", ...
        "ReferenceAppliesForce", true, ...
        "TargetAppliesForce", true), ...
        height(rows), 1);

    for iRow = 1:height(rows)

        capacityChanged = ...
            rows.HasScalarCapacity(iRow) && ...
            abs(rows.ProposedValue(iRow) - rows.CurrentValue(iRow)) > ...
            max(1e-12, ...
                1e-10 * abs(rows.CurrentValue(iRow)));

        appliesChanged = ...
            rows.ProposedAppliesForce(iRow) ~= ...
            rows.AppliesForce(iRow);

        entries(iRow).Name = char(rows.Name(iRow));
        entries(iRow).ObjectType = char(rows.ObjectType(iRow));
        entries(iRow).Category = char(rows.Category(iRow));
        entries(iRow).Group = char(rows.Group(iRow));
        entries(iRow).CapacityParameter = ...
            char(rows.CapacityParameter(iRow));
        entries(iRow).UnitNote = char(rows.UnitNote(iRow));

        if capacityChanged || includeSelectedUnchanged && ...
                rows.HasScalarCapacity(iRow)

            entries(iRow).CapacityAction = "set";
            entries(iRow).ReferenceValue = ...
                double(rows.CurrentValue(iRow));
            entries(iRow).TargetValue = ...
                double(rows.ProposedValue(iRow));

            assert(isfinite(entries(iRow).ReferenceValue) && ...
                   entries(iRow).ReferenceValue > 0, ...
                "ForceCapacityConfig:InvalidReferenceValue", ...
                "Reference capacity for '%s' is invalid.", ...
                rows.Name(iRow));

            entries(iRow).ScaleFactor = ...
                entries(iRow).TargetValue / ...
                entries(iRow).ReferenceValue;
        end

        entries(iRow).ReferenceAppliesForce = ...
            logical(rows.AppliesForce(iRow));
        entries(iRow).TargetAppliesForce = ...
            logical(rows.ProposedAppliesForce(iRow));

        if appliesChanged || includeSelectedUnchanged
            entries(iRow).AppliesForceAction = "set";
        end
    end

    sourceInfo = dir(modelFile);

    sourceModel = struct;
    sourceModel.FileName = char(string(sourceInfo.name));
    sourceModel.FullPath = char(modelFile);
    sourceModel.Bytes = double(sourceInfo.bytes);
    sourceModel.Modified = char(string(sourceInfo.date));

    config = struct;
    config.Schema = "headneck-force-capacity-config";
    config.Version = 1;
    config.CreatedAt = char(string(datetime( ...
        "now", ...
        "Format", "yyyy-MM-dd'T'HH:mm:ss")));
    config.Description = char(description);
    config.SourceModel = sourceModel;
    config.DefaultApplyMode = char(defaultApplyMode);
    config.EntryCount = numel(entries);
    config.Entries = entries;

    try
        jsonText = jsonencode( ...
            config, ...
            "PrettyPrint", true);
    catch
        jsonText = jsonencode(config);
    end

    fileId = fopen(configFile, "w");

    assert(fileId >= 0, ...
        "ForceCapacityConfig:OpenFailed", ...
        "Could not open config for writing:\n%s", ...
        configFile);

    cleanup = onCleanup(@() fclose(fileId));

    fwrite(fileId, jsonText, "char");

    clear cleanup

    assert(isfile(configFile), ...
        "ForceCapacityConfig:WriteFailed", ...
        "Configuration was not written:\n%s", ...
        configFile);

    % Re-read through the validator before returning.
    loaded = ...
        modelprep.loadForceCapacityConfig( ...
            configFile);

    result = struct;
    result.ConfigFile = configFile;
    result.Config = loaded.Config;
    result.EntryCount = loaded.Config.EntryCount;
end
