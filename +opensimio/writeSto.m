function writeSto(filePath, tableData, varargin)
%WRITESTO Write an OpenSim storage (.sto) file.
%
% opensimio.writeSto(filePath, tableData)

    validateExtension(filePath, ".sto");

    opensimio.writeOpenSimTable( ...
        filePath, ...
        tableData, ...
        varargin{:});
end

function validateExtension(filePath, expectedExtension)

    [~, ~, extension] = fileparts(string(filePath));

    if lower(string(extension)) ~= expectedExtension
        error("opensimio:UnexpectedExtension", ...
            "Output file must use the %s extension:\n%s", ...
            expectedExtension, string(filePath));
    end
end
