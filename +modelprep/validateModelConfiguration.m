function result = validateModelConfiguration(modelInput, varargin)
%VALIDATEMODELCONFIGURATION Check expected locks and constraint enforcement.
%
% result = modelprep.validateModelConfiguration(modelInput)
%
% Name-value options:
%   ExpectedLocked
%   ExpectedUnlocked
%   ExpectedConstraintsEnforced  [] (do not check), true, or false
%   ThrowOnFailure              true

    parser = inputParser;
    parser.FunctionName = "modelprep.validateModelConfiguration";

    addRequired(parser, "modelInput");

    addParameter(parser, "ExpectedLocked", strings(0,1), ...
        @(x) ischar(x) || isstring(x) || iscellstr(x));

    addParameter(parser, "ExpectedUnlocked", strings(0,1), ...
        @(x) ischar(x) || isstring(x) || iscellstr(x));

    addParameter(parser, "ExpectedConstraintsEnforced", [], ...
        @(x) isempty(x) || (islogical(x) && isscalar(x)));

    addParameter(parser, "ThrowOnFailure", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, modelInput, varargin{:});

    report = modelprep.inspectModel(modelInput);
    issues = strings(0,1);

    expectedLocked = string(parser.Results.ExpectedLocked);
    expectedLocked = expectedLocked(:);

    expectedUnlocked = string(parser.Results.ExpectedUnlocked);
    expectedUnlocked = expectedUnlocked(:);

    for coordinateName = expectedLocked.'
        index = find( ...
            report.Coordinates.Coordinate == coordinateName, 1);

        if isempty(index)
            issues(end+1,1) = ...
                "Missing coordinate: " + coordinateName; %#ok<AGROW>
        elseif ~report.Coordinates.DefaultLocked(index)
            issues(end+1,1) = ...
                "Expected locked: " + coordinateName; %#ok<AGROW>
        end
    end

    for coordinateName = expectedUnlocked.'
        index = find( ...
            report.Coordinates.Coordinate == coordinateName, 1);

        if isempty(index)
            issues(end+1,1) = ...
                "Missing coordinate: " + coordinateName; %#ok<AGROW>
        elseif report.Coordinates.DefaultLocked(index)
            issues(end+1,1) = ...
                "Expected unlocked: " + coordinateName; %#ok<AGROW>
        end
    end

    expectedConstraints = ...
        parser.Results.ExpectedConstraintsEnforced;

    if ~isempty(expectedConstraints)
        mismatch = ...
            report.Constraints.PropertyEnforced ~= ...
            expectedConstraints;

        for constraintName = ...
                report.Constraints.Constraint(mismatch).'
            issues(end+1,1) = ...
                "Unexpected constraint enforcement: " + ...
                constraintName; %#ok<AGROW>
        end
    end

    result = struct;
    result.Passed = isempty(issues);
    result.Issues = issues;
    result.Inspection = report;

    if ~result.Passed && parser.Results.ThrowOnFailure
        error("modelprep:ConfigurationValidationFailed", ...
            "%s", strjoin(issues, newline));
    end
end
