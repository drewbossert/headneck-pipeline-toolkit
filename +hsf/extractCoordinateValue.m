function result = extractCoordinateValue( ...
        motionInput, coordinateName, varargin)
%EXTRACTCOORDINATEVALUE Extract a coordinate value from an IK motion file.
%
% result = hsf.extractCoordinateValue(motionInput, coordinateName)
%
% Name-value options:
%   TimeWindow       [] (entire file)
%   Method           "median", "mean", "first", or "at_time"
%   Time             [] (required for Method="at_time")
%   RequireConstant  true
%   Tolerance        1e-6
%
% Result fields:
%   Coordinate, Value, Minimum, Maximum, Range, IsConstant,
%   Unit, TimeWindow, NumSamples
%
% Rotational values remain in the units stored by the motion file. For the
% HSF workflow, gndroll is expected in degrees when inDegrees=yes.
    parser = inputParser;
    parser.FunctionName = "hsf.extractCoordinateValue";

    addRequired(parser, "motionInput");
    addRequired(parser, "coordinateName", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, "TimeWindow", [], ...
        @(x) isempty(x) || ...
        (isnumeric(x) && numel(x) == 2 && x(2) >= x(1)));
    addParameter(parser, "Method", "median", ...
        @(x) any(strcmpi(string(x), ...
        ["median", "mean", "first", "at_time"])));
    addParameter(parser, "Time", [], ...
        @(x) isempty(x) || ...
        (isnumeric(x) && isscalar(x) && isfinite(x)));
    addParameter(parser, "RequireConstant", true, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, "Tolerance", 1e-6, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 0);
    parse(parser, motionInput, coordinateName, varargin{:});

    motion = opensimio.resolveMotion(motionInput);
    coordinateName = string(coordinateName);
    normalizedLabels = strings(size(motion.Labels));

    for index = 1:numel(motion.Labels)
        normalizedLabels(index) = ...
            opensimio.normalizeMotionLabel(motion.Labels(index));
    end

    labelIndex = find(normalizedLabels == coordinateName, 1);
    if isempty(labelIndex)
        error("hsf:CoordinateNotFound", ...
            "Coordinate '%s' was not found in the motion file.", ...
            coordinateName);
    end

    if isempty(parser.Results.TimeWindow)
        timeWindow = [motion.Time(1), motion.Time(end)];
    else
        timeWindow = double(parser.Results.TimeWindow(:)).';
    end

    mask = motion.Time >= timeWindow(1) & ...
        motion.Time <= timeWindow(2);
    if ~any(mask)
        error("hsf:EmptyCoordinateWindow", ...
            "No samples lie in the requested time window.");
    end

    values = motion.Data(mask, labelIndex);
    times = motion.Time(mask);
    method = lower(string(parser.Results.Method));
    switch method
        case "median"
            value = median(values, "omitnan");
        case "mean"
            value = mean(values, "omitnan");
        case "first"
            value = values(find(isfinite(values), 1, "first"));
        case "at_time"
            requestedTime = parser.Results.Time;

            if isempty(requestedTime)
                error("hsf:MissingCoordinateTime", ...
                    "Time is required for Method='at_time'.");
            end
            if requestedTime < times(1) || requestedTime > times(end)
                error("hsf:CoordinateTimeOutsideRange", ...
                    "Requested time lies outside the selected window.");
            end

            value = interp1(times, values, requestedTime, "linear");
    end

    minimumValue = min(values, [], "omitnan");
    maximumValue = max(values, [], "omitnan");
    valueRange = maximumValue - minimumValue;
    isConstant = valueRange <= parser.Results.Tolerance;
    if parser.Results.RequireConstant && ~isConstant
        error("hsf:CoordinateNotConstant", ...
            ["Coordinate '%s' range %.12g exceeds tolerance %.12g."], ...
            coordinateName, valueRange, parser.Results.Tolerance);
    end
    if lower(coordinateName) == "gndroll" && ...
            ~(islogical(motion.InDegrees) && motion.InDegrees)
        error("hsf:GndrollNotInDegrees", ...
            ["The HSF force decomposition expects gndroll in degrees. " ...
             "The motion header does not specify inDegrees=yes."]);
    end
    result = struct;
    result.Coordinate = coordinateName;
    result.Value = value;
    result.Minimum = minimumValue;
    result.Maximum = maximumValue;
    result.Range = valueRange;
    result.IsConstant = isConstant;
    result.Unit = "deg";
    result.TimeWindow = timeWindow;
    result.NumSamples = sum(mask);
end
