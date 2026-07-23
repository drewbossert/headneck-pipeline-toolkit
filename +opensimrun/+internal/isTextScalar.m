function valid = isTextScalar(value)
%ISTEXTSCALAR True for scalar string or character vector.

    valid = ischar(value) || ...
        (isstring(value) && isscalar(value));
end
