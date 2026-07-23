function normalized = normalizeMotionLabel(label)
%NORMALIZEMOTIONLABEL Normalize an OpenSim coordinate label.

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
