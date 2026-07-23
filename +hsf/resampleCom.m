function result = resampleCom(comInput, targetRateHz, varargin)
%RESAMPLECOM Resample a center-of-mass trajectory to a uniform rate.
%
% result = hsf.resampleCom(comInput, targetRateHz)
%
% Name-value options:
%   TimeRange            [] (input start/end)
%   InterpolationMethod  "pchip", "linear", or "makima"
%
% The output time vector includes the input start and advances by exactly
% 1/targetRateHz. The final sample is the last grid point not exceeding the
% requested end time, with the exact end appended when it lies within
% numerical tolerance of the uniform grid.

    parser = inputParser;
    parser.FunctionName = "hsf.resampleCom";

    addRequired(parser, "comInput", @isstruct);
    addRequired(parser, "targetRateHz", ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);

    addParameter(parser, "TimeRange", [], ...
        @(x) isempty(x) || ...
        (isnumeric(x) && numel(x) == 2 && x(2) >= x(1)));
    addParameter(parser, "InterpolationMethod", "pchip", ...
        @(x) any(strcmpi(string(x), ...
        ["pchip", "linear", "makima"])));

    parse(parser, comInput, targetRateHz, varargin{:});

    requiredFields = ["Time", "X", "Y", "Z"];

    if ~all(isfield(comInput, requiredFields))
        error("hsf:InvalidComStructure", ...
            "comInput must contain Time, X, Y, and Z.");
    end

    sourceTime = double(comInput.Time(:));
    sourceData = [ ...
        double(comInput.X(:)), ...
        double(comInput.Y(:)), ...
        double(comInput.Z(:))];

    if any(diff(sourceTime) <= 0)
        error("hsf:NonmonotonicComTime", ...
            "CoM time values must be strictly increasing.");
    end

    if isempty(parser.Results.TimeRange)
        timeRange = [sourceTime(1), sourceTime(end)];
    else
        timeRange = double(parser.Results.TimeRange(:)).';
    end

    tolerance = max(1e-12, 1e-9 * max(abs(sourceTime)));

    if timeRange(1) < sourceTime(1) - tolerance || ...
            timeRange(2) > sourceTime(end) + tolerance
        error("hsf:ComResamplingOutsideRange", ...
            "Requested resampling range exceeds the CoM data range.");
    end

    dt = 1 / double(targetRateHz);
    numberOfSteps = floor((timeRange(2) - timeRange(1)) / dt + 1e-10);
    targetTime = timeRange(1) + (0:numberOfSteps).' * dt;

    if abs(targetTime(end) - timeRange(2)) <= max(tolerance, dt*1e-8)
        targetTime(end) = timeRange(2);
    end

    method = lower(string(parser.Results.InterpolationMethod));
    targetData = interp1( ...
        sourceTime, sourceData, targetTime, char(method));

    if any(~isfinite(targetData), "all")
        error("hsf:ComInterpolationFailed", ...
            "CoM interpolation produced non-finite values.");
    end

    result = struct;
    result.Time = targetTime;
    result.X = targetData(:, 1);
    result.Y = targetData(:, 2);
    result.Z = targetData(:, 3);
    result.Data = targetData;
    result.TargetRateHz = double(targetRateHz);
    result.InterpolationMethod = method;
    result.SourceStartTime = sourceTime(1);
    result.SourceEndTime = sourceTime(end);

    if isfield(comInput, "BodyName")
        result.BodyName = comInput.BodyName;
    else
        result.BodyName = "";
    end
end
