function values = extractStableCoordinateValues( ...
        motionInput, modelInput, coordinateNames, timeWindow, varargin)
%EXTRACTSTABLECOORDINATEVALUES Summarize coordinate values in a time window.
%
% values = modelprep.extractStableCoordinateValues( ...
%     motionInput, modelInput, coordinateNames, timeWindow)
%
% motionInput may be a parsed opensimio table structure or a .mot path.
% timeWindow is [startTime endTime] in seconds.
%
% Name-value options:
%   Method                    "median" (default), "mean", "first", or "last"
%   RotationToleranceDeg      0.05
%   TranslationToleranceM     1e-5
%   OtherTolerance            1e-8
%   RequireStable             false
%   MinimumSamples            3
%
% The ValueSI column is suitable for Coordinate.setDefaultValue().

    parser = inputParser;
    parser.FunctionName = "modelprep.extractStableCoordinateValues";

    addRequired(parser, "motionInput");
    addRequired(parser, "modelInput");
    addRequired(parser, "coordinateNames");
    addRequired(parser, "timeWindow", ...
        @(x) isnumeric(x) && numel(x) == 2 && ...
        all(isfinite(x)) && x(2) >= x(1));

    addParameter(parser, "Method", "median", ...
        @(x) any(strcmpi(string(x), ...
        ["median", "mean", "first", "last"])));

    addParameter(parser, "RotationToleranceDeg", 0.05, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 0);

    addParameter(parser, "TranslationToleranceM", 1e-5, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 0);

    addParameter(parser, "OtherTolerance", 1e-8, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 0);

    addParameter(parser, "RequireStable", false, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "MinimumSamples", 3, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 1);

    parse(parser, motionInput, modelInput, ...
        coordinateNames, timeWindow, varargin{:});

    motion = opensimio.resolveMotion(motionInput);
    modelReport = modelprep.inspectModel(modelInput);

    coordinateNames = string(coordinateNames);
    coordinateNames = coordinateNames(:);
    method = lower(string(parser.Results.Method));

    normalizedLabels = strings(size(motion.Labels));

    for index = 1:numel(motion.Labels)
        normalizedLabels(index) = ...
            modelprep.internal.normalizeMotionLabel( ...
            motion.Labels(index));
    end

    if numel(unique(normalizedLabels)) ~= numel(normalizedLabels)
        error("modelprep:DuplicateMotionLabels", ...
            "Motion labels are not unique after path normalization.");
    end

    window = double(timeWindow(:)).';
    windowMask = motion.Time >= window(1) & motion.Time <= window(2);

    if sum(windowMask) < parser.Results.MinimumSamples
        error("modelprep:InsufficientWindowSamples", ...
            "Only %d samples lie in the requested window [%.9g, %.9g] s.", ...
            sum(windowMask), window(1), window(2));
    end

    nCoordinates = numel(coordinateNames);

    Coordinate = coordinateNames;
    CoordinateType = strings(nCoordinates, 1);
    Method = repmat(method, nCoordinates, 1);
    WindowStart = repmat(window(1), nCoordinates, 1);
    WindowEnd = repmat(window(2), nCoordinates, 1);
    NumSamples = repmat(sum(windowMask), nCoordinates, 1);
    ValueSI = nan(nCoordinates, 1);
    ValueDisplay = nan(nCoordinates, 1);
    DisplayUnit = strings(nCoordinates, 1);
    MinimumDisplay = nan(nCoordinates, 1);
    MaximumDisplay = nan(nCoordinates, 1);
    RangeDisplay = nan(nCoordinates, 1);
    StandardDeviationDisplay = nan(nCoordinates, 1);
    StabilityToleranceDisplay = nan(nCoordinates, 1);
    IsStable = false(nCoordinates, 1);

    for coordinateIndex = 1:nCoordinates
        coordinateName = coordinateNames(coordinateIndex);

        modelIndex = find( ...
            modelReport.Coordinates.Coordinate == coordinateName, ...
            1);

        if isempty(modelIndex)
            error("modelprep:MissingModelCoordinate", ...
                "Coordinate '%s' is not present in the model.", ...
                coordinateName);
        end

        motionIndex = find( ...
            normalizedLabels == coordinateName, ...
            1);

        if isempty(motionIndex)
            error("modelprep:MissingMotionCoordinate", ...
                "Coordinate '%s' is not present in the motion file.", ...
                coordinateName);
        end

        coordinateType = ...
            modelReport.Coordinates.CoordinateType(modelIndex);

        rawValues = motion.Data(windowMask, motionIndex);
        valuesSI = modelprep.internal.motionValuesToSI( ...
            rawValues, coordinateType, motion.InDegrees);

        switch method
            case "median"
                valueSI = median(valuesSI, "omitnan");
            case "mean"
                valueSI = mean(valuesSI, "omitnan");
            case "first"
                valueSI = valuesSI(find(isfinite(valuesSI), 1, "first"));
            case "last"
                valueSI = valuesSI(find(isfinite(valuesSI), 1, "last"));
        end

        displayValues = ...
            modelprep.internal.siToDisplay(valuesSI, coordinateType);

        CoordinateType(coordinateIndex) = coordinateType;
        ValueSI(coordinateIndex) = valueSI;
        ValueDisplay(coordinateIndex) = ...
            modelprep.internal.siToDisplay(valueSI, coordinateType);

        if coordinateType == "rotation"
            DisplayUnit(coordinateIndex) = "deg";
            tolerance = parser.Results.RotationToleranceDeg;
        elseif coordinateType == "translation"
            DisplayUnit(coordinateIndex) = "m";
            tolerance = parser.Results.TranslationToleranceM;
        else
            DisplayUnit(coordinateIndex) = "SI";
            tolerance = parser.Results.OtherTolerance;
        end

        MinimumDisplay(coordinateIndex) = ...
            min(displayValues, [], "omitnan");
        MaximumDisplay(coordinateIndex) = ...
            max(displayValues, [], "omitnan");
        RangeDisplay(coordinateIndex) = ...
            MaximumDisplay(coordinateIndex) - ...
            MinimumDisplay(coordinateIndex);
        StandardDeviationDisplay(coordinateIndex) = ...
            std(displayValues, "omitnan");
        StabilityToleranceDisplay(coordinateIndex) = tolerance;
        IsStable(coordinateIndex) = ...
            RangeDisplay(coordinateIndex) <= tolerance;
    end

    values = table( ...
        Coordinate, CoordinateType, Method, ...
        WindowStart, WindowEnd, NumSamples, ...
        ValueSI, ValueDisplay, DisplayUnit, ...
        MinimumDisplay, MaximumDisplay, ...
        RangeDisplay, StandardDeviationDisplay, ...
        StabilityToleranceDisplay, IsStable, ...
        'VariableNames', { ...
            'Coordinate', 'CoordinateType', 'Method', ...
            'WindowStart', 'WindowEnd', 'NumSamples', ...
            'ValueSI', 'ValueDisplay', 'DisplayUnit', ...
            'MinimumDisplay', 'MaximumDisplay', ...
            'RangeDisplay', 'StandardDeviationDisplay', ...
            'StabilityToleranceDisplay', 'IsStable'});

    if parser.Results.RequireStable && any(~values.IsStable)
        unstable = values.Coordinate(~values.IsStable);

        error("modelprep:UnstableCoordinates", ...
            "Coordinate(s) exceed stability tolerance: %s", ...
            strjoin(unstable, ", "));
    end
end
