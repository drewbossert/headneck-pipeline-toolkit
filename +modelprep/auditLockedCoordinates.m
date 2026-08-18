function report = auditLockedCoordinates( ...
        motionInput, lockValues, varargin)
%AUDITLOCKEDCOORDINATES Verify locked coordinates in an IK motion file.
%
% report = modelprep.auditLockedCoordinates(motionInput, lockValues)
%
% motionInput may be a .mot path or a structure returned by
% opensimio.readMot().
%
% lockValues must be a table containing:
%   Coordinate
% and one expected-value variable named:
%   ValueSI, DefaultValueSI, or ExpectedValueSI
%
% CoordinateType is optional. When it is absent, the function uses
% ModelInput when supplied and otherwise applies a conservative coordinate-
% name classification.
%
% If lockValues contains a Locked variable, only rows with Locked=true are
% audited by default.
%
% Name-value options:
%   ModelInput                    ""
%   TimeWindow                   [] (entire motion)
%   Statistic                    "median" or "mean"
%   AuditOnlyLocked              true
%   RotationRangeToleranceDeg    1e-6
%   TranslationRangeToleranceM   1e-10
%   OtherRangeToleranceSI        1e-10
%   RotationMatchToleranceDeg    1e-5
%   TranslationMatchToleranceM   1e-9
%   OtherMatchToleranceSI        1e-9
%   MinimumSamples               2
%   RequirePass                  false
%
% Returned structure fields:
%   Table
%   Passed
%   NumCoordinates
%   NumPassed
%   NumFailed
%   FailedCoordinates
%   TimeWindow
%   Statistic
%   Tolerances
%
% The Table field contains expected and observed values in both OpenSim SI
% units and display units. Rotations are displayed in degrees; translations
% remain in meters.

    parser = inputParser;
    parser.FunctionName = "modelprep.auditLockedCoordinates";

    addRequired(parser, "motionInput");
    addRequired(parser, "lockValues", @istable);

    addParameter(parser, "ModelInput", "");

    addParameter(parser, "TimeWindow", [], ...
        @(x) isempty(x) || ...
        (isnumeric(x) && numel(x) == 2 && ...
        all(isfinite(x)) && x(2) >= x(1)));

    addParameter(parser, "Statistic", "median", ...
        @(x) any(strcmpi(string(x), ["median", "mean"])));

    addParameter(parser, "AuditOnlyLocked", true, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "RotationRangeToleranceDeg", 1e-6, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);

    addParameter(parser, "TranslationRangeToleranceM", 1e-10, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);

    addParameter(parser, "OtherRangeToleranceSI", 1e-10, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);

    addParameter(parser, "RotationMatchToleranceDeg", 1e-5, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);

    addParameter(parser, "TranslationMatchToleranceM", 1e-9, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);

    addParameter(parser, "OtherMatchToleranceSI", 1e-9, ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);

    addParameter(parser, "MinimumSamples", 2, ...
        @(x) isnumeric(x) && isscalar(x) && ...
        isfinite(x) && x >= 1 && mod(x,1) == 0);

    addParameter(parser, "RequirePass", false, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, motionInput, lockValues, varargin{:});

    motion = opensimio.resolveMotion(motionInput);
    lockValues = selectAuditRows( ...
        lockValues, parser.Results.AuditOnlyLocked);

    variableNames = string(lockValues.Properties.VariableNames);

    if ~ismember("Coordinate", variableNames)
        error("modelprep:MissingCoordinateColumn", ...
            "lockValues must contain a Coordinate variable.");
    end

    expectedVariable = selectExpectedVariable(variableNames);

    Coordinate = string(lockValues.Coordinate);
    Coordinate = Coordinate(:);

    if isempty(Coordinate)
        error("modelprep:NoLockedCoordinates", ...
            "No coordinates were selected for the lock audit.");
    end

    if numel(unique(Coordinate)) ~= numel(Coordinate)
        error("modelprep:DuplicateLockCoordinates", ...
            "lockValues contains duplicate coordinate names.");
    end

    ExpectedValueSI = double(lockValues.(expectedVariable));
    ExpectedValueSI = ExpectedValueSI(:);

    if any(~isfinite(ExpectedValueSI))
        invalid = Coordinate(~isfinite(ExpectedValueSI));

        error("modelprep:InvalidExpectedLockValue", ...
            "Non-finite expected value(s) for: %s", ...
            strjoin(invalid, ", "));
    end

    CoordinateType = resolveCoordinateTypes( ...
        Coordinate, lockValues, variableNames, ...
        parser.Results.ModelInput);

    normalizedLabels = strings(size(motion.Labels));

    for labelIndex = 1:numel(motion.Labels)
        normalizedLabels(labelIndex) = ...
            opensimio.normalizeMotionLabel( ...
            motion.Labels(labelIndex));
    end

    if numel(unique(normalizedLabels)) ~= numel(normalizedLabels)
        error("modelprep:DuplicateMotionLabels", ...
            "Motion labels are not unique after path normalization.");
    end

    if isempty(parser.Results.TimeWindow)
        timeWindow = [motion.Time(1), motion.Time(end)];
    else
        timeWindow = double(parser.Results.TimeWindow(:)).';
    end

    windowMask = motion.Time >= timeWindow(1) & ...
        motion.Time <= timeWindow(2);

    numberOfWindowSamples = sum(windowMask);

    if numberOfWindowSamples < parser.Results.MinimumSamples
        error("modelprep:InsufficientAuditSamples", ...
            ["Only %d samples lie in the audit window " ...
             "[%.9g, %.9g] s."], ...
            numberOfWindowSamples, timeWindow(1), timeWindow(2));
    end

    statistic = lower(string(parser.Results.Statistic));
    nCoordinates = numel(Coordinate);

    Statistic = repmat(statistic, nCoordinates, 1);
    WindowStart = repmat(timeWindow(1), nCoordinates, 1);
    WindowEnd = repmat(timeWindow(2), nCoordinates, 1);
    NumSamples = repmat(numberOfWindowSamples, nCoordinates, 1);
    NumNonfiniteSamples = zeros(nCoordinates, 1);

    ExpectedValueDisplay = nan(nCoordinates, 1);
    ObservedStatisticSI = nan(nCoordinates, 1);
    ObservedStatisticDisplay = nan(nCoordinates, 1);
    DifferenceSI = nan(nCoordinates, 1);
    DifferenceDisplay = nan(nCoordinates, 1);
    AbsoluteDifferenceDisplay = nan(nCoordinates, 1);
    ObservedMinimumDisplay = nan(nCoordinates, 1);
    ObservedMaximumDisplay = nan(nCoordinates, 1);
    ObservedRangeDisplay = nan(nCoordinates, 1);
    ObservedStandardDeviationDisplay = nan(nCoordinates, 1);
    DisplayUnit = strings(nCoordinates, 1);
    RangeToleranceDisplay = nan(nCoordinates, 1);
    MatchToleranceDisplay = nan(nCoordinates, 1);
    NoNonfiniteSamples = false(nCoordinates, 1);
    ConstantWithinTolerance = false(nCoordinates, 1);
    MatchesExpectedValue = false(nCoordinates, 1);
    Passed = false(nCoordinates, 1);

    for coordinateIndex = 1:nCoordinates
        coordinateName = Coordinate(coordinateIndex);

        motionIndex = find( ...
            normalizedLabels == coordinateName, 1);

        if isempty(motionIndex)
            error("modelprep:MissingMotionCoordinate", ...
                "Coordinate '%s' is not present in the motion file.", ...
                coordinateName);
        end

        rawValues = motion.Data(windowMask, motionIndex);
        coordinateType = CoordinateType(coordinateIndex);

        observedValuesSI = ...
            modelprep.internal.motionValuesToSI( ...
            rawValues, coordinateType, motion.InDegrees);

        finiteMask = isfinite(observedValuesSI);
        NumNonfiniteSamples(coordinateIndex) = sum(~finiteMask);
        NoNonfiniteSamples(coordinateIndex) = all(finiteMask);

        if ~any(finiteMask)
            continue;
        end

        finiteValuesSI = observedValuesSI(finiteMask);

        switch statistic
            case "median"
                observedStatisticSI = median(finiteValuesSI);
            case "mean"
                observedStatisticSI = mean(finiteValuesSI);
        end

        displayValues = modelprep.internal.siToDisplay( ...
            finiteValuesSI, coordinateType);

        expectedValueDisplay = modelprep.internal.siToDisplay( ...
            ExpectedValueSI(coordinateIndex), coordinateType);

        observedStatisticDisplay = ...
            modelprep.internal.siToDisplay( ...
            observedStatisticSI, coordinateType);

        differenceSI = observedStatisticSI - ...
            ExpectedValueSI(coordinateIndex);

        differenceDisplay = modelprep.internal.siToDisplay( ...
            differenceSI, coordinateType);

        [displayUnit, rangeTolerance, matchTolerance] = ...
            selectTolerances(coordinateType, parser.Results);

        observedRange = max(displayValues) - min(displayValues);

        ExpectedValueDisplay(coordinateIndex) = ...
            expectedValueDisplay;
        ObservedStatisticSI(coordinateIndex) = ...
            observedStatisticSI;
        ObservedStatisticDisplay(coordinateIndex) = ...
            observedStatisticDisplay;
        DifferenceSI(coordinateIndex) = differenceSI;
        DifferenceDisplay(coordinateIndex) = differenceDisplay;
        AbsoluteDifferenceDisplay(coordinateIndex) = ...
            abs(differenceDisplay);
        ObservedMinimumDisplay(coordinateIndex) = ...
            min(displayValues);
        ObservedMaximumDisplay(coordinateIndex) = ...
            max(displayValues);
        ObservedRangeDisplay(coordinateIndex) = observedRange;
        ObservedStandardDeviationDisplay(coordinateIndex) = ...
            std(displayValues);
        DisplayUnit(coordinateIndex) = displayUnit;
        RangeToleranceDisplay(coordinateIndex) = rangeTolerance;
        MatchToleranceDisplay(coordinateIndex) = matchTolerance;
        ConstantWithinTolerance(coordinateIndex) = ...
            observedRange <= rangeTolerance;
        MatchesExpectedValue(coordinateIndex) = ...
            abs(differenceDisplay) <= matchTolerance;
        Passed(coordinateIndex) = ...
            NoNonfiniteSamples(coordinateIndex) && ...
            ConstantWithinTolerance(coordinateIndex) && ...
            MatchesExpectedValue(coordinateIndex);
    end

    auditTable = table( ...
        Coordinate, CoordinateType, Statistic, ...
        WindowStart, WindowEnd, NumSamples, ...
        NumNonfiniteSamples, ExpectedValueSI, ...
        ExpectedValueDisplay, ObservedStatisticSI, ...
        ObservedStatisticDisplay, DifferenceSI, ...
        DifferenceDisplay, AbsoluteDifferenceDisplay, ...
        ObservedMinimumDisplay, ObservedMaximumDisplay, ...
        ObservedRangeDisplay, ...
        ObservedStandardDeviationDisplay, DisplayUnit, ...
        RangeToleranceDisplay, MatchToleranceDisplay, ...
        NoNonfiniteSamples, ConstantWithinTolerance, ...
        MatchesExpectedValue, Passed, ...
        'VariableNames', { ...
            'Coordinate', 'CoordinateType', 'Statistic', ...
            'WindowStart', 'WindowEnd', 'NumSamples', ...
            'NumNonfiniteSamples', 'ExpectedValueSI', ...
            'ExpectedValueDisplay', 'ObservedStatisticSI', ...
            'ObservedStatisticDisplay', 'DifferenceSI', ...
            'DifferenceDisplay', 'AbsoluteDifferenceDisplay', ...
            'ObservedMinimumDisplay', 'ObservedMaximumDisplay', ...
            'ObservedRangeDisplay', ...
            'ObservedStandardDeviationDisplay', 'DisplayUnit', ...
            'RangeToleranceDisplay', 'MatchToleranceDisplay', ...
            'NoNonfiniteSamples', 'ConstantWithinTolerance', ...
            'MatchesExpectedValue', 'Passed'});

    report = struct;
    report.Table = auditTable;
    report.Passed = all(auditTable.Passed);
    report.NumCoordinates = height(auditTable);
    report.NumPassed = sum(auditTable.Passed);
    report.NumFailed = sum(~auditTable.Passed);
    report.FailedCoordinates = ...
        auditTable.Coordinate(~auditTable.Passed);
    report.TimeWindow = timeWindow;
    report.Statistic = statistic;
    report.ExpectedValueVariable = expectedVariable;
    report.Tolerances = struct( ...
        "RotationRangeToleranceDeg", ...
            parser.Results.RotationRangeToleranceDeg, ...
        "TranslationRangeToleranceM", ...
            parser.Results.TranslationRangeToleranceM, ...
        "OtherRangeToleranceSI", ...
            parser.Results.OtherRangeToleranceSI, ...
        "RotationMatchToleranceDeg", ...
            parser.Results.RotationMatchToleranceDeg, ...
        "TranslationMatchToleranceM", ...
            parser.Results.TranslationMatchToleranceM, ...
        "OtherMatchToleranceSI", ...
            parser.Results.OtherMatchToleranceSI);

    if ~report.Passed && parser.Results.RequirePass
        failed = report.FailedCoordinates;

        error("modelprep:LockedCoordinateAuditFailed", ...
            "Locked-coordinate audit failed for: %s", ...
            strjoin(failed, ", "));
    end
end

function selected = selectAuditRows(lockValues, auditOnlyLocked)

    variableNames = string(lockValues.Properties.VariableNames);

    if auditOnlyLocked && ismember("Locked", variableNames)
        selected = lockValues(logical(lockValues.Locked), :);
    else
        selected = lockValues;
    end
end

function expectedVariable = selectExpectedVariable(variableNames)

    candidates = [ ...
        "ExpectedValueSI"
        "DefaultValueSI"
        "ValueSI"
    ];

    match = candidates(ismember(candidates, variableNames));

    if isempty(match)
        error("modelprep:MissingExpectedValueColumn", ...
            ["lockValues must contain ExpectedValueSI, " ...
             "DefaultValueSI, or ValueSI."]);
    end

    expectedVariable = match(1);
end

function coordinateTypes = resolveCoordinateTypes( ...
        coordinateNames, lockValues, variableNames, modelInput)

    nCoordinates = numel(coordinateNames);
    coordinateTypes = strings(nCoordinates, 1);

    if ismember("CoordinateType", variableNames)
        coordinateTypes = lower(string(lockValues.CoordinateType));
        coordinateTypes = coordinateTypes(:);
    end

    missingType = strlength(coordinateTypes) == 0 | ...
        ~ismember(coordinateTypes, ...
        ["rotation", "translation", "other"]);

    if any(missingType) && hasModelInput(modelInput)
        modelReport = modelprep.inspectModel(modelInput);

        for index = find(missingType).'
            modelRow = find( ...
                modelReport.Coordinates.Coordinate == ...
                coordinateNames(index), 1);

            if isempty(modelRow)
                error("modelprep:MissingModelCoordinate", ...
                    "Coordinate '%s' is not present in the model.", ...
                    coordinateNames(index));
            end

            coordinateTypes(index) = ...
                modelReport.Coordinates.CoordinateType(modelRow);
        end

        missingType = strlength(coordinateTypes) == 0 | ...
            ~ismember(coordinateTypes, ...
            ["rotation", "translation", "other"]);
    end

    for index = find(missingType).'
        coordinateTypes(index) = inferTypeFromName( ...
            coordinateNames(index));
    end
end

function coordinateType = inferTypeFromName(coordinateName)

    coordinateName = lower(string(coordinateName));

    if contains(coordinateName, "pitch") || ...
            contains(coordinateName, "roll") || ...
            contains(coordinateName, "yaw") || ...
            ~isempty(regexp(coordinateName, "_r[123]$", "once"))
        coordinateType = "rotation";
    elseif endsWith(coordinateName, "_tx") || ...
            endsWith(coordinateName, "_ty") || ...
            endsWith(coordinateName, "_tz")
        coordinateType = "translation";
    else
        coordinateType = "other";
    end
end

function tf = hasModelInput(modelInput)

    if ischar(modelInput)
        tf = ~isempty(modelInput);
    elseif isstring(modelInput)
        tf = isscalar(modelInput) && strlength(modelInput) > 0;
    else
        tf = isa(modelInput, "org.opensim.modeling.Model");
    end
end

function [unit, rangeTolerance, matchTolerance] = ...
        selectTolerances(coordinateType, options)

    switch coordinateType
        case "rotation"
            unit = "deg";
            rangeTolerance = ...
                options.RotationRangeToleranceDeg;
            matchTolerance = ...
                options.RotationMatchToleranceDeg;
        case "translation"
            unit = "m";
            rangeTolerance = ...
                options.TranslationRangeToleranceM;
            matchTolerance = ...
                options.TranslationMatchToleranceM;
        otherwise
            unit = "SI";
            rangeTolerance = ...
                options.OtherRangeToleranceSI;
            matchTolerance = ...
                options.OtherMatchToleranceSI;
    end
end
