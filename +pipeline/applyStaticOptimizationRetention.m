function result = applyStaticOptimizationRetention( ...
        projectCfg, resultsDirectory, varargin)
%APPLYSTATICOPTIMIZATIONRETENTION Apply immediate SO artifact retention.
%
% result = pipeline.applyStaticOptimizationRetention( ...
%     projectCfg, resultsDirectory)
%
% Applies ONLY immediate, post-audit cleanup rules. Shared-cache and other
% end-of-workflow retention settings are intentionally not applied here.
%
% Current immediate artifact:
%   *StaticOptimization_controls.xml
%
% The caller should invoke this only after Static Optimization has run and
% its required scientific outputs have passed structural/QC checks. If an SO
% run errors before that point, this function should not be called, leaving
% transient artifacts available for diagnosis.

    assert(isstruct(projectCfg) && isscalar(projectCfg), ...
        "StorageRetentionApply:InvalidProjectConfig", ...
        "projectCfg must be a scalar struct.");

    parser = inputParser;
    parser.FunctionName = "pipeline.applyStaticOptimizationRetention";

    addRequired(parser, ...
        "resultsDirectory", ...
        @(x) ...
            (ischar(x) && isrow(x)) || ...
            (isstring(x) && isscalar(x) && ~ismissing(x)));

    addParameter(parser, ...
        "PrintProgress", ...
        false, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, resultsDirectory, varargin{:});

    resultsDirectory = string(parser.Results.resultsDirectory);
    printProgress = logical(parser.Results.PrintProgress);

    assert(isfolder(resultsDirectory), ...
        "StorageRetentionApply:ResultsDirectoryMissing", ...
        "Static Optimization results directory was not found:\n%s", ...
        resultsDirectory);

    policy = pipeline.resolveStorageRetentionPolicy(projectCfg);

    listing = dir(fullfile( ...
        resultsDirectory, ...
        "*StaticOptimization_controls.xml"));

    controlsFiles = strings(numel(listing),1);

    for iFile = 1:numel(listing)
        controlsFiles(iFile) = string(fullfile( ...
            listing(iFile).folder, ...
            listing(iFile).name));
    end

    nFiles = numel(controlsFiles);

    ArtifactType = repmat( ...
        "static_optimization_controls_xml", ...
        nFiles, ...
        1);

    File = controlsFiles;
    Existed = true(nFiles,1);
    Retained = false(nFiles,1);
    Deleted = false(nFiles,1);
    Failed = false(nFiles,1);
    Reason = strings(nFiles,1);
    ErrorMessage = strings(nFiles,1);

    for iFile = 1:nFiles

        if policy.StaticOptimization.KeepControlsXml
            Retained(iFile) = true;
            Reason(iFile) = "retained_by_policy";
            continue;
        end

        try
            delete(File(iFile));
            Deleted(iFile) = ~isfile(File(iFile));

            if Deleted(iFile)
                Reason(iFile) = "deleted_by_policy";
            else
                Reason(iFile) = ...
                    "delete_requested_but_file_remains";
            end

        catch exception
            Failed(iFile) = true;
            Reason(iFile) = "delete_failed";
            ErrorMessage(iFile) = string(exception.message);

            if printProgress
                warning( ...
                    "StorageRetentionApply:DeleteFailed", ...
                    "Retention cleanup could not delete:\n%s\n%s", ...
                    File(iFile), ...
                    ErrorMessage(iFile));
            end
        end
    end

    Actions = table( ...
        ArtifactType, ...
        File, ...
        Existed, ...
        Retained, ...
        Deleted, ...
        Failed, ...
        Reason, ...
        ErrorMessage);

    result = struct;
    result.SchemaVersion = 1;
    result.ResultsDirectory = resultsDirectory;
    result.ControlsXmlFilesFound = nFiles;
    result.ControlsXmlFilesDeleted = nnz(Deleted);
    result.ControlsXmlFilesRetained = nnz(Retained);
    result.CleanupFailureCount = nnz(Failed);
    result.CleanupPassed = ~any(Failed);
    result.Actions = Actions;

    if printProgress

        if policy.StaticOptimization.KeepControlsXml
            fprintf( ...
                "SO retention: retained %d controls XML file(s).\n", ...
                nFiles);
        else
            fprintf( ...
                "SO retention: deleted %d of %d controls XML file(s).\n", ...
                nnz(Deleted), ...
                nFiles);
        end
    end
end
