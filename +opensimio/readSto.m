function result = readSto(filePath, varargin)
%READSTO Read an OpenSim storage (.sto) file.
%
% result = opensimio.readSto(filePath)

    result = opensimio.readOpenSimTable( ...
        filePath, ...
        "ExpectedExtension", ".sto", ...
        varargin{:});
end
