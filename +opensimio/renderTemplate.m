function [renderedText, report] = renderTemplate(templateInput, values, varargin)
%RENDERTEMPLATE Replace {{TOKEN}} placeholders in a text template.
%
% renderedText = opensimio.renderTemplate(templateInput, values)
%
% templateInput may be:
%   - the structure returned by opensimio.readTemplate(), or
%   - a scalar string/character vector containing template text.
%
% values may be:
%   - a scalar structure: struct("MODEL_FILE", "...", ...)
%   - a containers.Map
%   - a two-column table with variables Key and Value
%
% Name-value options:
%   Strict           true (default): error when unresolved tokens remain
%   EscapeXmlValues  false (default): XML-escape replacement values
%
% The function returns a report table containing Token, Replacement,
% and Occurrences.

    parser = inputParser;
    parser.FunctionName = "opensimio.renderTemplate";

    addRequired(parser, "templateInput");

    addRequired(parser, "values");

    addParameter(parser, "Strict", true, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "EscapeXmlValues", false, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, templateInput, values, varargin{:});

    if isstruct(templateInput) && isfield(templateInput, "Text")
        renderedText = string(templateInput.Text);
    elseif ischar(templateInput) || ...
            (isstring(templateInput) && isscalar(templateInput))
        renderedText = string(templateInput);
    else
        error("opensimio:InvalidTemplate", ...
            ["templateInput must be a scalar string, character vector, " ...
             "or the structure returned by opensimio.readTemplate()."]);
    end

    [keys, replacements] = normalizeReplacementValues(values);

    occurrences = zeros(numel(keys), 1);

    for index = 1:numel(keys)
        key = keys(index);
        replacement = replacements(index);

        if parser.Results.EscapeXmlValues
            replacement = xmlEscape(replacement);
        end

        pattern = "\{\{\s*" + regexptranslate("escape", key) + ...
            "\s*\}\}";

        matches = regexp(char(renderedText), char(pattern), "match");
        occurrences(index) = numel(matches);

        renderedText = string(regexprep( ...
            char(renderedText), ...
            char(pattern), ...
            char(replacement)));
    end

    unresolvedMatches = regexp( ...
        char(renderedText), ...
        '\{\{\s*([A-Za-z][A-Za-z0-9_.-]*)\s*\}\}', ...
        'tokens');

    if isempty(unresolvedMatches)
        unresolvedTokens = strings(0,1);
    else
        unresolvedTokens = string(cellfun( ...
            @(x) x{1}, unresolvedMatches, ...
            "UniformOutput", false));
        unresolvedTokens = unique(unresolvedTokens(:), "stable");
    end

    report = table( ...
        keys(:), replacements(:), occurrences, ...
        'VariableNames', ...
        {'Token', 'Replacement', 'Occurrences'});

    if parser.Results.Strict && ~isempty(unresolvedTokens)
        error("opensimio:UnresolvedTemplateTokens", ...
            "Unresolved template tokens remain: %s", ...
            strjoin(unresolvedTokens, ", "));
    end
end

function [keys, replacements] = normalizeReplacementValues(values)

    if isstruct(values)
        if ~isscalar(values)
            error("opensimio:InvalidReplacements", ...
                "Replacement structure must be scalar.");
        end

        keys = string(fieldnames(values));
        replacements = strings(numel(keys), 1);

        for index = 1:numel(keys)
            replacements(index) = stringify(values.(char(keys(index))));
        end

    elseif isa(values, "containers.Map")
        keys = string(values.keys());
        replacements = strings(numel(keys), 1);

        for index = 1:numel(keys)
            replacements(index) = stringify(values(char(keys(index))));
        end

    elseif istable(values)
        requiredVariables = ["Key", "Value"];

        if ~all(ismember(requiredVariables, ...
                string(values.Properties.VariableNames)))
            error("opensimio:InvalidReplacementTable", ...
                "Replacement table must contain Key and Value variables.");
        end

        keys = string(values.Key);
        replacements = string(values.Value);

    else
        error("opensimio:InvalidReplacements", ...
            ["values must be a scalar structure, containers.Map, " ...
             "or table with Key and Value variables."]);
    end

    keys = keys(:);
    replacements = replacements(:);

    if numel(unique(lower(keys))) ~= numel(keys)
        error("opensimio:DuplicateReplacementKeys", ...
            "Replacement keys must be unique, ignoring case.");
    end
end

function valueString = stringify(value)

    if isstring(value)
        if ~isscalar(value)
            error("opensimio:NonScalarReplacement", ...
                "Each replacement value must be scalar.");
        end
        valueString = value;

    elseif ischar(value)
        valueString = string(value);

    elseif isnumeric(value) || islogical(value)
        if ~isscalar(value)
            error("opensimio:NonScalarReplacement", ...
                "Each replacement value must be scalar.");
        end
        valueString = string(value);

    else
        error("opensimio:UnsupportedReplacementType", ...
            "Unsupported replacement value type: %s", class(value));
    end
end

function escaped = xmlEscape(value)

    escaped = string(value);
    escaped = replace(escaped, "&", "&amp;");
    escaped = replace(escaped, "<", "&lt;");
    escaped = replace(escaped, ">", "&gt;");
    escaped = replace(escaped, '"', "&quot;");
    escaped = replace(escaped, "'", "&apos;");
end
