function writeOpenSimTable(filePath, tableData, varargin)
%WRITEOPENSIMTABLE Write an OpenSim .mot or .sto storage table.
%
% opensimio.writeOpenSimTable(filePath, tableData)
%
% tableData must contain:
%   Labels  1-by-N labels
%   Data    M-by-N numeric matrix
%
% Optional tableData fields:
%   HeaderLines
%   InDegrees
%
% Name-value options:
%   Name          Header name. Default: output filename without extension.
%   InDegrees     true, false, or NaN. Default: tableData.InDegrees or NaN.
%   HeaderLines   Header to preserve. Default: tableData.HeaderLines or "".
%   Delimiter     "\t" (default), " ", or ","
%   Precision     "%.15g" (default)
%   CreateFolder  true (default)
%
% Existing nRows, nColumns, datarows, datacolumns, and inDegrees metadata
% are updated before the file is written.

    parser = inputParser;
    parser.FunctionName = "opensimio.writeOpenSimTable";

    addRequired(parser, "filePath", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addRequired(parser, "tableData", @isstruct);

    addParameter(parser, "Name", "", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "InDegrees", [], ...
        @(x) isempty(x) || ...
        (islogical(x) && isscalar(x)) || ...
        (isnumeric(x) && isscalar(x)));

    addParameter(parser, "HeaderLines", string.empty(0,1), ...
        @(x) ischar(x) || isstring(x) || iscellstr(x));

    addParameter(parser, "Delimiter", sprintf('\t'), ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "Precision", "%.15g", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "CreateFolder", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, filePath, tableData, varargin{:});

    filePath = string(parser.Results.filePath);
    tableData = parser.Results.tableData;
    delimiter = char(string(parser.Results.Delimiter));
    precision = char(string(parser.Results.Precision));

    requiredFields = ["Labels", "Data"];

    for fieldName = requiredFields
        if ~isfield(tableData, fieldName)
            error("opensimio:MissingField", ...
                "tableData is missing required field '%s'.", fieldName);
        end
    end

    labels = reshape(string(tableData.Labels), 1, []);
    data = tableData.Data;

    if ~isnumeric(data) || ndims(data) ~= 2
        error("opensimio:InvalidData", ...
            "tableData.Data must be a two-dimensional numeric matrix.");
    end

    if size(data, 2) ~= numel(labels)
        error("opensimio:ColumnCountMismatch", ...
            ["tableData.Data has %d columns, but tableData.Labels " ...
             "contains %d labels."], ...
            size(data, 2), numel(labels));
    end

    if any(strlength(labels) == 0)
        error("opensimio:EmptyLabel", ...
            "Column labels cannot be empty.");
    end

    if contains(string(delimiter), newline)
        error("opensimio:InvalidDelimiter", ...
            "Delimiter cannot contain a newline.");
    end

    if parser.Results.CreateFolder
        parentFolder = fileparts(filePath);

        if strlength(parentFolder) > 0 && ~isfolder(parentFolder)
            mkdir(parentFolder);
        end
    end

    requestedName = string(parser.Results.Name);

    if strlength(requestedName) == 0
        [~, requestedName] = fileparts(filePath);
        requestedName = string(requestedName);
    end

    requestedHeader = string(parser.Results.HeaderLines);

    if isempty(requestedHeader) && isfield(tableData, "HeaderLines")
        requestedHeader = string(tableData.HeaderLines);
    end

    requestedInDegrees = parser.Results.InDegrees;

    if isempty(requestedInDegrees)
        if isfield(tableData, "InDegrees")
            requestedInDegrees = tableData.InDegrees;
        else
            requestedInDegrees = NaN;
        end
    end

    headerLines = opensimio.internal.buildOpenSimHeader( ...
        requestedHeader, ...
        requestedName, ...
        size(data, 1), ...
        size(data, 2), ...
        requestedInDegrees);

    fileID = fopen(filePath, "w");

    if fileID < 0
        error("opensimio:OpenFailed", ...
            "Could not open file for writing:\n%s", filePath);
    end

    cleanupObject = onCleanup(@() fclose(fileID)); %#ok<NASGU>

    for lineIndex = 1:numel(headerLines)
        fprintf(fileID, "%s\n", headerLines(lineIndex));
    end

    fprintf(fileID, "%s\n", strjoin(labels, string(delimiter)));

    numericFormat = repmat([precision, delimiter], 1, numel(labels));
    numericFormat = [numericFormat(1:end-numel(delimiter)), '\n'];

    for rowIndex = 1:size(data, 1)
        fprintf(fileID, numericFormat, data(rowIndex, :));
    end
end
