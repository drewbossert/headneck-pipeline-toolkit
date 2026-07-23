function value = getHeaderValue(tableData, key, defaultValue)
%GETHEADERVALUE Read a case-insensitive metadata value from parsed header.
%
% value = opensimio.getHeaderValue(tableData, key)
% value = opensimio.getHeaderValue(tableData, key, defaultValue)

    if nargin < 3
        defaultValue = "";
    end

    value = string(defaultValue);
    key = string(key);

    if ~isstruct(tableData) || ...
            ~isfield(tableData, "Metadata") || ...
            isempty(tableData.Metadata)
        return;
    end

    metadata = tableData.Metadata;

    if ~all(ismember(["Key", "Value"], ...
            string(metadata.Properties.VariableNames)))
        return;
    end

    matchIndex = find( ...
        strcmpi(metadata.Key, key), ...
        1, ...
        "last");

    if ~isempty(matchIndex)
        value = metadata.Value(matchIndex);
    end
end
