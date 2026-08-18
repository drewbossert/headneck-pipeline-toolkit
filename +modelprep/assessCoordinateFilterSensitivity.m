function result = assessCoordinateFilterSensitivity( ...
    motionInput, coordinateNames, lockWindow, varargin)
%ASSESSCOORDINATEFILTERSENSITIVITY
% Assess low-pass filter sensitivity for selected rotational coordinates.
%
% result = modelprep.assessCoordinateFilterSensitivity( ...
%     motionInput, coordinateNames, lockWindow)
%
% motionInput may be:
%   - an OpenSim motion struct returned by opensimio.readMot
%   - a path to a .mot file
%
% coordinateNames:
%   String array of rotational coordinate names to assess.
%
% lockWindow:
%   [startTime endTime] in seconds.
%
% Name-value options:
%   CandidateCutoffsHz
%   PrototypeOrder
%   StabilityToleranceDeg
%   MinimumWindowSamples
%
% Returned result fields:
%   Summary
%   Time
%   Coordinates
%   CandidateCutoffsHz
%   RawDataDeg
%   FilteredDataDeg
%   SampleRateHz
%   LockWindow
%
% FilteredDataDeg dimensions:
%   samples x coordinates x cutoff frequencies

    parser = inputParser;
    parser.FunctionName = ...
        "modelprep.assessCoordinateFilterSensitivity";

    addRequired(parser, "motionInput");

    addRequired(parser, "coordinateNames", ...
        @(x) ischar(x) || isstring(x) || iscellstr(x));

    addRequired(parser, "lockWindow", ...
        @(x) isnumeric(x) && numel(x) == 2);

    addParameter(parser, "CandidateCutoffsHz", ...
        [0.5 1.0 2.0 3.0], ...
        @(x) isnumeric(x) && isvector(x) && all(x > 0));

    addParameter(parser, "PrototypeOrder", 2, ...
        @(x) isnumeric(x) && isscalar(x) && ...
        x >= 1 && mod(x, 1) == 0);

    addParameter(parser, "StabilityToleranceDeg", NaN, ...
        @(x) isnumeric(x) && isscalar(x));

    addParameter(parser, "MinimumWindowSamples", 2, ...
        @(x) isnumeric(x) && isscalar(x) && ...
        x >= 2 && mod(x, 1) == 0);

    parse(parser, ...
        motionInput, ...
        coordinateNames, ...
        lockWindow, ...
        varargin{:});

    coordinateNames = ...
        reshape(string(parser.Results.coordinateNames), 1, []);

    lockWindow = double(parser.Results.lockWindow(:).');

    candidateCutoffsHz = ...
        sort(unique(double( ...
        parser.Results.CandidateCutoffsHz(:).')));

    prototypeOrder = ...
        double(parser.Results.PrototypeOrder);

    stabilityToleranceDeg = ...
        double(parser.Results.StabilityToleranceDeg);

    minimumWindowSamples = ...
        double(parser.Results.MinimumWindowSamples);

    %% Resolve motion input

    motion = ...
        opensimio.resolveMotion( ...
            motionInput);

    requiredFields = [
        "Labels"
        "Data"
        "Time"
        "InDegrees"
    ];

    for iField = 1:numel(requiredFields)

        fieldName = requiredFields(iField);

        assert(isfield(motion, fieldName), ...
            "Motion input is missing required field '%s'.", ...
            fieldName);

    end

    labels = reshape(string(motion.Labels), 1, []);
    data = motion.Data;
    time = motion.Time(:);

    assert(size(data, 1) == numel(time), ...
        "Motion data row count does not match time vector length.");

    assert(size(data, 2) == numel(labels), ...
        "Motion data column count does not match label count.");

    assert(all(isfinite(time)), ...
        "Time vector contains nonfinite values.");

    assert(all(diff(time) > 0), ...
        "Time vector must be strictly increasing.");

    %% Determine sampling frequency

    dt = diff(time);
    medianDt = median(dt);

    Fs = 1 / medianDt;

    relativeDtVariation = ...
        max(abs(dt - medianDt)) / medianDt;

    assert(relativeDtVariation < 1e-3, ...
        ["Time samples are not sufficiently uniform " ...
         "for direct digital filtering."]);

    nyquistHz = Fs / 2;

    assert(all(candidateCutoffsHz < nyquistHz), ...
        "All candidate cutoff frequencies must be below Nyquist.");

    %% Identify lock-window samples

    lockMask = ...
        time >= lockWindow(1) & ...
        time <= lockWindow(2);

    numWindowSamples = nnz(lockMask);

    assert(numWindowSamples >= minimumWindowSamples, ...
        ["Lock window contains only %d samples; " ...
         "minimum required is %d."], ...
        numWindowSamples, ...
        minimumWindowSamples);

    windowTime = time(lockMask);

    %% Allocate outputs

    numCoordinates = numel(coordinateNames);
    numCutoffs = numel(candidateCutoffsHz);
    numSamples = numel(time);

    rawDataDeg = ...
        nan(numSamples, numCoordinates);

    filteredDataDeg = ...
        nan(numSamples, numCoordinates, numCutoffs);

    numRows = numCoordinates * numCutoffs;

    coordinateColumn = strings(numRows, 1);

    cutoffColumn = nan(numRows, 1);
    prototypeOrderColumn = nan(numRows, 1);
    effectiveOrderColumn = nan(numRows, 1);
    sampleCountColumn = nan(numRows, 1);

    rawMedianColumn = nan(numRows, 1);
    filteredMedianColumn = nan(numRows, 1);
    medianShiftColumn = nan(numRows, 1);

    rawRangeColumn = nan(numRows, 1);
    filteredRangeColumn = nan(numRows, 1);
    rangeReductionColumn = nan(numRows, 1);

    rawStdColumn = nan(numRows, 1);
    filteredStdColumn = nan(numRows, 1);
    stdReductionColumn = nan(numRows, 1);

    rawSlopeColumn = nan(numRows, 1);
    filteredSlopeColumn = nan(numRows, 1);

    toleranceColumn = ...
        repmat(stabilityToleranceDeg, numRows, 1);

    stabilityStatusColumn = ...
        strings(numRows, 1);

    %% Filter and assess each coordinate

    rowIndex = 0;

    for iCoordinate = 1:numCoordinates

        coordinate = coordinateNames(iCoordinate);

        matches = find(labels == coordinate);

        assert(~isempty(matches), ...
            "Coordinate '%s' was not found.", ...
            coordinate);

        assert(numel(matches) == 1, ...
            "Coordinate '%s' occurs more than once.", ...
            coordinate);

        raw = data(:, matches);

        assert(all(isfinite(raw)), ...
            "Coordinate '%s' contains nonfinite values.", ...
            coordinate);

        if ~motion.InDegrees
            raw = rad2deg(raw);
        end

        rawDataDeg(:, iCoordinate) = raw;

        rawWindow = raw(lockMask);

        rawMedian = median(rawWindow);
        rawRange = max(rawWindow) - min(rawWindow);
        rawStd = std(rawWindow);

        rawSlope = localLinearSlope( ...
            windowTime, ...
            rawWindow);

        for iCutoff = 1:numCutoffs

            rowIndex = rowIndex + 1;

            cutoffHz = ...
                candidateCutoffsHz(iCutoff);

            normalizedCutoff = ...
                cutoffHz / nyquistHz;

            [b, a] = butter( ...
                prototypeOrder, ...
                normalizedCutoff, ...
                "low");

            filtered = filtfilt( ...
                b, ...
                a, ...
                raw);

            filteredDataDeg( ...
                :, ...
                iCoordinate, ...
                iCutoff) = filtered;

            filteredWindow = ...
                filtered(lockMask);

            filteredMedian = ...
                median(filteredWindow);

            filteredRange = ...
                max(filteredWindow) - ...
                min(filteredWindow);

            filteredStd = ...
                std(filteredWindow);

            filteredSlope = ...
                localLinearSlope( ...
                windowTime, ...
                filteredWindow);

            medianShift = ...
                filteredMedian - rawMedian;

            if rawRange > 0

                rangeReduction = ...
                    100 * ...
                    (1 - filteredRange / rawRange);

            else

                rangeReduction = NaN;

            end

            if rawStd > 0

                stdReduction = ...
                    100 * ...
                    (1 - filteredStd / rawStd);

            else

                stdReduction = NaN;

            end

            if isnan(stabilityToleranceDeg)

                stabilityStatus = ...
                    "not_assessed";

            elseif filteredRange <= ...
                    stabilityToleranceDeg

                stabilityStatus = "pass";

            else

                stabilityStatus = "fail";

            end

            coordinateColumn(rowIndex) = ...
                coordinate;

            cutoffColumn(rowIndex) = ...
                cutoffHz;

            prototypeOrderColumn(rowIndex) = ...
                prototypeOrder;

            effectiveOrderColumn(rowIndex) = ...
                2 * prototypeOrder;

            sampleCountColumn(rowIndex) = ...
                numWindowSamples;

            rawMedianColumn(rowIndex) = ...
                rawMedian;

            filteredMedianColumn(rowIndex) = ...
                filteredMedian;

            medianShiftColumn(rowIndex) = ...
                medianShift;

            rawRangeColumn(rowIndex) = ...
                rawRange;

            filteredRangeColumn(rowIndex) = ...
                filteredRange;

            rangeReductionColumn(rowIndex) = ...
                rangeReduction;

            rawStdColumn(rowIndex) = ...
                rawStd;

            filteredStdColumn(rowIndex) = ...
                filteredStd;

            stdReductionColumn(rowIndex) = ...
                stdReduction;

            rawSlopeColumn(rowIndex) = ...
                rawSlope;

            filteredSlopeColumn(rowIndex) = ...
                filteredSlope;

            stabilityStatusColumn(rowIndex) = ...
                stabilityStatus;

        end
    end

    %% Build summary table

    summary = table( ...
        coordinateColumn, ...
        cutoffColumn, ...
        prototypeOrderColumn, ...
        effectiveOrderColumn, ...
        sampleCountColumn, ...
        rawMedianColumn, ...
        filteredMedianColumn, ...
        medianShiftColumn, ...
        rawRangeColumn, ...
        filteredRangeColumn, ...
        rangeReductionColumn, ...
        rawStdColumn, ...
        filteredStdColumn, ...
        stdReductionColumn, ...
        rawSlopeColumn, ...
        filteredSlopeColumn, ...
        toleranceColumn, ...
        stabilityStatusColumn, ...
        'VariableNames', { ...
            'Coordinate', ...
            'CutoffHz', ...
            'PrototypeOrder', ...
            'EffectiveZeroPhaseOrder', ...
            'NumWindowSamples', ...
            'RawMedianDeg', ...
            'FilteredMedianDeg', ...
            'MedianShiftDeg', ...
            'RawRangeDeg', ...
            'FilteredRangeDeg', ...
            'RangeReductionPct', ...
            'RawStdDeg', ...
            'FilteredStdDeg', ...
            'StdReductionPct', ...
            'RawSlopeDegPerSec', ...
            'FilteredSlopeDegPerSec', ...
            'StabilityToleranceDeg', ...
            'StabilityStatus'});

    summary = sortrows( ...
        summary, ...
        ["Coordinate", "CutoffHz"]);

    %% Assemble result

    result = struct;

    result.Summary = summary;
    result.Time = time;
    result.Coordinates = coordinateNames;
    result.CandidateCutoffsHz = candidateCutoffsHz;

    result.RawDataDeg = rawDataDeg;
    result.FilteredDataDeg = filteredDataDeg;

    result.SampleRateHz = Fs;
    result.LockWindow = lockWindow;
    result.NumWindowSamples = numWindowSamples;

    result.PrototypeOrder = prototypeOrder;
    result.EffectiveZeroPhaseOrder = ...
        2 * prototypeOrder;

end


function slope = localLinearSlope(time, values)
%LOCALLINEARSLOPE Linear least-squares slope.

    time = time(:);
    values = values(:);

    if numel(time) < 2

        slope = NaN;
        return;

    end

    shiftedTime = ...
        time - time(1);

    coefficients = ...
        polyfit(shiftedTime, values, 1);

    slope = coefficients(1);

end