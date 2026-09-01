function result = pruneStaticOptimizationArtifacts(projectCfg, varargin)
%PRUNESTATICOPTIMIZATIONARTIFACTS Explicit end-of-workflow SO pruning.
%
% result = pipeline.pruneStaticOptimizationArtifacts(projectCfg)
%
% Inventories known Static Optimization artifacts and applies the retention
% policy from projectCfg.storage. DryRun=true by default; deletion occurs
% only when DryRun=false is supplied explicitly.
%
% Options:
%   DryRun                true (default)
%   Conditions            projectCfg.conditions
%   Trials                projectCfg.trials
%   ConfigIds             empty -> discover all existing config folders
%   IncludeShared         true
%   IncludeConfigurations true
%   PrintProgress         true
%
% Unknown files are never deleted. They are reported in UnmanagedFiles.
%
% Returned Actions table:
%   Scope, ConfigId, ConditionDeg, TrialNumber, ArtifactType, File, Bytes,
%   PolicyKeep, EligibleForDeletion, Deleted, Failed, ErrorMessage

    assert(isstruct(projectCfg) && isscalar(projectCfg), ...
        "SOPrune:InvalidProjectConfig", ...
        "projectCfg must be a scalar struct.");

    required = ["outputRoot","conditions","trials"];
    missing = required(~isfield(projectCfg, cellstr(required)));

    assert(isempty(missing), ...
        "SOPrune:ProjectConfigFieldsMissing", ...
        "projectCfg is missing required fields: %s", ...
        strjoin(missing, ", "));

    parser = inputParser;
    parser.FunctionName = "pipeline.pruneStaticOptimizationArtifacts";

    addParameter(parser, "DryRun", true, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, "Conditions", projectCfg.conditions, ...
        @(x) isnumeric(x) && isvector(x) && all(isfinite(x)));
    addParameter(parser, "Trials", projectCfg.trials, ...
        @(x) isnumeric(x) && isvector(x) && all(isfinite(x)) && ...
        all(x >= 1) && all(mod(x,1) == 0));
    addParameter(parser, "ConfigIds", strings(0,1), ...
        @(x) ischar(x) || isstring(x) || iscellstr(x));
    addParameter(parser, "IncludeShared", true, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, "IncludeConfigurations", true, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, "PrintProgress", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, varargin{:});

    dryRun = logical(parser.Results.DryRun);
    conditions = unique(double(parser.Results.Conditions(:).'), "stable");
    trials = unique(double(parser.Results.Trials(:).'), "stable");
    configIds = string(parser.Results.ConfigIds(:));
    configIds = configIds(strlength(configIds) > 0);
    includeShared = logical(parser.Results.IncludeShared);
    includeConfigurations = logical(parser.Results.IncludeConfigurations);
    printProgress = logical(parser.Results.PrintProgress);

    outputRoot = string(projectCfg.outputRoot);
    policy = pipeline.resolveStorageRetentionPolicy(projectCfg);

    if includeConfigurations && isempty(configIds)
        configIds = localDiscoverConfigIds(outputRoot);
    end

    actions = localEmptyActions();
    unmanaged = localEmptyUnmanaged();

    if includeShared
        for conditionDeg = conditions
            for trialNumber = trials
                [a,u] = localInventoryShared( ...
                    outputRoot, conditionDeg, trialNumber, policy);
                actions = [actions; a]; %#ok<AGROW>
                unmanaged = [unmanaged; u]; %#ok<AGROW>
            end
        end
    end

    if includeConfigurations
        for iConfig = 1:numel(configIds)
            for conditionDeg = conditions
                for trialNumber = trials
                    [a,u] = localInventoryConfig( ...
                        outputRoot, configIds(iConfig), ...
                        conditionDeg, trialNumber, policy);
                    actions = [actions; a]; %#ok<AGROW>
                    unmanaged = [unmanaged; u]; %#ok<AGROW>
                end
            end
        end
    end

    if ~dryRun
        for i = 1:height(actions)
            if ~actions.EligibleForDeletion(i)
                continue;
            end

            try
                delete(actions.File(i));
                actions.Deleted(i) = ~isfile(actions.File(i));

                if ~actions.Deleted(i)
                    actions.Failed(i) = true;
                    actions.ErrorMessage(i) = ...
                        "delete requested but file remains";
                end
            catch exception
                actions.Failed(i) = true;
                actions.ErrorMessage(i) = string(exception.message);
            end
        end
    end

    result = struct;
    result.SchemaVersion = 1;
    result.DryRun = dryRun;
    result.Policy = policy;
    result.ConfigIds = configIds;
    result.Actions = actions;
    result.ManagedFileCount = height(actions);
    result.DeleteCandidateCount = nnz(actions.EligibleForDeletion);
    result.DeletedFileCount = nnz(actions.Deleted);
    result.DeleteFailureCount = nnz(actions.Failed);
    result.BytesEligible = sum( ...
        actions.Bytes(actions.EligibleForDeletion), "omitnan");
    result.BytesDeleted = sum(actions.Bytes(actions.Deleted), "omitnan");
    result.UnmanagedFiles = unmanaged;

    if printProgress
        if dryRun
            fprintf( ...
                "\nSO artifact pruning DRY RUN\n" + ...
                "Managed files: %d\n" + ...
                "Delete candidates: %d\n" + ...
                "Potential recovery: %.2f MB\n" + ...
                "Unmanaged files retained: %d\n", ...
                result.ManagedFileCount, ...
                result.DeleteCandidateCount, ...
                result.BytesEligible / 1024^2, ...
                height(unmanaged));
        else
            fprintf( ...
                "\nSO artifact pruning APPLIED\n" + ...
                "Deleted files: %d\n" + ...
                "Recovered: %.2f MB\n" + ...
                "Deletion failures: %d\n" + ...
                "Unmanaged files retained: %d\n", ...
                result.DeletedFileCount, ...
                result.BytesDeleted / 1024^2, ...
                result.DeleteFailureCount, ...
                height(unmanaged));
        end
    end
end


function ids = localDiscoverConfigIds(outputRoot)

    root = string(fullfile(outputRoot, "static_optimization_configs"));

    if ~isfolder(root)
        ids = strings(0,1);
        return;
    end

    listing = dir(root);
    names = string({listing.name}).';
    keep = [listing.isdir].' & ~ismember(names, [".",".."]);
    ids = names(keep);
end


function [actions, unmanaged] = ...
        localInventoryShared(outputRoot, conditionDeg, trialNumber, policy)

    conditionTag = string(sprintf("%02ddeg", round(conditionDeg)));
    trialTag = string(sprintf("trial%02d", trialNumber));
    stem = conditionTag + "_" + trialTag;

    root = string(fullfile( ...
        outputRoot, conditionTag, trialTag, ...
        "03_static_optimization_shared_prep"));

    actions = localEmptyActions();
    unmanaged = localEmptyUnmanaged();

    if ~isfolder(root)
        return;
    end

    files = localListFiles(root);

    for i = 1:numel(files)
        rel = localRelativePath(files(i), root);
        [managed,type,keep] = localClassifyShared(rel, stem, policy);

        if managed
            actions = localAddAction(actions, ...
                "shared_prep", "", conditionDeg, trialNumber, ...
                type, files(i), keep);
        else
            unmanaged = localAddUnmanaged(unmanaged, ...
                "shared_prep", "", conditionDeg, trialNumber, files(i));
        end
    end
end


function [managed,type,keep] = localClassifyShared(rel, stem, policy)

    rel = replace(rel, "\", "/");
    managed = true;
    type = "";
    keep = true;

    if rel == stem + "_modelC_static_optimization.osim"
        type = "shared_neutral_model_c";
        keep = policy.SharedStaticOptimizationPrep.KeepNeutralModelC;

    elseif rel == "body_kinematics/" + ...
            stem + "_body_kinematics_setup.xml" || ...
            startsWith(rel, "body_kinematics/results/")
        type = "shared_body_kinematics";
        keep = policy.SharedStaticOptimizationPrep.KeepBodyKinematics;

    elseif any(rel == [ ...
            "body_kinematics/qc/skull_com_raw.csv"
            "body_kinematics/qc/skull_com_resampled.csv"
            "body_kinematics/qc/skull_com_summary.csv"])
        type = "shared_com_csv";
        keep = policy.SharedStaticOptimizationPrep.KeepComCsv;

    elseif rel == ...
            "head_support_force/qc/contact_event_detection_summary.csv"
        type = "shared_event_timing";
        keep = policy.SharedStaticOptimizationPrep.KeepEventTiming;

    elseif rel == "head_support_force/" + stem + "_head_support_force.mot"
        type = "shared_hsf_motion";
        keep = policy.SharedStaticOptimizationPrep.KeepHsfMotion;

    elseif rel == "head_support_force/" + stem + "_external_loads.xml"
        type = "shared_external_loads_xml";
        keep = policy.SharedStaticOptimizationPrep.KeepExternalLoadsXml;

    elseif rel == "qc/model_c_checkpoint.mat"
        type = "shared_checkpoint";
        keep = policy.SharedStaticOptimizationPrep.KeepCheckpoint;

    elseif startsWith(rel, "qc/") || ...
            startsWith(rel, "body_kinematics/qc/") || ...
            startsWith(rel, "head_support_force/qc/")
        type = "shared_qc";
        keep = policy.SharedStaticOptimizationPrep.KeepQc;

    else
        managed = false;
    end
end


function [actions, unmanaged] = ...
        localInventoryConfig( ...
            outputRoot, configId, conditionDeg, trialNumber, policy)

    conditionTag = string(sprintf("%02ddeg", round(conditionDeg)));
    trialTag = string(sprintf("trial%02d", trialNumber));
    stem = conditionTag + "_" + trialTag;

    root = string(fullfile( ...
        outputRoot, "static_optimization_configs", configId, ...
        conditionTag, trialTag));

    actions = localEmptyActions();
    unmanaged = localEmptyUnmanaged();

    if ~isfolder(root)
        return;
    end

    files = localListFiles(root);

    for i = 1:numel(files)
        rel = localRelativePath(files(i), root);
        [managed,type,keep] = localClassifyConfig(rel, stem, policy);

        if managed
            actions = localAddAction(actions, ...
                "configuration", configId, conditionDeg, trialNumber, ...
                type, files(i), keep);
        else
            unmanaged = localAddUnmanaged(unmanaged, ...
                "configuration", configId, conditionDeg, trialNumber, files(i));
        end
    end
end


function [managed,type,keep] = localClassifyConfig(rel, stem, policy)

    rel = replace(rel, "\", "/");
    p3 = "03_static_optimization_prep/";
    p4 = "04_static_optimization/";

    managed = true;
    type = "";
    keep = true;

    if rel == p3 + stem + "_modelC_static_optimization.osim"
        type = "configured_model_c";
        keep = policy.StaticOptimizationPrep.KeepConfiguredModelC;

    elseif rel == p3 + "qc/model_c_checkpoint.mat"
        type = "configuration_prep_checkpoint";
        keep = policy.StaticOptimizationPrep.KeepCheckpoint;

    elseif startsWith(rel, p3 + "qc/")
        type = "configuration_prep_qc";
        keep = policy.StaticOptimizationPrep.KeepQc;

    elseif rel == p4 + stem + "_so_setup.xml"
        type = "static_optimization_setup_xml";
        keep = policy.StaticOptimization.KeepSetupXml;

    elseif startsWith(rel, p4 + "results/") && ...
            endsWith(rel, "StaticOptimization_force.sto")
        type = "static_optimization_force_sto";
        keep = policy.StaticOptimization.KeepForceSto;

    elseif startsWith(rel, p4 + "results/") && ...
            endsWith(rel, "StaticOptimization_activation.sto")
        type = "static_optimization_activation_sto";
        keep = policy.StaticOptimization.KeepActivationSto;

    elseif startsWith(rel, p4 + "results/") && ...
            endsWith(rel, "StaticOptimization_controls.xml")
        type = "static_optimization_controls_xml";
        keep = policy.StaticOptimization.KeepControlsXml;

    elseif rel == p4 + "qc/static_optimization_run_checkpoint.mat"
        type = "static_optimization_checkpoint";
        keep = policy.StaticOptimization.KeepCheckpoint;

    elseif startsWith(rel, p4 + "qc/")
        type = "static_optimization_qc";
        keep = policy.StaticOptimization.KeepQc;

    else
        managed = false;
    end
end


function files = localListFiles(root)

    listing = dir(fullfile(root, "**", "*"));
    listing = listing(~[listing.isdir]);

    files = strings(numel(listing),1);

    for i = 1:numel(listing)
        files(i) = string(fullfile(listing(i).folder, listing(i).name));
    end
end


function rel = localRelativePath(filePath, root)

    prefix = string(root) + filesep;
    rel = extractAfter(string(filePath), strlength(prefix));
end


function actions = localAddAction( ...
        actions, scope, configId, conditionDeg, trialNumber, ...
        artifactType, filePath, keep)

    info = dir(filePath);

    assert(~isempty(info), ...
        "SOPrune:ManagedFileMissing", ...
        "Managed artifact was not found while building prune inventory:\n%s", ...
        string(filePath));

    newRow = ...
        height(actions) + 1;

    actions.Scope(newRow,1) = ...
        string(scope);

    actions.ConfigId(newRow,1) = ...
        string(configId);

    actions.ConditionDeg(newRow,1) = ...
        double(conditionDeg);

    actions.TrialNumber(newRow,1) = ...
        double(trialNumber);

    actions.ArtifactType(newRow,1) = ...
        string(artifactType);

    actions.File(newRow,1) = ...
        string(filePath);

    actions.Bytes(newRow,1) = ...
        double(info(1).bytes);

    actions.PolicyKeep(newRow,1) = ...
        logical(keep);

    actions.EligibleForDeletion(newRow,1) = ...
        ~logical(keep);

    actions.Deleted(newRow,1) = ...
        false;

    actions.Failed(newRow,1) = ...
        false;

    actions.ErrorMessage(newRow,1) = ...
        "";
end


function unmanaged = localAddUnmanaged( ...
        unmanaged, scope, configId, conditionDeg, trialNumber, filePath)

    info = dir(filePath);

    assert(~isempty(info), ...
        "SOPrune:UnmanagedFileMissing", ...
        "Unmanaged artifact was not found while building prune inventory:\n%s", ...
        string(filePath));

    newRow = height(unmanaged) + 1;

    unmanaged.Scope(newRow,1) = ...
        string(scope);

    unmanaged.ConfigId(newRow,1) = ...
        string(configId);

    unmanaged.ConditionDeg(newRow,1) = ...
        double(conditionDeg);

    unmanaged.TrialNumber(newRow,1) = ...
        double(trialNumber);

    unmanaged.File(newRow,1) = ...
        string(filePath);

    unmanaged.Bytes(newRow,1) = ...
        double(info(1).bytes);
end


function actions = localEmptyActions()

    variableNames = { ...
        'Scope', ...
        'ConfigId', ...
        'ConditionDeg', ...
        'TrialNumber', ...
        'ArtifactType', ...
        'File', ...
        'Bytes', ...
        'PolicyKeep', ...
        'EligibleForDeletion', ...
        'Deleted', ...
        'Failed', ...
        'ErrorMessage' ...
    };

    variableTypes = { ...
        'string', ...
        'string', ...
        'double', ...
        'double', ...
        'string', ...
        'string', ...
        'double', ...
        'logical', ...
        'logical', ...
        'logical', ...
        'logical', ...
        'string' ...
    };

    actions = table( ...
        'Size', [0 numel(variableNames)], ...
        'VariableTypes', variableTypes, ...
        'VariableNames', variableNames);
end


function unmanaged = localEmptyUnmanaged()

    variableNames = { ...
        'Scope', ...
        'ConfigId', ...
        'ConditionDeg', ...
        'TrialNumber', ...
        'File', ...
        'Bytes' ...
    };

    variableTypes = { ...
        'string', ...
        'string', ...
        'double', ...
        'double', ...
        'string', ...
        'double' ...
    };

    unmanaged = table( ...
        'Size', [0 numel(variableNames)], ...
        'VariableTypes', variableTypes, ...
        'VariableNames', variableNames);
end
