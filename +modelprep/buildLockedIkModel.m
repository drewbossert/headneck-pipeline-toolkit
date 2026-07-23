function result = buildLockedIkModel( ...
        baseModelFile, lockValues, outputModelFile, varargin)
%BUILDLOCKEDIKMODEL Create Model B for constrained final IK.
%
% result = modelprep.buildLockedIkModel( ...
%     baseModelFile, lockValues, outputModelFile)
%
% lockValues is normally returned by extractStableCoordinateValues() and
% must contain Coordinate and ValueSI.
%
% By default, exactly the root plus independent out-of-plane coordinates
% are locked. Dependent auxiliary r1/r2 coordinates remain unlocked and are
% governed by enabled coordinate-coupler constraints.
%
% Name-value options:
%   CoordinateNames  default coordinateGroups().FinalIkLocked
%   RequireStable    true

    parser = inputParser;
    parser.FunctionName = "modelprep.buildLockedIkModel";

    addRequired(parser, "baseModelFile");
    addRequired(parser, "lockValues", @istable);
    addRequired(parser, "outputModelFile");

    groups = modelprep.coordinateGroups();

    addParameter(parser, "CoordinateNames", ...
        groups.FinalIkLocked, ...
        @(x) ischar(x) || isstring(x) || iscellstr(x));

    addParameter(parser, "RequireStable", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, baseModelFile, lockValues, ...
        outputModelFile, varargin{:});

    coordinateNames = string(parser.Results.CoordinateNames);
    coordinateNames = coordinateNames(:);

    requiredColumns = ["Coordinate", "ValueSI"];

    if ~all(ismember(requiredColumns, ...
            string(lockValues.Properties.VariableNames)))
        error("modelprep:InvalidLockValues", ...
            "lockValues must contain Coordinate and ValueSI.");
    end

    if parser.Results.RequireStable && ...
            ismember("IsStable", ...
            string(lockValues.Properties.VariableNames)) && ...
            any(~lockValues.IsStable( ...
            ismember(string(lockValues.Coordinate), coordinateNames)))
        error("modelprep:UnstableLockValues", ...
            "One or more requested locking coordinates are unstable.");
    end

    selected = lockValues( ...
        ismember(string(lockValues.Coordinate), coordinateNames), :);

    missing = setdiff( ...
        coordinateNames, string(selected.Coordinate), "stable");

    if ~isempty(missing)
        error("modelprep:MissingLockValues", ...
            "Lock values are missing for: %s", ...
            strjoin(missing, ", "));
    end

    [model, unlockReport] = modelprep.unlockAllCoordinates( ...
        baseModelFile, ...
        "ClearPrescribed", true);

    [model, constraintReport] = ...
        modelprep.setConstraintEnforcement(model, true);

    configuration = modelprep.makeLockConfiguration(selected);

    [model, coordinateReport] = ...
        modelprep.applyCoordinateConfiguration( ...
        model, configuration);

    modelprep.saveModel(model, outputModelFile);
    inspection = modelprep.inspectModel(outputModelFile);

    result = struct;
    result.OutputModelFile = string(outputModelFile);
    result.LockValues = selected;
    result.UnlockReport = unlockReport;
    result.ConstraintReport = constraintReport;
    result.CoordinateReport = coordinateReport;
    result.Inspection = inspection;
end
