function labelIndex = findAxisLabel(labels, bodyName, axisName)
%FINDAXISLABEL Find body_X/body_Y/body_Z labels case-insensitively.

    labels = lower(string(labels));
    bodyName = lower(string(bodyName));
    axisName = lower(string(axisName));

    exactCandidates = [ ...
        bodyName + "_" + axisName, ...
        bodyName + "." + axisName, ...
        bodyName + "-" + axisName];

    labelIndex = find(ismember(labels, exactCandidates), 1);

    if ~isempty(labelIndex)
        return;
    end

    suffix = bodyName + "_" + axisName;
    labelIndex = find(endsWith(labels, suffix), 1);

    if isempty(labelIndex)
        error("hsf:BodyComAxisNotFound", ...
            ["Could not find the %s-axis position label for body '%s'. " ...
             "Available labels include: %s"], ...
            upper(axisName), bodyName, ...
            strjoin(labels(1:min(12,numel(labels))), ", "));
    end
end
