function headerLines = buildOpenSimHeader( ...
        existingHeaderLines, name, nRows, nColumns, inDegrees)
%BUILDOPENSIMHEADER Preserve and update an OpenSim table header.

    existingHeaderLines = string(existingHeaderLines);
    existingHeaderLines = existingHeaderLines(:);

    if isempty(existingHeaderLines)
        headerLines = string(name);
    else
        headerLines = existingHeaderLines;

        endHeaderMask = strcmpi(strtrim(headerLines), "endheader");
        headerLines(endHeaderMask) = [];
        headerLines(strlength(strtrim(headerLines)) == 0) = [];

        if isempty(headerLines)
            headerLines = string(name);
        end
    end

    headerLines = setMetadataLine( ...
        headerLines, ["nRows", "datarows"], ...
        "nRows=" + string(nRows));

    headerLines = setMetadataLine( ...
        headerLines, ["nColumns", "datacolumns"], ...
        "nColumns=" + string(nColumns));

    if ~(isnumeric(inDegrees) && isnan(inDegrees))
        if logical(inDegrees)
            inDegreesText = "yes";
        else
            inDegreesText = "no";
        end

        headerLines = setMetadataLine( ...
            headerLines, "inDegrees", ...
            "inDegrees=" + inDegreesText);
    end

    headerLines(end+1,1) = "endheader";
end

function lines = setMetadataLine(lines, keyAliases, replacementLine)

    keyAliases = lower(string(keyAliases));
    matchIndex = [];

    for lineIndex = 1:numel(lines)

        line = strtrim(lines(lineIndex));

        equalsTokens = regexp( ...
            char(line), ...
            '^\s*([^=]+?)\s*=', ...
            'tokens', ...
            'once');

        if ~isempty(equalsTokens)
            candidateKey = lower(string(strtrim(equalsTokens{1})));
        else
            spaceTokens = regexp( ...
                char(line), ...
                '^\s*(\S+)\s+', ...
                'tokens', ...
                'once');

            if isempty(spaceTokens)
                continue;
            end

            candidateKey = lower(string(spaceTokens{1}));
        end

        if ismember(candidateKey, keyAliases)
            matchIndex = lineIndex;
            break;
        end
    end

    if isempty(matchIndex)
        lines(end+1,1) = replacementLine;
    else
        lines(matchIndex) = replacementLine;
    end
end
