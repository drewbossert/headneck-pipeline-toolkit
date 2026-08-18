function [motion, sourceFile] = resolveMotion(motionInput)
%RESOLVEMOTION Resolve a motion-file path or parsed motion structure.
%
% [motion, sourceFile] = opensimio.resolveMotion(motionInput)
%
% INPUT
%   motionInput
%       Either:
%           - path to an OpenSim .mot file; or
%           - structure returned by opensimio.readMot().
%
% OUTPUTS
%   motion
%       Parsed OpenSim motion structure containing at least:
%           Labels
%           Data
%           Time
%           InDegrees
%
%   sourceFile
%       String path identifying the source file when known.
%       For a path input, this is the supplied path.
%       For a parsed structure, FilePath is used when available.
%       Otherwise, sourceFile is "".
%
% This helper centralizes the path-or-structure input contract used by
% multiple packages without imposing package-specific scientific logic.

    requiredFields = [
        "Labels"
        "Data"
        "Time"
        "InDegrees"
    ];

    if ischar(motionInput) || ...
            (isstring(motionInput) && isscalar(motionInput))

        sourceFile = ...
            string(motionInput);

        motion = ...
            opensimio.readMot( ...
                sourceFile);

        return;
    end

    if isstruct(motionInput) && ...
            all(isfield( ...
                motionInput, ...
                requiredFields))

        motion = ...
            motionInput;

        if isfield(motion, "FilePath")

            sourceFile = ...
                string(motion.FilePath);

        else

            sourceFile = ...
                "";
        end

        return;
    end

    error( ...
        "opensimio:InvalidMotionInput", ...
        "motionInput must be a .mot path or a structure returned " + ...
        "by opensimio.readMot().");
end
