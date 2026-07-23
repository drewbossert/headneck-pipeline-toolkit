function value = getUnmatchedOption(inputStruct, fieldName, defaultValue)
%GETUNMATCHEDOPTION Retrieve an unmatched parser option.

    if isfield(inputStruct, fieldName)
        value = inputStruct.(fieldName);
    else
        value = defaultValue;
    end
end
