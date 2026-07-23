function normalized = normalizeStorageLabel(label)
%NORMALIZESTORAGELABEL Normalize a BodyKinematics storage label.

    normalized = strtrim(string(label));
    normalized = replace(normalized, "\", "/");
    parts = split(normalized, "/");
    parts = parts(strlength(parts) > 0);

    if ~isempty(parts)
        normalized = parts(end);
    end
end
