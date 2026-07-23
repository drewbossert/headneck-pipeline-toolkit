function normalized = normalizeMotionLabel(label)
%NORMALIZEMOTIONLABEL Convert full coordinate paths to coordinate names.

    normalized = strtrim(string(label));

    if lower(normalized) == "time"
        normalized = "time";
        return;
    end

    normalized = regexprep(normalized, "/value$", "");

    parts = split(normalized, "/");
    parts = parts(strlength(parts) > 0);

    if ~isempty(parts)
        normalized = parts(end);
    end
end
