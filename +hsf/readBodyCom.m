function result = readBodyCom(positionInput, bodyName)
%READBODYCOM Extract a body's global center-of-mass position trajectory.
%
% result = hsf.readBodyCom(positionInput, bodyName)
%
% positionInput may be a BodyKinematics position .sto path or a structure
% returned by opensimio.readSto().
%
% Result fields:
%   Time, X, Y, Z, Data, Labels, BodyName, SourceFile
%
% BodyKinematics position output commonly uses labels such as skull_X,
% skull_Y, and skull_Z. Full path labels are also normalized.

    if ischar(positionInput) || ...
            (isstring(positionInput) && isscalar(positionInput))
        storage = opensimio.readSto(positionInput);
        sourceFile = string(positionInput);
    elseif isstruct(positionInput) && ...
            all(isfield(positionInput, ["Labels", "Data", "Time"]))
        storage = positionInput;

        if isfield(storage, "FilePath")
            sourceFile = string(storage.FilePath);
        else
            sourceFile = "";
        end
    else
        error("hsf:InvalidBodyKinematicsInput", ...
            ["positionInput must be a .sto path or a structure returned " ...
             "by opensimio.readSto()."]);
    end

    bodyName = string(bodyName);
    normalized = strings(size(storage.Labels));

    for index = 1:numel(storage.Labels)
        normalized(index) = lower( ...
            hsf.internal.normalizeStorageLabel(storage.Labels(index)));
    end

    bodyLower = lower(bodyName);

    xIndex = hsf.internal.findAxisLabel(normalized, bodyLower, "x");
    yIndex = hsf.internal.findAxisLabel(normalized, bodyLower, "y");
    zIndex = hsf.internal.findAxisLabel(normalized, bodyLower, "z");

    result = struct;
    result.Time = storage.Time;
    result.X = storage.Data(:, xIndex);
    result.Y = storage.Data(:, yIndex);
    result.Z = storage.Data(:, zIndex);
    result.Data = [result.X, result.Y, result.Z];
    result.Labels = ["x", "y", "z"];
    result.BodyName = bodyName;
    result.SourceFile = sourceFile;
end
