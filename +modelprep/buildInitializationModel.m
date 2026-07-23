function result = buildInitializationModel( ...
        baseModelFile, outputModelFile, varargin)
%BUILDINITIALIZATIONMODEL Create Model A for initialization IK.
%
% result = modelprep.buildInitializationModel( ...
%     baseModelFile, outputModelFile)
%
% The resulting model has:
%   - all coordinates unlocked;
%   - prescribed-coordinate flags cleared by default; and
%   - all constraints enabled.
%
% Name-value option:
%   ClearClamped  false

    parser = inputParser;
    parser.FunctionName = "modelprep.buildInitializationModel";

    addRequired(parser, "baseModelFile");
    addRequired(parser, "outputModelFile");

    addParameter(parser, "ClearClamped", false, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, baseModelFile, outputModelFile, varargin{:});

    [model, unlockReport] = modelprep.unlockAllCoordinates( ...
        baseModelFile, ...
        "ClearPrescribed", true, ...
        "ClearClamped", parser.Results.ClearClamped);

    [model, constraintReport] = ...
        modelprep.setConstraintEnforcement(model, true);

    modelprep.saveModel(model, outputModelFile);
    inspection = modelprep.inspectModel(outputModelFile);

    result = struct;
    result.OutputModelFile = string(outputModelFile);
    result.UnlockReport = unlockReport;
    result.ConstraintReport = constraintReport;
    result.Inspection = inspection;
end
