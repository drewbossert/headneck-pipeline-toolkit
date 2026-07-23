function nameValue = structToNameValue(inputStruct)
%STRUCTTONAMEVALUE Convert a scalar structure to name-value cell array.

    fieldNames = fieldnames(inputStruct);
    nameValue = cell(1, 2 * numel(fieldNames));

    for index = 1:numel(fieldNames)
        nameValue{2*index - 1} = fieldNames{index};
        nameValue{2*index} = inputStruct.(fieldNames{index});
    end
end
