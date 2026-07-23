function [headerLines, labelLineIndex] = ...
        locateOpenSimTableSections(lines, filePath)
%LOCATEOPENSIMTABLESECTIONS Locate header and column-label row.

    trimmedLines = strtrim(lines);
    endHeaderIndex = find( ...
        strcmpi(trimmedLines, "endheader"), ...
        1, ...
        "first");

    if ~isempty(endHeaderIndex)
        headerLines = lines(1:endHeaderIndex);
        labelLineIndex = endHeaderIndex + 1;

        while labelLineIndex <= numel(lines) && ...
                strlength(strtrim(lines(labelLineIndex))) == 0
            labelLineIndex = labelLineIndex + 1;
        end

        if labelLineIndex > numel(lines)
            error("opensimio:MissingLabels", ...
                "No column-label row follows endheader in:\n%s", ...
                filePath);
        end

        return;
    end

    labelLineIndex = [];

    for lineIndex = 1:numel(lines)
        candidate = strtrim(lines(lineIndex));

        if startsWith(lower(candidate), "time") && ...
                ~contains(candidate, "=")
            candidateLabels = ...
                opensimio.internal.parseColumnLabels(candidate);

            if ~isempty(candidateLabels) && ...
                    lower(candidateLabels(1)) == "time"
                labelLineIndex = lineIndex;
                break;
            end
        end
    end

    if isempty(labelLineIndex)
        error("opensimio:MissingHeaderTerminator", ...
            ["Could not locate 'endheader' or a column-label row " ...
             "beginning with 'time' in:\n%s"], ...
            filePath);
    end

    headerLines = lines(1:labelLineIndex-1);
end
