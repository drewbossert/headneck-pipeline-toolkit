function result = applyConfiguredForceCapacitiesIfEnabled( ...
        modelFile, projectCfg, varargin)
%APPLYCONFIGUREDFORCECAPACITIESIFENABLED Optional pipeline ForceSet hook.
%
% result = modelprep.applyConfiguredForceCapacitiesIfEnabled( ...
%     modelFile, projectCfg)
%
% Expected project configuration:
%
%   projectCfg.forceCapacity.enabled = false;
%   projectCfg.forceCapacity.configFile = "";
%   projectCfg.forceCapacity.applyMode = "target";
%   projectCfg.forceCapacity.requireAllEntries = true;
%
% When disabled, the function returns without modifying the model.
%
% When enabled, the saved JSON configuration is applied IN PLACE to the
% newly generated pipeline model and verified. An audit CSV is written
% beside the model unless AuditFile is supplied.
%
% For pipeline use, "target" is recommended over "scale" because target
% application is idempotent: accidentally applying the same config twice
% produces the same configured values instead of scaling twice.
%
% NAME-VALUE OPTIONS
%   StageName
%       Optional label returned in the result.
%
%   AuditFile
%       Optional explicit audit CSV path.

    parser = inputParser;
    parser.FunctionName = ...
        "modelprep.applyConfiguredForceCapacitiesIfEnabled";

    addRequired(parser, "modelFile", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addRequired(parser, "projectCfg", @isstruct);

    addParameter(parser, "StageName", "", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "AuditFile", "", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    parse(parser, modelFile, projectCfg, varargin{:});

    modelFile = string(parser.Results.modelFile);
    stageName = string(parser.Results.StageName);
    auditFile = string(parser.Results.AuditFile);

    assert(isfile(modelFile), ...
        "ForceCapacityPipeline:ModelMissing", ...
        "Generated model was not found:\n%s", ...
        modelFile);

    result = struct;
    result.ModelFile = modelFile;
    result.StageName = stageName;
    result.Enabled = false;
    result.Applied = false;
    result.ConfigFile = "";
    result.ApplyMode = "";
    result.AuditFile = "";
    result.VerificationPassed = true;
    result.ApplicationResult = [];

    if ~isfield(projectCfg, "forceCapacity")
        return;
    end

    cfg = projectCfg.forceCapacity;

    if ~isfield(cfg, "enabled") || ...
            ~logical(cfg.enabled)
        return;
    end

    result.Enabled = true;

    assert(isfield(cfg, "configFile"), ...
        "ForceCapacityPipeline:ConfigFileMissing", ...
        ["projectCfg.forceCapacity.enabled is true, but " ...
         "configFile is not defined."]);

    configFile = string(cfg.configFile);

    assert(strlength(configFile) > 0 && isfile(configFile), ...
        "ForceCapacityPipeline:ConfigNotFound", ...
        "Force-capacity config was not found:\n%s", ...
        configFile);

    if isfield(cfg, "applyMode")
        applyMode = lower(string(cfg.applyMode));
    else
        applyMode = "target";
    end

    assert(any(applyMode == ["target","scale","default"]), ...
        "ForceCapacityPipeline:InvalidApplyMode", ...
        "forceCapacity.applyMode must be target, scale, or default.");

    if isfield(cfg, "requireAllEntries")
        requireAllEntries = ...
            logical(cfg.requireAllEntries);
    else
        requireAllEntries = true;
    end

    if strlength(auditFile) == 0

        [modelFolder, modelStem, ~] = ...
            fileparts(modelFile);

        auditFile = string(fullfile( ...
            modelFolder, ...
            string(modelStem) + ...
            "_force_config_audit.csv"));
    end

    applicationResult = ...
        modelprep.applyForceCapacityConfig( ...
            modelFile, ...
            configFile, ...
            "OutputModelFile", modelFile, ...
            "AllowInPlace", true, ...
            "ApplyMode", applyMode, ...
            "RequireAllEntries", requireAllEntries, ...
            "AuditFile", auditFile);

    assert(applicationResult.VerificationPassed, ...
        "ForceCapacityPipeline:VerificationFailed", ...
        "Applied force-capacity configuration failed verification.");

    result.Applied = true;
    result.ConfigFile = configFile;
    result.ApplyMode = ...
        applicationResult.ApplyMode;
    result.AuditFile = auditFile;
    result.VerificationPassed = ...
        applicationResult.VerificationPassed;
    result.ApplicationResult = ...
        applicationResult;
end
