function labels = parseColumnLabels(labelLine)
%PARSECOLUMNLABELS Split an OpenSim table label row.

    labelLine = string(strtrim(labelLine));

    if strlength(labelLine) == 0
        labels = strings(0,1);
        return;
    end

    if contains(labelLine, sprintf('\t'))
        labels = split(labelLine, sprintf('\t'));
    elseif contains(labelLine, ",")
        labels = split(labelLine, ",");
    else
        labels = string(regexp( ...
            char(labelLine), ...
            '\s+', ...
            'split'));
    end

    labels = strtrim(labels);
    labels = labels(strlength(labels) > 0);
    labels = reshape(labels, 1, []);
end
