function writeText(filePath, textContent, varargin)
%WRITETEXT Write scalar text to a UTF-8 file.
%
% opensimio.writeText(filePath, textContent)
%
% Name-value options:
%   CreateFolder     true (default)
%   EnsureFinalNewline true (default)

    parser = inputParser;
    parser.FunctionName = "opensimio.writeText";

    addRequired(parser, "filePath", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addRequired(parser, "textContent", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "CreateFolder", true, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "EnsureFinalNewline", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, filePath, textContent, varargin{:});

    filePath = string(parser.Results.filePath);
    textContent = string(parser.Results.textContent);

    if parser.Results.CreateFolder
        parentFolder = fileparts(filePath);

        if strlength(parentFolder) > 0 && ~isfolder(parentFolder)
            mkdir(parentFolder);
        end
    end

    if parser.Results.EnsureFinalNewline && ...
            ~endsWith(textContent, newline)
        textContent = textContent + newline;
    end

    fileID = fopen(filePath, "w", "n", "UTF-8");

    if fileID < 0
        error("opensimio:OpenFailed", ...
            "Could not open file for writing:\n%s", filePath);
    end

    cleanupObject = onCleanup(@() fclose(fileID)); %#ok<NASGU>
    fprintf(fileID, "%s", textContent);
end
