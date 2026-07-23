function result = buildMotion( ...
        resampledCom, forceComponents, envelopeInput, varargin)
%BUILDMOTION Construct an OpenSim-compatible HSF motion structure.
%
% result = hsf.buildMotion(resampledCom, forceComponents, envelopeInput)
%
% Name-value options:
%   ForcePrefix   "ground_force_1_v"
%   PointPrefix   "ground_force_1_p"
%   TorquePrefix  "ground_torque_1_"
%   IncludeTorque false
%   Name          "head_support_force"
%
% Force values are multiplied by the support envelope. The application point
% follows the skull center of mass even while the force is zero.

    defaults = hsf.defaultParameters();

    parser = inputParser;
    parser.FunctionName = "hsf.buildMotion";

    addRequired(parser, "resampledCom", @isstruct);
    addRequired(parser, "forceComponents", @isstruct);
    addRequired(parser, "envelopeInput");

    addParameter(parser, "ForcePrefix", defaults.ForcePrefix, ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, "PointPrefix", defaults.PointPrefix, ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, "TorquePrefix", defaults.TorquePrefix, ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, "IncludeTorque", defaults.IncludeTorque, ...
        @(x) islogical(x) && isscalar(x));
    addParameter(parser, "Name", "head_support_force", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    parse(parser, resampledCom, forceComponents, ...
        envelopeInput, varargin{:});

    requiredCom = ["Time", "X", "Y", "Z"];

    if ~all(isfield(resampledCom, requiredCom))
        error("hsf:InvalidResampledCom", ...
            "resampledCom must contain Time, X, Y, and Z.");
    end

    if isstruct(envelopeInput) && isfield(envelopeInput, "Envelope")
        envelope = double(envelopeInput.Envelope(:));
    elseif isnumeric(envelopeInput) && isvector(envelopeInput)
        envelope = double(envelopeInput(:));
    else
        error("hsf:InvalidEnvelope", ...
            "envelopeInput must be a numeric vector or envelope structure.");
    end

    time = double(resampledCom.Time(:));
    nRows = numel(time);

    if numel(envelope) ~= nRows
        error("hsf:EnvelopeLengthMismatch", ...
            "Envelope length does not match CoM time length.");
    end

    forceVector = [ ...
        forceComponents.ForceX, ...
        forceComponents.ForceY, ...
        forceComponents.ForceZ];

    forceData = envelope .* forceVector;
    pointData = [ ...
        double(resampledCom.X(:)), ...
        double(resampledCom.Y(:)), ...
        double(resampledCom.Z(:))];

    forcePrefix = string(parser.Results.ForcePrefix);
    pointPrefix = string(parser.Results.PointPrefix);
    torquePrefix = string(parser.Results.TorquePrefix);

    labels = [ ...
        "time", ...
        forcePrefix + "x", ...
        forcePrefix + "y", ...
        forcePrefix + "z", ...
        pointPrefix + "x", ...
        pointPrefix + "y", ...
        pointPrefix + "z"];

    data = [time, forceData, pointData];

    if parser.Results.IncludeTorque
        labels = [labels, ...
            torquePrefix + "x", ...
            torquePrefix + "y", ...
            torquePrefix + "z"];
        data = [data, zeros(nRows,3)];
    end

    motion = struct;
    motion.FilePath = "";
    motion.Extension = ".mot";
    motion.HeaderLines = strings(0,1);
    motion.Metadata = table( ...
        'Size', [0,4], ...
        'VariableTypes', ...
        {'string','string','string','double'}, ...
        'VariableNames', ...
        {'Key','Value','RawLine','LineNumber'});
    motion.Labels = labels;
    motion.Data = data;
    motion.Time = time;
    motion.InDegrees = false;
    motion.NumRows = size(data,1);
    motion.NumColumns = size(data,2);
    motion.LabelLineIndex = NaN;

    result = struct;
    result.Motion = motion;
    result.Name = string(parser.Results.Name);
    result.Envelope = envelope;
    result.ForceComponents = forceComponents;
    result.ResampledCom = resampledCom;
end
