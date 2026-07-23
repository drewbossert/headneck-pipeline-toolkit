function writeXml(filePath, xmlData, varargin)
%WRITEXML Write a Java DOM document to an XML file.
%
% opensimio.writeXml(filePath, xmlData)
%
% xmlData may be:
%   - the structure returned by opensimio.readXml(), or
%   - a Java DOM Document object.
%
% Name-value option:
%   CreateFolder  true (default)

    parser = inputParser;
    parser.FunctionName = "opensimio.writeXml";

    addRequired(parser, "filePath", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addRequired(parser, "xmlData");

    addParameter(parser, "CreateFolder", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, filePath, xmlData, varargin{:});

    filePath = string(parser.Results.filePath);

    if isstruct(xmlData) && isfield(xmlData, "Document")
        document = xmlData.Document;
    else
        document = xmlData;
    end

    if parser.Results.CreateFolder
        parentFolder = fileparts(filePath);

        if strlength(parentFolder) > 0 && ~isfolder(parentFolder)
            mkdir(parentFolder);
        end
    end

    try
        if exist("xmlwrite", "file") == 2
            xmlwrite(char(filePath), document);
        else
            transformerFactory = ...
                javax.xml.transform.TransformerFactory.newInstance();

            transformer = transformerFactory.newTransformer();

            transformer.setOutputProperty( ...
                javax.xml.transform.OutputKeys.INDENT, "yes");

            source = javax.xml.transform.dom.DOMSource(document);
            output = javax.xml.transform.stream.StreamResult( ...
                java.io.File(char(filePath)));

            transformer.transform(source, output);
        end
    catch exception
        error("opensimio:XmlWriteFailed", ...
            "Could not write XML file:\n%s\n\n%s", ...
            filePath, exception.message);
    end
end
