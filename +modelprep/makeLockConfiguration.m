function configuration = makeLockConfiguration(valueTable)
%MAKELOCKCONFIGURATION Convert extracted values into a model configuration.
%
% configuration = modelprep.makeLockConfiguration(valueTable)
%
% valueTable must contain Coordinate and ValueSI.

    if ~istable(valueTable)
        error("modelprep:InvalidValueTable", ...
            "valueTable must be a MATLAB table.");
    end

    required = ["Coordinate", "ValueSI"];

    if ~all(ismember(required, ...
            string(valueTable.Properties.VariableNames)))
        error("modelprep:MissingValueColumns", ...
            "valueTable must contain Coordinate and ValueSI.");
    end

    Coordinate = string(valueTable.Coordinate);
    DefaultValueSI = double(valueTable.ValueSI);
    Locked = true(height(valueTable), 1);
    Clamped = false(height(valueTable), 1);
    Prescribed = false(height(valueTable), 1);

    configuration = table( ...
        Coordinate, DefaultValueSI, ...
        Locked, Clamped, Prescribed, ...
        'VariableNames', { ...
            'Coordinate', 'DefaultValueSI', ...
            'Locked', 'Clamped', 'Prescribed'});
end
