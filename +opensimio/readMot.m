function result = readMot(filePath, varargin)
%READMOT Read an OpenSim motion (.mot) file.
%
% result = opensimio.readMot(filePath)

    result = opensimio.readOpenSimTable( ...
        filePath, ...
        "ExpectedExtension", ".mot", ...
        varargin{:});
end
