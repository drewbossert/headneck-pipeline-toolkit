function result = summarizeCoordinateMotion( ...
    motionInput, coordinateNames, varargin)
%SUMMARIZECOORDINATEMOTION Summarize selected OpenSim coordinate trajectories.
%
% result = modelprep.summarizeCoordinateMotion( ...
%     motionInput, coordinateNames)
%
% The function extracts selected coordinate trajectories and calculates
% descriptive metrics over a requested analysis interval. An optional
% baseline window can be supplied so coordinate excursions can be reported
% relative to the supported initial pose.
%
% INPUTS
%   motionInput
%       OpenSim motion struct returned by opensimio.readMot, or path to a
%       .mot file.
%
%   coordinateNames
%       Names of coordinates to summarize.
%
% NAME-VALUE OPTIONS
%   "TimeWindow"
%       Analysis interval [start end]. Default = complete motion.
%
%   "BaselineWindow"
%       Interval used to calculate baseline coordinate values.
%       Default = [] (first analyzed sample).
%
%   "BaselineStatistic"
%       "median" or "mean". Default = "median".
%
% OUTPUT
%   result.Summary
%       One row per coordinate.
%
%   result.Trajectories
%       Time plus selected coordinate trajectories.
%
%   result.RelativeTrajectories
%       Time plus trajectories expressed relative to baseline.
%
%   result.BaselineValues
%       Baseline value corresponding to each coordinate.
%
%   result.TimeWindow
%   result.BaselineWindow
%   result.InDegrees
%   result.SourceFile

    parser = inputParser;
    parser.FunctionName = ...
        "modelprep.summarizeCoordinateMotion";

    addRequired(parser, "motionInput");

    addRequired(parser, "coordinateNames", ...
        @(x) ischar(x) || isstring(x) || iscellstr(x));

    addParameter(parser, "TimeWindow", [], ...
        @(x) isempty(x) || ...
        (isnumeric(x) && numel(x) == 2 && all(isfinite(x))));

    addParameter(parser, "BaselineWindow", [], ...
        @(x) isempty(x) || ...
        (isnumeric(x) && numel(x) == 2 && all(isfinite(x))));

    addParameter(parser, "BaselineStatistic", "median", ...
        @(x) any(strcmpi(string(x), ["median", "mean"])));

    parse(parser, ...
        motionInput, ...
        coordinateNames, ...
        varargin{:});

    coordinateNames = reshape( ...
        string(parser.Results.coordinateNames), ...
        1, []);

    baselineStatistic = ...
        lower(string(parser.Results.BaselineStatistic));

    %% Resolve motion input

    [motion, sourceFile] = ...
        opensimio.resolveMotion( ...
            motionInput);

    %% Validate structure

    requiredFields = [
        "Labels"
        "Data"
        "Time"
        "InDegrees"
    ];

    for iField = 1:numel(requiredFields)

        fieldName = requiredFields(iField);

        assert(isfield(motion, fieldName), ...
            "Motion input is missing field '%s'.", ...
            fieldName);
    end

    labels = reshape(string(motion.Labels), 1, []);
    data = motion.Data;
    time = motion.Time(:);

    assert(size(data, 1) == numel(time), ...
        "Motion data rows do not match the time vector.");

    assert(size(data, 2) == numel(labels), ...
        "Motion data columns do not match the labels.");

    %% Analysis window

    requestedTimeWindow = parser.Results.TimeWindow;

    if isempty(requestedTimeWindow)
        timeWindow = [time(1), time(end)];
    else
        timeWindow = double(requestedTimeWindow(:).');
    end

    assert(timeWindow(2) > timeWindow(1), ...
        "TimeWindow end must exceed start.");

    assert(timeWindow(1) >= time(1) && ...
           timeWindow(2) <= time(end), ...
        "TimeWindow lies outside the motion-file time range.");

    analysisMask = ...
        time >= timeWindow(1) & ...
        time <= timeWindow(2);

    analysisTime = time(analysisMask);

    %% Baseline window

    requestedBaselineWindow = ...
        parser.Results.BaselineWindow;

    if isempty(requestedBaselineWindow)

        baselineWindow = ...
            [analysisTime(1), analysisTime(1)];

        baselineMask = false(size(time));
        baselineMask(find(analysisMask, 1, "first")) = true;

    else

        baselineWindow = ...
            double(requestedBaselineWindow(:).');

        assert(baselineWindow(2) >= baselineWindow(1), ...
            "BaselineWindow end must equal or exceed start.");

        assert(baselineWindow(1) >= timeWindow(1) && ...
               baselineWindow(2) <= timeWindow(2), ...
            "BaselineWindow must lie inside TimeWindow.");

        baselineMask = ...
            time >= baselineWindow(1) & ...
            time <= baselineWindow(2);

    end

    assert(any(baselineMask), ...
        "BaselineWindow contains no motion samples.");

    %% Allocate trajectory matrices

    numCoordinates = numel(coordinateNames);
    numSamples = nnz(analysisMask);

    trajectoryData = ...
        nan(numSamples, numCoordinates);

    relativeData = ...
        nan(numSamples, numCoordinates);

    baselineValues = ...
        nan(numCoordinates, 1);

    %% Allocate summary variables

    coordinateColumn = strings(numCoordinates, 1);
    coordinateTypeColumn = strings(numCoordinates, 1);

    minimumColumn = nan(numCoordinates, 1);
    maximumColumn = nan(numCoordinates, 1);
    rangeColumn = nan(numCoordinates, 1);

    meanColumn = nan(numCoordinates, 1);
    medianColumn = nan(numCoordinates, 1);
    stdColumn = nan(numCoordinates, 1);

    baselineColumn = nan(numCoordinates, 1);

    minimumRelativeColumn = nan(numCoordinates, 1);
    maximumRelativeColumn = nan(numCoordinates, 1);
    peakAbsExcursionColumn = nan(numCoordinates, 1);

    startValueColumn = nan(numCoordinates, 1);
    endValueColumn = nan(numCoordinates, 1);
    netChangeColumn = nan(numCoordinates, 1);

    timeOfMinimumColumn = nan(numCoordinates, 1);
    timeOfMaximumColumn = nan(numCoordinates, 1);
    timeOfPeakExcursionColumn = nan(numCoordinates, 1);

    %% Extract and summarize

    for iCoordinate = 1:numCoordinates

        coordinate = coordinateNames(iCoordinate);

        matches = find(labels == coordinate);

        assert(numel(matches) == 1, ...
            "Coordinate '%s' was not uniquely identified.", ...
            coordinate);

        values = data(:, matches);

        assert(all(isfinite(values)), ...
            "Coordinate '%s' contains nonfinite values.", ...
            coordinate);

        analyzedValues = values(analysisMask);
        baselineSamples = values(baselineMask);

        switch baselineStatistic
            case "median"
                baselineValue = median(baselineSamples);
            case "mean"
                baselineValue = mean(baselineSamples);
        end

        relativeValues = ...
            analyzedValues - baselineValue;

        trajectoryData(:, iCoordinate) = ...
            analyzedValues;

        relativeData(:, iCoordinate) = ...
            relativeValues;

        baselineValues(iCoordinate) = ...
            baselineValue;

        [minimumValue, minimumIndex] = ...
            min(analyzedValues);

        [maximumValue, maximumIndex] = ...
            max(analyzedValues);

        [peakAbsExcursion, peakIndex] = ...
            max(abs(relativeValues));

        coordinateColumn(iCoordinate) = ...
            coordinate;

        coordinateTypeColumn(iCoordinate) = ...
            localCoordinateType(coordinate);

        minimumColumn(iCoordinate) = ...
            minimumValue;

        maximumColumn(iCoordinate) = ...
            maximumValue;

        rangeColumn(iCoordinate) = ...
            maximumValue - minimumValue;

        meanColumn(iCoordinate) = ...
            mean(analyzedValues);

        medianColumn(iCoordinate) = ...
            median(analyzedValues);

        stdColumn(iCoordinate) = ...
            std(analyzedValues);

        baselineColumn(iCoordinate) = ...
            baselineValue;

        minimumRelativeColumn(iCoordinate) = ...
            min(relativeValues);

        maximumRelativeColumn(iCoordinate) = ...
            max(relativeValues);

        peakAbsExcursionColumn(iCoordinate) = ...
            peakAbsExcursion;

        startValueColumn(iCoordinate) = ...
            analyzedValues(1);

        endValueColumn(iCoordinate) = ...
            analyzedValues(end);

        netChangeColumn(iCoordinate) = ...
            analyzedValues(end) - analyzedValues(1);

        timeOfMinimumColumn(iCoordinate) = ...
            analysisTime(minimumIndex);

        timeOfMaximumColumn(iCoordinate) = ...
            analysisTime(maximumIndex);

        timeOfPeakExcursionColumn(iCoordinate) = ...
            analysisTime(peakIndex);

    end

    %% Summary table

    summary = table( ...
        coordinateColumn, ...
        coordinateTypeColumn, ...
        baselineColumn, ...
        startValueColumn, ...
        endValueColumn, ...
        netChangeColumn, ...
        minimumColumn, ...
        maximumColumn, ...
        rangeColumn, ...
        meanColumn, ...
        medianColumn, ...
        stdColumn, ...
        minimumRelativeColumn, ...
        maximumRelativeColumn, ...
        peakAbsExcursionColumn, ...
        timeOfMinimumColumn, ...
        timeOfMaximumColumn, ...
        timeOfPeakExcursionColumn, ...
        'VariableNames', { ...
            'Coordinate', ...
            'CoordinateType', ...
            'BaselineValue', ...
            'StartValue', ...
            'EndValue', ...
            'NetChange', ...
            'Minimum', ...
            'Maximum', ...
            'Range', ...
            'Mean', ...
            'Median', ...
            'StandardDeviation', ...
            'MinimumRelativeToBaseline', ...
            'MaximumRelativeToBaseline', ...
            'PeakAbsoluteExcursionFromBaseline', ...
            'TimeOfMinimum', ...
            'TimeOfMaximum', ...
            'TimeOfPeakExcursion'});

    %% Trajectory tables

    variableNames = ...
        ["time", coordinateNames];

    assert(all(arrayfun( ...
        @(x) isvarname(char(x)), variableNames)), ...
        "One or more coordinate names are invalid MATLAB table names.");

    trajectories = array2table( ...
        [analysisTime, trajectoryData], ...
        "VariableNames", cellstr(variableNames));

    relativeTrajectories = array2table( ...
        [analysisTime, relativeData], ...
        "VariableNames", cellstr(variableNames));

    %% Output

    result = struct;

    result.Summary = summary;
    result.Trajectories = trajectories;
    result.RelativeTrajectories = relativeTrajectories;

    result.BaselineValues = baselineValues;

    result.TimeWindow = timeWindow;
    result.BaselineWindow = baselineWindow;
    result.BaselineStatistic = baselineStatistic;

    result.InDegrees = motion.InDegrees;
    result.SourceFile = sourceFile;

end


function coordinateType = localCoordinateType(coordinate)

    coordinate = string(coordinate);

    if endsWith(coordinate, "_r1")
        coordinateType = "r1";
    elseif endsWith(coordinate, "_r2")
        coordinateType = "r2";
    elseif endsWith(coordinate, "_r3")
        coordinateType = "r3";
    else
        coordinateType = "other";
    end

end