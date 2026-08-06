function cfg = load_project_config(varargin)
%LOAD_PROJECT_CONFIG Load shared and machine-specific project settings.
%
% cfg = load_project_config()
%
% Name-value options:
%   RequireLocalConfig  true
%   ValidatePaths       true
%
% Configuration order:
%   1. Repository root is detected automatically.
%   2. config/project_defaults.m is executed.
%   3. config/project_local.m overrides machine-specific fields.
%   4. Required files and directories are validated.

    parser = inputParser;
    parser.FunctionName = "load_project_config";

    addParameter(parser, ...
        "RequireLocalConfig", ...
        true, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, ...
        "ValidatePaths", ...
        true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, varargin{:});

    %% Locate repository

    loaderFile = string(mfilename("fullpath"));
    projectRoot = string(fileparts(loaderFile));

    defaultsFile = fullfile( ...
        projectRoot, ...
        "config", ...
        "project_defaults.m");

    localFile = fullfile( ...
        projectRoot, ...
        "config", ...
        "project_local.m");

    exampleFile = fullfile( ...
        projectRoot, ...
        "config", ...
        "project_local_example.m");

    assert(isfile(defaultsFile), ...
        "ProjectConfig:DefaultsMissing", ...
        "Shared defaults file was not found:\n%s", ...
        defaultsFile);

    %% Load shared defaults

    cfg = struct();
    cfg.projectRoot = projectRoot;

    run(defaultsFile);

    %% Load machine-specific overrides

    if isfile(localFile)
        run(localFile);
    elseif parser.Results.RequireLocalConfig
        error("ProjectConfig:LocalConfigMissing", ...
            "Machine-specific configuration was not found:\n%s\n\nCopy:\n%s\n\nto:\n%s\n\nand edit the local paths.", ...
            localFile, exampleFile, localFile);
    end

    cfg.configDirectory = fullfile(projectRoot, "config");
    cfg.defaultsFile = string(defaultsFile);
    cfg.localFile = string(localFile);

    %% Supply optional defaults

    cfg = setDefault(cfg, "machineName", "");
    cfg = setDefault(cfg, "rawDataRoot", "");
    cfg = setDefault(cfg, "openSimRoot", "");
    cfg = setDefault(cfg, "openSimJavaJar", "");
    cfg = setDefault(cfg, "openSimBinDirectory", "");
    % cfg = setDefault(cfg, "overwriteExisting", false);
    cfg = setDefault(cfg, "enableParallel", false);
    cfg = setDefault(cfg, "maxWorkers", 1);

    %% Validate

    if parser.Results.ValidatePaths
        validateConfiguration(cfg);
    end
end

function cfg = setDefault(cfg, fieldName, defaultValue)

    if ~isfield(cfg, fieldName)
        cfg.(fieldName) = defaultValue;
    end
end

function validateConfiguration(cfg)

    assert(isfolder(cfg.projectRoot), ...
        "ProjectConfig:ProjectRootMissing", ...
        "Project root was not found:\n%s", ...
        cfg.projectRoot);

    assert(isfolder(cfg.modelsDirectory), ...
        "ProjectConfig:ModelsDirectoryMissing", ...
        "Models directory was not found:\n%s", ...
        cfg.modelsDirectory);

    assert(isfolder(cfg.inputDirectory), ...
        "ProjectConfig:InputDirectoryMissing", ...
        "Input directory was not found:\n%s", ...
        cfg.inputDirectory);

    if ~isfolder(cfg.outputRoot)
        mkdir(cfg.outputRoot);
    end

    if cfg.requireKinematicBaseModel
        assert(isfile(cfg.kinematicBaseModel), ...
            "ProjectConfig:KinematicModelMissing", ...
            "Kinematic base model was not found:\n%s", ...
            cfg.kinematicBaseModel);
    end

    if cfg.requireScalingBaseModel
        assert(isfile(cfg.scalingBaseModel), ...
            "ProjectConfig:ScalingModelMissing", ...
            "Scaling base model was not found:\n%s", ...
            cfg.scalingBaseModel);
    end

    if cfg.requireInitializationIkTemplate
        assert(isfile(cfg.initializationIkTemplate), ...
            "ProjectConfig:IkTemplateMissing", ...
            "Initialization IK template was not found:\n%s", ...
            cfg.initializationIkTemplate);
    end

    if strlength(string(cfg.rawDataRoot)) > 0
        assert(isfolder(cfg.rawDataRoot), ...
            "ProjectConfig:RawDataRootMissing", ...
            "Raw-data directory was not found:\n%s", ...
            cfg.rawDataRoot);
    end

    assert(isnumeric(cfg.maxWorkers) && ...
        isscalar(cfg.maxWorkers) && ...
        isfinite(cfg.maxWorkers) && ...
        cfg.maxWorkers >= 1 && ...
        mod(cfg.maxWorkers, 1) == 0, ...
        "ProjectConfig:InvalidMaxWorkerCount", ...
        "maxWorkers must be a positive integer.");
end