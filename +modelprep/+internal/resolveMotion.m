function motion = resolveMotion(motionInput)
%RESOLVEMOTION Return parsed motion structure from path or structure.

    if ischar(motionInput) || ...
            (isstring(motionInput) && isscalar(motionInput))
        motion = opensimio.readMot(motionInput);
        return;
    end

    if isstruct(motionInput) && ...
            all(isfield(motionInput, ...
            ["Labels", "Data", "Time", "InDegrees"]))
        motion = motionInput;
        return;
    end

    error("modelprep:InvalidMotionInput", ...
        ["motionInput must be a .mot path or a structure returned " ...
         "by opensimio.readMot()."]);
end
