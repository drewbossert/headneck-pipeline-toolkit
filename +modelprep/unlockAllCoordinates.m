function [model, report] = unlockAllCoordinates(modelInput, varargin)
%UNLOCKALLCOORDINATES Clear default coordinate locking.
%
% [model, report] = modelprep.unlockAllCoordinates(modelInput)
%
% Name-value options:
%   ClearPrescribed  false (default)
%   ClearClamped     false (default)
%
% Property changes are written into the model object. The returned report
% records the previous and resulting default settings.

    parser = inputParser;
    parser.FunctionName = "modelprep.unlockAllCoordinates";

    addRequired(parser, "modelInput");
    addParameter(parser, "ClearPrescribed", false, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, "ClearClamped", false, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, modelInput, varargin{:});

    model = modelprep.internal.resolveModel(modelInput);
    coordinateSet = model.getCoordinateSet();
    nCoordinates = coordinateSet.getSize();

    Coordinate = strings(nCoordinates, 1);
    PreviousLocked = false(nCoordinates, 1);
    NewLocked = false(nCoordinates, 1);
    PreviousPrescribed = false(nCoordinates, 1);
    NewPrescribed = false(nCoordinates, 1);
    PreviousClamped = false(nCoordinates, 1);
    NewClamped = false(nCoordinates, 1);

    for index = 0:nCoordinates-1
        coordinate = coordinateSet.get(index);
        row = index + 1;

        Coordinate(row) = modelprep.internal.osimString( ...
            coordinate.getName());

        PreviousLocked(row) = ...
            logical(coordinate.getDefaultLocked());
        PreviousPrescribed(row) = ...
            logical(coordinate.getDefaultIsPrescribed());
        PreviousClamped(row) = ...
            logical(coordinate.getDefaultClamped());

        coordinate.setDefaultLocked(false);

        if parser.Results.ClearPrescribed
            coordinate.setDefaultIsPrescribed(false);
        end

        if parser.Results.ClearClamped
            coordinate.setDefaultClamped(false);
        end

        NewLocked(row) = ...
            logical(coordinate.getDefaultLocked());
        NewPrescribed(row) = ...
            logical(coordinate.getDefaultIsPrescribed());
        NewClamped(row) = ...
            logical(coordinate.getDefaultClamped());
    end

    [model, ~] = modelprep.internal.finalizeAndInitialize(model);

    report = table( ...
        Coordinate, ...
        PreviousLocked, NewLocked, ...
        PreviousPrescribed, NewPrescribed, ...
        PreviousClamped, NewClamped, ...
        'VariableNames', { ...
            'Coordinate', ...
            'PreviousLocked', 'NewLocked', ...
            'PreviousPrescribed', 'NewPrescribed', ...
            'PreviousClamped', 'NewClamped'});
end
