function result = readOpenSimTable(filePath, varargin)
%READOPENSIMTABLE Read an OpenSim .mot or .sto storage table.
%
% result = opensimio.readOpenSimTable(filePath)
%
% Name-value options:
%   ExpectedExtension  ".mot", ".sto", or "" (default)
%   RequireTimeColumn  true (default)
%
% Returned structure:
%   FilePath       Absolute or supplied file path
%   Extension      File extension
%   HeaderLines    Header lines through endheader, when present
%   Metadata       Table with Key, Value, RawLine, and LineNumber
%   Labels         1-by-N string array of column labels
%   Data           M-by-N numeric matrix
%   Time           M-by-1 time vector, when the first label is time
%   InDegrees      true, false, or NaN when unspecified
%   NumRows        Number of data rows
%   NumColumns     Number of data columns
%   LabelLineIndex Line number containing column labels
%
% The reader supports whitespace-, tab-, and comma-delimited numeric data.

    parser = inputParser;
    parser.FunctionName = "opensimio.readOpenSimTable";

    addRequired(parser, "filePath", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "ExpectedExtension", "", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "RequireTimeColumn", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, filePath, varargin{:});

    filePath = string(parser.Results.filePath);
    expectedExtension = lower(string(parser.Results.ExpectedExtension));
    requireTimeColumn = parser.Results.RequireTimeColumn;

    assert(isfile(filePath), ...
        "opensimio:FileNotFound", ...
        "OpenSim table file was not found:\n%s", filePath);

    [~, ~, extension] = fileparts(filePath);
    extension = lower(string(extension));

    if strlength(expectedExtension) > 0 && extension ~= expectedExtension
        error("opensimio:UnexpectedExtension", ...
            "Expected a %s file but received:\n%s", ...
            expectedExtension, filePath);
    end

    lines = readlines(filePath);

    if isempty(lines)
        error("opensimio:EmptyFile", ...
            "The file is empty:\n%s", filePath);
    end

    [headerLines, labelLineIndex] = ...
        opensimio.internal.locateOpenSimTableSections(lines, filePath);

    labelLine = lines(labelLineIndex);
    labels = opensimio.internal.parseColumnLabels(labelLine);

    if isempty(labels)
        error("opensimio:MissingLabels", ...
            "No column labels were found in:\n%s", filePath);
    end

    if requireTimeColumn && lower(labels(1)) ~= "time"
        error("opensimio:MissingTimeColumn", ...
            "The first column must be 'time' in:\n%s", filePath);
    end

    fileID = fopen(filePath, "r");

    if fileID < 0
        error("opensimio:OpenFailed", ...
            "Could not open file for reading:\n%s", filePath);
    end

    cleanupObject = onCleanup(@() fclose(fileID)); %#ok<NASGU>

    for lineIndex = 1:labelLineIndex
        fgetl(fileID);
    end

    formatSpec = repmat('%f', 1, numel(labels));

    numericCells = textscan( ...
        fileID, ...
        formatSpec, ...
        'Delimiter', {' ', sprintf('\t'), ','}, ...
        'MultipleDelimsAsOne', true, ...
        'CollectOutput', true, ...
        'ReturnOnError', false, ...
        'TreatAsEmpty', {'NA', 'N/A', 'nan', 'NaN'});

    if isempty(numericCells) || isempty(numericCells{1})
        error("opensimio:MissingNumericData", ...
            "No numeric data were read from:\n%s", filePath);
    end

    data = numericCells{1};

    if size(data, 2) ~= numel(labels)
        error("opensimio:ColumnCountMismatch", ...
            ["The numeric data contain %d columns, but the label row " ...
             "contains %d labels in:\n%s"], ...
            size(data, 2), numel(labels), filePath);
    end

    metadata = opensimio.internal.parseHeaderMetadata(headerLines);
    inDegrees = opensimio.internal.readLogicalMetadata( ...
        metadata, "inDegrees", NaN);

    result = struct;
    result.FilePath = filePath;
    result.Extension = extension;
    result.HeaderLines = headerLines;
    result.Metadata = metadata;
    result.Labels = reshape(labels, 1, []);
    result.Data = data;
    result.InDegrees = inDegrees;
    result.NumRows = size(data, 1);
    result.NumColumns = size(data, 2);
    result.LabelLineIndex = labelLineIndex;

    if lower(labels(1)) == "time"
        result.Time = data(:, 1);
    else
        result.Time = [];
    end

    declaredRows = opensimio.getHeaderValue(result, "nRows", "");
    declaredColumns = opensimio.getHeaderValue(result, "nColumns", "");

    if strlength(declaredRows) > 0
        declaredRowsNumber = str2double(declaredRows);

        if isfinite(declaredRowsNumber) && ...
                declaredRowsNumber ~= result.NumRows
            warning("opensimio:DeclaredRowCountMismatch", ...
                ["Header declares %g rows, but %d rows were read from:\n%s"], ...
                declaredRowsNumber, result.NumRows, filePath);
        end
    end

    if strlength(declaredColumns) > 0
        declaredColumnsNumber = str2double(declaredColumns);

        if isfinite(declaredColumnsNumber) && ...
                declaredColumnsNumber ~= result.NumColumns
            warning("opensimio:DeclaredColumnCountMismatch", ...
                ["Header declares %g columns, but %d columns were read from:\n%s"], ...
                declaredColumnsNumber, result.NumColumns, filePath);
        end
    end
end
