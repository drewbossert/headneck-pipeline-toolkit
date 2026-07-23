function writeMot(filePath, tableData, varargin)
%WRITEMOT Write an OpenSim motion (.mot) file.
%
% opensimio.writeMot(filePath, tableData)

    validateExtension(filePath, ".mot");

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
