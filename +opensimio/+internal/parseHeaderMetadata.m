function metadata = parseHeaderMetadata(headerLines)
%PARSEHEADERMETADATA Parse key/value metadata from OpenSim header lines.

    keys = strings(0,1);
    values = strings(0,1);
    rawLines = strings(0,1);
    lineNumbers = zeros(0,1);

    recognizedSpaceSeparatedKeys = lower([ ...
        "nRows"
        "nColumns"
        "datarows"
        "datacolumns"
        "version"
        "inDegrees"
    ]);

    for lineIndex = 1:numel(headerLines)

        rawLine = string(headerLines(lineIndex));
        trimmedLine = strtrim(rawLine);

        if strlength(trimmedLine) == 0 || ...
                strcmpi(trimmedLine, "endheader")
            continue;
        end

        equalsTokens = regexp( ...
            char(trimmedLine), ...
            '^\s*([^=]+?)\s*=\s*(.*?)\s*$', ...
            'tokens', ...
            'once');

        if ~isempty(equalsTokens)
            key = string(strtrim(equalsTokens{1}));
            value = string(strtrim(equalsTokens{2}));
        else
            spaceTokens = regexp( ...
                char(trimmedLine), ...
                '^\s*(\S+)\s+(.+?)\s*$', ...
                'tokens', ...
                'once');

            if isempty(spaceTokens)
                continue;
            end

            candidateKey = string(spaceTokens{1});

            if ~ismember(lower(candidateKey), ...
                    recognizedSpaceSeparatedKeys)
                continue;
            end

            key = candidateKey;
            value = string(strtrim(spaceTokens{2}));
        end

        keys(end+1,1) = key; %#ok<AGROW>
        values(end+1,1) = value; %#ok<AGROW>
        rawLines(end+1,1) = rawLine; %#ok<AGROW>
        lineNumbers(end+1,1) = lineIndex; %#ok<AGROW>
    end

    metadata = table( ...
        keys, ...
        values, ...
        rawLines, ...
        lineNumbers, ...
        'VariableNames', ...
        {'Key', 'Value', 'RawLine', 'LineNumber'});
end
