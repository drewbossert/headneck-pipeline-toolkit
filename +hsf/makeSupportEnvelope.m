function result = makeSupportEnvelope(time, varargin)
%MAKESUPPORTENVELOPE Create a 0-to-1 head-support-force envelope.
%
% result = hsf.makeSupportEnvelope(time)
%
% Name-value options:
%   OffIntervals   N-by-2 intervals where HSF is zero
%   RampDuration   0.1 seconds
%   RampShape      "halfcosine" or "linear"
%
% For each off interval [a,b], the force ramps down during
% [a-RampDuration,a], remains zero through [a,b], and ramps up during
% [b,b+RampDuration]. Multiple intervals are combined using the minimum
% envelope.

    parser = inputParser;
    parser.FunctionName = "hsf.makeSupportEnvelope";

    addRequired(parser, "time", ...
        @(x) isnumeric(x) && isvector(x) && all(isfinite(x)));

    addParameter(parser, "OffIntervals", zeros(0,2), ...
        @(x) isnumeric(x) && (isempty(x) || size(x,2) == 2));
    addParameter(parser, "RampDuration", 0.1, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
    addParameter(parser, "RampShape", "halfcosine", ...
        @(x) any(strcmpi(string(x), ["halfcosine", "linear"])));

    parse(parser, time, varargin{:});

    time = double(time(:));

    if any(diff(time) <= 0)
        error("hsf:NonmonotonicEnvelopeTime", ...
            "Time values must be strictly increasing.");
    end

    intervals = double(parser.Results.OffIntervals);
    rampDuration = double(parser.Results.RampDuration);
    rampShape = lower(string(parser.Results.RampShape));

    if isempty(intervals)
        intervals = zeros(0,2);
    end

    if any(intervals(:,2) < intervals(:,1))
        error("hsf:InvalidOffInterval", ...
            "Each off interval must satisfy end >= start.");
    end

    if size(intervals,1) > 1
        intervals = sortrows(intervals, 1);

        if any(intervals(2:end,1) < intervals(1:end-1,2))
            error("hsf:OverlappingOffIntervals", ...
                "Off intervals cannot overlap.");
        end
    end

    envelope = ones(size(time));

    for intervalIndex = 1:size(intervals,1)
        offStart = intervals(intervalIndex,1);
        offEnd = intervals(intervalIndex,2);
        intervalEnvelope = ones(size(time));

        offMask = time >= offStart & time <= offEnd;
        intervalEnvelope(offMask) = 0;

        if rampDuration > 0
            downMask = time >= offStart-rampDuration & ...
                time < offStart;

            if any(downMask)
                progress = (time(downMask) - ...
                    (offStart-rampDuration)) / rampDuration;
                intervalEnvelope(downMask) = ...
                    hsf.internal.rampDown(progress, rampShape);
            end

            upMask = time > offEnd & ...
                time <= offEnd+rampDuration;

            if any(upMask)
                progress = (time(upMask) - offEnd) / rampDuration;
                intervalEnvelope(upMask) = ...
                    hsf.internal.rampUp(progress, rampShape);
            end
        end

        envelope = min(envelope, intervalEnvelope);
    end

    result = struct;
    result.Time = time;
    result.Envelope = envelope;
    result.OffIntervals = intervals;
    result.RampDuration = rampDuration;
    result.RampShape = rampShape;
    result.Minimum = min(envelope);
    result.Maximum = max(envelope);
end
