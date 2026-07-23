function [model, report] = applyCoordinateConfiguration( ...
        modelInput, configuration, varargin)
%APPLYCOORDINATECONFIGURATION Apply coordinate properties from a table.
%
% [model, report] = modelprep.applyCoordinateConfiguration( ...
%     modelInput, configuration)
%
% Required configuration variable:
%   Coordinate
%
% Optional variables:
%   DefaultValueSI
%   Locked
%   Clamped
%   Prescribed
%   RangeMinSI
%   RangeMaxSI
%
% Name-value options:
%   AllowMissing             false
%   RequireValueInsideRange  true

    parser = inputParser;
    parser.FunctionName = "modelprep.applyCoordinateConfiguration";

    addRequired(parser, "modelInput");
    addRequired(parser, "configuration", @istable);

    addParameter(parser, "AllowMissing", false, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "RequireValueInsideRange", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, modelInput, configuration, varargin{:});

    variableNames = string(configuration.Properties.VariableNames);

    if ~ismember("Coordinate", variableNames)
        error("modelprep:MissingCoordinateColumn", ...
            "configuration must contain a Coordinate variable.");
    end

    model = modelprep.internal.resolveModel(modelInput);
    coordinateSet = model.getCoordinateSet();

    nRows = height(configuration);

    Coordinate = string(configuration.Coordinate);
    Found = false(nRows, 1);
    PreviousDefaultValueSI = nan(nRows, 1);
    NewDefaultValueSI = nan(nRows, 1);
    PreviousLocked = false(nRows, 1);
    NewLocked = false(nRows, 1);
    PreviousClamped = false(nRows, 1);
    NewClamped = false(nRows, 1);
    PreviousPrescribed = false(nRows, 1);
    NewPrescribed = false(nRows, 1);
    PreviousRangeMinSI = nan(nRows, 1);
    NewRangeMinSI = nan(nRows, 1);
    PreviousRangeMaxSI = nan(nRows, 1);
    NewRangeMaxSI = nan(nRows, 1);

    for row = 1:nRows
        coordinateName = Coordinate(row);

        if ~coordinateSet.contains(char(coordinateName))
            if parser.Results.AllowMissing
                continue;
            end

            error("modelprep:MissingModelCoordinate", ...
                "Coordinate '%s' is not present in the model.", ...
                coordinateName);
        end

        Found(row) = true;
        coordinate = coordinateSet.get(char(coordinateName));

        PreviousDefaultValueSI(row) = ...
            coordinate.getDefaultValue();
        PreviousLocked(row) = ...
            logical(coordinate.getDefaultLocked());
        PreviousClamped(row) = ...
            logical(coordinate.getDefaultClamped());
        PreviousPrescribed(row) = ...
            logical(coordinate.getDefaultIsPrescribed());
        PreviousRangeMinSI(row) = coordinate.getRangeMin();
        PreviousRangeMaxSI(row) = coordinate.getRangeMax();

        if ismember("RangeMinSI", variableNames) && ...
                isfinite(configuration.RangeMinSI(row))
            coordinate.setRangeMin(configuration.RangeMinSI(row));
        end

        if ismember("RangeMaxSI", variableNames) && ...
                isfinite(configuration.RangeMaxSI(row))
            coordinate.setRangeMax(configuration.RangeMaxSI(row));
        end

        if coordinate.getRangeMin() > coordinate.getRangeMax()
            error("modelprep:InvalidCoordinateRange", ...
                "Coordinate '%s' has minimum greater than maximum.", ...
                coordinateName);
        end

        if ismember("DefaultValueSI", variableNames) && ...
                isfinite(configuration.DefaultValueSI(row))

            defaultValue = configuration.DefaultValueSI(row);

            if parser.Results.RequireValueInsideRange && ...
                    (defaultValue < coordinate.getRangeMin() || ...
                     defaultValue > coordinate.getRangeMax())
                error("modelprep:DefaultOutsideRange", ...
                    ["Default value %.12g for coordinate '%s' lies " ...
                     "outside [%.12g, %.12g]."], ...
                    defaultValue, coordinateName, ...
                    coordinate.getRangeMin(), ...
                    coordinate.getRangeMax());
            end

            coordinate.setDefaultValue(defaultValue);
        end

        if ismember("Locked", variableNames)
            coordinate.setDefaultLocked( ...
                logical(configuration.Locked(row)));
        end

        if ismember("Clamped", variableNames)
            coordinate.setDefaultClamped( ...
                logical(configuration.Clamped(row)));
        end

        if ismember("Prescribed", variableNames)
            coordinate.setDefaultIsPrescribed( ...
                logical(configuration.Prescribed(row)));
        end

        NewDefaultValueSI(row) = coordinate.getDefaultValue();
        NewLocked(row) = logical(coordinate.getDefaultLocked());
        NewClamped(row) = logical(coordinate.getDefaultClamped());
        NewPrescribed(row) = ...
            logical(coordinate.getDefaultIsPrescribed());
        NewRangeMinSI(row) = coordinate.getRangeMin();
        NewRangeMaxSI(row) = coordinate.getRangeMax();
    end

    [model, ~] = modelprep.internal.finalizeAndInitialize(model);

    report = table( ...
        Coordinate, Found, ...
        PreviousDefaultValueSI, NewDefaultValueSI, ...
        PreviousLocked, NewLocked, ...
        PreviousClamped, NewClamped, ...
        PreviousPrescribed, NewPrescribed, ...
        PreviousRangeMinSI, NewRangeMinSI, ...
        PreviousRangeMaxSI, NewRangeMaxSI, ...
        'VariableNames', { ...
            'Coordinate', 'Found', ...
            'PreviousDefaultValueSI', 'NewDefaultValueSI', ...
            'PreviousLocked', 'NewLocked', ...
            'PreviousClamped', 'NewClamped', ...
            'PreviousPrescribed', 'NewPrescribed', ...
            'PreviousRangeMinSI', 'NewRangeMinSI', ...
            'PreviousRangeMaxSI', 'NewRangeMaxSI'});
end
