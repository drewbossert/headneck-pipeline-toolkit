function result = readXml(filePath)
%READXML Read an XML file into a Java DOM document.
%
% result = opensimio.readXml(filePath)
%
% Returned structure:
%   FilePath
%   Document
%   RootElement
%   RootName
%
% The Java DOM representation works with xmlwrite and supports standard
% methods such as getElementsByTagName(), getTextContent(), and setTextContent().

    filePath = string(filePath);

    assert(isfile(filePath), ...
        "opensimio:FileNotFound", ...
        "XML file was not found:\n%s", filePath);

    try
        if exist("xmlread", "file") == 2
            document = xmlread(char(filePath));
        else
            factory = javax.xml.parsers.DocumentBuilderFactory.newInstance();
            factory.setNamespaceAware(true);
            builder = factory.newDocumentBuilder();
            document = builder.parse(java.io.File(char(filePath)));
        end

        document.getDocumentElement().normalize();
    catch exception
        error("opensimio:XmlReadFailed", ...
            "Could not parse XML file:\n%s\n\n%s", ...
            filePath, exception.message);
    end

    rootElement = document.getDocumentElement();

    result = struct;
    result.FilePath = filePath;
    result.Document = document;
    result.RootElement = rootElement;
    result.RootName = string(char(rootElement.getNodeName()));
end
