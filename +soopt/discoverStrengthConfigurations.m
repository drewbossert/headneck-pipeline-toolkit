function configs = discoverStrengthConfigurations(projectCfg)
%DISCOVERSTRENGTHCONFIGURATIONS Discover canonical SO strength configurations.
%
% configs = soopt.discoverStrengthConfigurations(projectCfg)
%
% Discovery is driven by configuration directories that actually exist
% beneath:
%
%   <outputRoot>/static_optimization_configs/
%
% Only directories using the canonical strength-configuration identity:
%
%   m{muscle_percent}p_a{actuator_percent}p
%
% are returned. Noncanonical directories are ignored.
%
% This function is intentionally SIDE-EFFECT FREE. It does not create,
% modify, or delete any directories or files.
%
% RETURN TABLE
%
%   ConfigId
%   MusclePercent
%   ActuatorPercent
%   ConfigRoot
%   BatchQcDirectory
%   Process4SummaryCsv
%   Process4SummaryCsvExists
%   Process4SummaryMat
%   Process4SummaryMatExists
%   AnalysisDirectory
%   AnalysisExists

    %% Validate project configuration

    assert(isstruct(projectCfg) && isscalar(projectCfg), ...
        "StrengthConfigDiscovery:InvalidProjectConfig", ...
        "projectCfg must be a scalar struct.");

    assert(isfield(projectCfg, "outputRoot"), ...
        "StrengthConfigDiscovery:OutputRootMissing", ...
        "projectCfg.outputRoot is required.");

    outputRoot = string(projectCfg.outputRoot);

    assert(isscalar(outputRoot) && ...
            ~ismissing(outputRoot) && ...
            strlength(outputRoot) > 0, ...
        "StrengthConfigDiscovery:InvalidOutputRoot", ...
        "projectCfg.outputRoot must be a nonempty scalar path.");

    assert(isfolder(outputRoot), ...
        "StrengthConfigDiscovery:OutputRootNotFound", ...
        "Project output root was not found:\n%s", ...
        outputRoot);

    %% Resolve canonical collection root

    collectionRoot = string(fullfile( ...
        outputRoot, ...
        "static_optimization_configs"));

    if ~isfolder(collectionRoot)
        configs = localEmptyDiscoveryTable();
        return;
    end

    %% Enumerate candidate configuration directories

    listing = dir(collectionRoot);

    isCandidateDirectory = [listing.isdir].';
    candidateNames = string({listing.name}).';

    isCandidateDirectory = ...
        isCandidateDirectory & ...
        candidateNames ~= "." & ...
        candidateNames ~= "..";

    listing = listing(isCandidateDirectory);

    if isempty(listing)
        configs = localEmptyDiscoveryTable();
        return;
    end

    nCandidates = numel(listing);

    ConfigId = strings(nCandidates,1);
    MusclePercent = nan(nCandidates,1);
    ActuatorPercent = nan(nCandidates,1);

    ConfigRoot = strings(nCandidates,1);
    BatchQcDirectory = strings(nCandidates,1);

    Process4SummaryCsv = strings(nCandidates,1);
    Process4SummaryCsvExists = false(nCandidates,1);

    Process4SummaryMat = strings(nCandidates,1);
    Process4SummaryMatExists = false(nCandidates,1);

    AnalysisDirectory = strings(nCandidates,1);
    AnalysisExists = false(nCandidates,1);

    keep = false(nCandidates,1);

    %% Parse canonical identities and resolve expected artifacts

    for iCandidate = 1:nCandidates

        directoryName = string(listing(iCandidate).name);

        try
            info = pipeline.parseStrengthConfigName( ...
                directoryName + ".json");
        catch exception
            if startsWith( ...
                    string(exception.identifier), ...
                    "StrengthConfig:")
                continue;
            end

            rethrow(exception);
        end

        configRoot = string(fullfile( ...
            collectionRoot, ...
            directoryName));

        batchQcDirectory = string(fullfile( ...
            configRoot, ...
            "batch_qc"));

        process4SummaryCsv = string(fullfile( ...
            batchQcDirectory, ...
            "process_4_static_optimization_summary.csv"));

        process4SummaryMat = string(fullfile( ...
            batchQcDirectory, ...
            "process_4_static_optimization_summary.mat"));

        analysisDirectory = string(fullfile( ...
            configRoot, ...
            "static_optimization_analysis"));

        keep(iCandidate) = true;

        ConfigId(iCandidate) = info.ConfigId;
        MusclePercent(iCandidate) = info.MusclePercent;
        ActuatorPercent(iCandidate) = info.ActuatorPercent;

        ConfigRoot(iCandidate) = configRoot;
        BatchQcDirectory(iCandidate) = batchQcDirectory;

        Process4SummaryCsv(iCandidate) = process4SummaryCsv;
        Process4SummaryCsvExists(iCandidate) = isfile(process4SummaryCsv);

        Process4SummaryMat(iCandidate) = process4SummaryMat;
        Process4SummaryMatExists(iCandidate) = isfile(process4SummaryMat);

        AnalysisDirectory(iCandidate) = analysisDirectory;
        AnalysisExists(iCandidate) = isfolder(analysisDirectory);
    end

    %% Remove noncanonical directories

    ConfigId = ConfigId(keep);
    MusclePercent = MusclePercent(keep);
    ActuatorPercent = ActuatorPercent(keep);

    ConfigRoot = ConfigRoot(keep);
    BatchQcDirectory = BatchQcDirectory(keep);

    Process4SummaryCsv = Process4SummaryCsv(keep);
    Process4SummaryCsvExists = Process4SummaryCsvExists(keep);

    Process4SummaryMat = Process4SummaryMat(keep);
    Process4SummaryMatExists = Process4SummaryMatExists(keep);

    AnalysisDirectory = AnalysisDirectory(keep);
    AnalysisExists = AnalysisExists(keep);

    %% Build deterministic discovery table

    configs = table( ...
        ConfigId, ...
        MusclePercent, ...
        ActuatorPercent, ...
        ConfigRoot, ...
        BatchQcDirectory, ...
        Process4SummaryCsv, ...
        Process4SummaryCsvExists, ...
        Process4SummaryMat, ...
        Process4SummaryMatExists, ...
        AnalysisDirectory, ...
        AnalysisExists);

    if ~isempty(configs)
        configs = sortrows( ...
            configs, ...
            { ...
                'MusclePercent', ...
                'ActuatorPercent', ...
                'ConfigId'});
    end
end


function T = localEmptyDiscoveryTable()

    T = table( ...
        strings(0,1), ...
        zeros(0,1), ...
        zeros(0,1), ...
        strings(0,1), ...
        strings(0,1), ...
        strings(0,1), ...
        false(0,1), ...
        strings(0,1), ...
        false(0,1), ...
        strings(0,1), ...
        false(0,1), ...
        'VariableNames', { ...
            'ConfigId', ...
            'MusclePercent', ...
            'ActuatorPercent', ...
            'ConfigRoot', ...
            'BatchQcDirectory', ...
            'Process4SummaryCsv', ...
            'Process4SummaryCsvExists', ...
            'Process4SummaryMat', ...
            'Process4SummaryMatExists', ...
            'AnalysisDirectory', ...
            'AnalysisExists'});
end
