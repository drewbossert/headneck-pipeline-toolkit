function value = readLogicalMetadata(metadata, key, defaultValue)
%READLOGICALMETADATA Read yes/no metadata as logical or default.

    value = defaultValue;

    if isempty(metadata)
        return;
    end

    matchIndex = find( ...
        strcmpi(metadata.Key, string(key)), ...
        1, ...
        "last");

    if isempty(matchIndex)
        return;
    end

    rawValue = lower(strtrim(metadata.Value(matchIndex)));

    if any(rawValue == ["yes", "true", "1"])
        value = true;
    elseif any(rawValue == ["no", "false", "0"])
        value = false;
    end
end
