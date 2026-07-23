function report = validateMotion(motionInput, varargin)
%VALIDATEMOTION Validate an HSF .mot structure or file.
%
% report = hsf.validateMotion(motionInput)
%
% Name-value options:
%   ExpectedRateHz       1000
%   ForcePrefix          "ground_force_1_v"
%   PointPrefix          "ground_force_1_p"
%   ForceMagnitudeTolerance 1e-8
%   ThrowOnFailure       true

    defaults = hsf.defaultParameters();

    parser = inputParser;
    parser.FunctionName = "hsf.validateMotion";

    addRequired(parser, "motionInput");
    addParameter(parser, "ExpectedRateHz", defaults.TargetRateHz, ...
        @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(parser, "ForcePrefix", defaults.ForcePrefix, ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, "PointPrefix", defaults.PointPrefix, ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, "ForceMagnitudeTolerance", 1e-8, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(parser, "ThrowOnFailure", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, motionInput, varargin{:});

    if ischar(motionInput) || ...
            (isstring(motionInput) && isscalar(motionInput))
        motion = opensimio.readMot(motionInput);
    elseif isstruct(motionInput) && ...
            all(isfield(motionInput, ["Labels", "Data", "Time"]))
        motion = motionInput;
    else
        error("hsf:InvalidMotionInput", ...
            "motionInput must be a .mot path or parsed motion structure.");
    end

    issues = strings(0,1);
    labels = string(motion.Labels);
    forcePrefix = string(parser.Results.ForcePrefix);
    pointPrefix = string(parser.Results.PointPrefix);

    requiredLabels = [ ...
        "time", ...
        forcePrefix+"x", forcePrefix+"y", forcePrefix+"z", ...
        pointPrefix+"x", pointPrefix+"y", pointPrefix+"z"];

    missing = setdiff(requiredLabels, labels, "stable");

    if ~isempty(missing)
        issues(end+1,1) = ...
            "Missing labels: " + strjoin(missing, ", "); %#ok<AGROW>
    end

    time = double(motion.Time(:));

    if any(diff(time) <= 0)
        issues(end+1,1) = ...
            "Time values are not strictly increasing."; %#ok<AGROW>
        estimatedRate = NaN;
    else
        dt = diff(time);
        estimatedRate = 1 / median(dt);

        if max(abs(dt - 1/parser.Results.ExpectedRateHz)) > 1e-9
            issues(end+1,1) = ...
                "Time vector is not uniformly sampled at expected rate."; %#ok<AGROW>
        end
    end

    if any(~isfinite(motion.Data), "all")
        issues(end+1,1) = ...
            "Motion data contain non-finite values."; %#ok<AGROW>
    end

    if isempty(missing)
        forceIndices = zeros(1,3);
        pointIndices = zeros(1,3);
        axes = ["x","y","z"];

        for axisIndex = 1:3
            forceIndices(axisIndex) = ...
                find(labels == forcePrefix+axes(axisIndex), 1);
            pointIndices(axisIndex) = ...
                find(labels == pointPrefix+axes(axisIndex), 1);
        end

        forceData = motion.Data(:, forceIndices);
        pointData = motion.Data(:, pointIndices);

        if any(~isfinite(forceData), "all")
            issues(end+1,1) = ...
                "Force data contain non-finite values."; %#ok<AGROW>
        end

        if any(~isfinite(pointData), "all")
            issues(end+1,1) = ...
                "Application-point data contain non-finite values."; %#ok<AGROW>
        end

        forceMagnitudes = vecnorm(forceData, 2, 2);
        maximumForceMagnitude = max(forceMagnitudes);
        minimumForceMagnitude = min(forceMagnitudes);

        nonzeroMask = forceMagnitudes > ...
            parser.Results.ForceMagnitudeTolerance;

        if any(nonzeroMask)
            activeMagnitudeRange = ...
                max(forceMagnitudes(nonzeroMask)) - ...
                min(forceMagnitudes(nonzeroMask));
        else
            activeMagnitudeRange = 0;
        end
    else
        maximumForceMagnitude = NaN;
        minimumForceMagnitude = NaN;
        activeMagnitudeRange = NaN;
    end

    report = struct;
    report.Passed = isempty(issues);
    report.Issues = issues;
    report.NumRows = size(motion.Data,1);
    report.NumColumns = size(motion.Data,2);
    report.EstimatedRateHz = estimatedRate;
    report.MaximumForceMagnitudeN = maximumForceMagnitude;
    report.MinimumForceMagnitudeN = minimumForceMagnitude;
    report.ActiveForceMagnitudeRangeN = activeMagnitudeRange;

    if ~report.Passed && parser.Results.ThrowOnFailure
        error("hsf:MotionValidationFailed", ...
            "%s", strjoin(issues, newline));
    end
end
