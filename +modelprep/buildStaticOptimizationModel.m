function result = buildStaticOptimizationModel( ...
        constrainedIkModelFile, finalIkMotionFile, ...
        outputModelFile, varargin)
%BUILDSTATICOPTIMIZATIONMODEL Create Model C for Static Optimization.
%
% result = modelprep.buildStaticOptimizationModel( ...
%     constrainedIkModelFile, finalIkMotionFile, outputModelFile)
%
% The function:
%   1) extracts constant root and out-of-plane values from final IK;
%   2) unlocks all coordinates;
%   3) disables all constraints;
%   4) locks root and all out-of-plane coordinates at extracted values; and
%   5) writes a validated .osim model.
%
% Name-value options:
%   TimeWindow             default entire final IK file
%   RotationToleranceDeg   1e-6
%   TranslationToleranceM  1e-10
%   RequireStable          true

    parser = inputParser;
    parser.FunctionName = "modelprep.buildStaticOptimizationModel";

    addRequired(parser, "constrainedIkModelFile");
    addRequired(parser, "finalIkMotionFile");
    addRequired(parser, "outputModelFile");

    addParameter(parser, "TimeWindow", [], ...
        @(x) isempty(x) || ...
        (isnumeric(x) && numel(x) == 2 && x(2) >= x(1)));

    addParameter(parser, "RotationToleranceDeg", 1e-6, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 0);

    addParameter(parser, "TranslationToleranceM", 1e-10, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 0);

    addParameter(parser, "RequireStable", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, constrainedIkModelFile, ...
        finalIkMotionFile, outputModelFile, varargin{:});

    motion = opensimio.readMot(finalIkMotionFile);

    if isempty(parser.Results.TimeWindow)
        timeWindow = [motion.Time(1), motion.Time(end)];
    else
        timeWindow = parser.Results.TimeWindow;
    end

    groups = modelprep.coordinateGroups();

    lockValues = modelprep.extractStableCoordinateValues( ...
        motion, constrainedIkModelFile, ...
        groups.StaticOptimizationLocked, timeWindow, ...
        "Method", "median", ...
        "RotationToleranceDeg", ...
        parser.Results.RotationToleranceDeg, ...
        "TranslationToleranceM", ...
        parser.Results.TranslationToleranceM, ...
        "RequireStable", parser.Results.RequireStable);

    [model, unlockReport] = modelprep.unlockAllCoordinates( ...
        constrainedIkModelFile, ...
        "ClearPrescribed", true);

    [model, constraintReport] = ...
        modelprep.setConstraintEnforcement(model, false);

    configuration = modelprep.makeLockConfiguration(lockValues);

    [model, coordinateReport] = ...
        modelprep.applyCoordinateConfiguration( ...
        model, configuration);

    modelprep.saveModel(model, outputModelFile);
    inspection = modelprep.inspectModel(outputModelFile);

    result = struct;
    result.OutputModelFile = string(outputModelFile);
    result.LockValues = lockValues;
    result.UnlockReport = unlockReport;
    result.ConstraintReport = constraintReport;
    result.CoordinateReport = coordinateReport;
    result.Inspection = inspection;
end
