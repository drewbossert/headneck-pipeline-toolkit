function info = parseStrengthConfigName(configFile)
%PARSESTRENGTHCONFIGNAME Parse canonical muscle/actuator strength config ID.
%
% info = pipeline.parseStrengthConfigName(configFile)
%
% Canonical filename:
%
%   m{muscle_percent}p_a{actuator_percent}p.json
%
% Example:
%
%   m25p_a75p.json
%
% returns:
%
%   info.ConfigId        = "m25p_a75p"
%   info.MusclePercent   = 25
%   info.ActuatorPercent = 75
%   info.FileName        = "m25p_a75p.json"
%   info.ConfigFile      = <original input path>

configFile = string(configFile);

assert(isscalar(configFile) && strlength(configFile) > 0, ...
    "StrengthConfig:InvalidInput", ...
    "configFile must be a nonempty scalar string or character vector.");

[~, stem, extension] = ...
    fileparts(configFile);

stem = string(stem);
extension = string(extension);

assert(strcmpi(extension, ".json"), ...
    "StrengthConfig:InvalidExtension", ...
    "Strength configuration must use the .json extension.");

expression = ...
    "^m(?<muscle>\d+)p_a(?<actuator>\d+)p$";

tokens = ...
    regexp( ...
    char(stem), ...
    expression, ...
    "names", ...
    "once");

assert(~isempty(tokens), ...
    "StrengthConfig:InvalidName", ...
    "Strength configuration filename '%s' does not match the " + ...
    "required pattern m{muscle}p_a{actuator}p.json.", ...
    stem + extension);

musclePercent = ...
    str2double(tokens.muscle);

actuatorPercent = ...
    str2double(tokens.actuator);

assert(isfinite(musclePercent) && musclePercent > 0, ...
    "StrengthConfig:InvalidMusclePercent", ...
    "Muscle percentage must be greater than zero.");

assert(isfinite(actuatorPercent) && actuatorPercent > 0, ...
    "StrengthConfig:InvalidActuatorPercent", ...
    "Actuator percentage must be greater than zero.");

info = struct;

info.ConfigId = stem;
info.MusclePercent = musclePercent;
info.ActuatorPercent = actuatorPercent;

info.FileName = ...
    stem + extension;

info.ConfigFile = ...
    configFile;
end