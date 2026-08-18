function normalized = normalizeMotionLabel(label)
%NORMALIZEMOTIONLABEL Normalize an OpenSim motion-coordinate label.
%
% normalized = opensimio.normalizeMotionLabel(label)
%
% INPUT
%   label
%       Character vector or scalar string containing either:
%           - "time";
%           - a bare coordinate name; or
%           - a full OpenSim coordinate path, optionally ending in /value.
%
% OUTPUT
%   normalized
%       Scalar string containing:
%           - "time" for the time column; or
%           - the final coordinate-name component of the input path.
%
% Examples:
%   opensimio.normalizeMotionLabel("time")
%       -> "time"
%
%   opensimio.normalizeMotionLabel( ...
%       "/jointset/c1c2/pitch1/value")
%       -> "pitch1"
%
% This helper centralizes the OpenSim motion-label normalization used by
% multiple packages.

    assert( ...
        ischar(label) || ...
        (isstring(label) && isscalar(label)), ...
        "opensimio:InvalidMotionLabel", ...
        "label must be a character vector or scalar string.");

    normalized = ...
        strtrim( ...
            string(label));

    if lower(normalized) == "time"

        normalized = ...
            "time";

        return;
    end

    normalized = ...
        regexprep( ...
            normalized, ...
            "/value$", ...
            "");

    parts = ...
        split( ...
            normalized, ...
            "/");

    parts = ...
        parts(strlength(parts) > 0);

    if ~isempty(parts)

        normalized = ...
            parts(end);
    end
end
