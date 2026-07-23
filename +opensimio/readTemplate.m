function template = readTemplate(filePath)
%READTEMPLATE Read a text-based template without modifying its contents.
%
% template = opensimio.readTemplate(filePath)
%
% Returned structure:
%   FilePath
%   FileName
%   Extension
%   Text       Scalar string containing the entire file
%   Lines      String array of lines
%   Tokens     Unique {{TOKEN}} placeholders detected in the text

    filePath = string(filePath);

    assert(isfile(filePath), ...
        "opensimio:FileNotFound", ...
        "Template file was not found:\n%s", filePath);

    rawText = fileread(filePath);
    templateText = string(rawText);

    [~, fileName, extension] = fileparts(filePath);

    tokenMatches = regexp( ...
        rawText, ...
        '\{\{\s*([A-Za-z][A-Za-z0-9_.-]*)\s*\}\}', ...
        'tokens');

    if isempty(tokenMatches)
        tokens = strings(0,1);
    else
        tokens = string(cellfun(@(x) x{1}, tokenMatches, ...
            "UniformOutput", false));
        tokens = unique(tokens(:), "stable");
    end

    template = struct;
    template.FilePath = filePath;
    template.FileName = string(fileName);
    template.Extension = string(extension);
    template.Text = templateText;
    template.Lines = splitlines(templateText);
    template.Tokens = tokens;
end
