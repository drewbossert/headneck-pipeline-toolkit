function result = generateFromBodyKinematics( ...
        positionFile, ikMotionFile, outputMotFile, ...
        conditionAngleDeg, varargin)
%GENERATEFROMBODYKINEMATICS Generate an HSF .mot from existing CoM output.
%
% result = hsf.generateFromBodyKinematics( ...
%     positionFile, ikMotionFile, outputMotFile, conditionAngleDeg)
%
% Name-value options:
%   BodyName
%   SkullMassKg
%   GravityY
%   GndrollCoordinate
%   GndrollTimeWindow
%   GndrollToleranceDeg
%   TargetRateHz
%   OffIntervals
%   RampDuration
%   RampShape
%   RadialSign
%   AzimuthConvention
%   InterpolationMethod
%   ForcePrefix
%   PointPrefix
%   TorquePrefix
%   IncludeTorque
%   Precision

    defaults = hsf.defaultParameters();

    parser = inputParser;
    parser.FunctionName = "hsf.generateFromBodyKinematics";

    addRequired(parser, "positionFile");
    addRequired(parser, "ikMotionFile");
    addRequired(parser, "outputMotFile");
    addRequired(parser, "conditionAngleDeg", ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x));

    addParameter(parser, "BodyName", defaults.BodyName);
    addParameter(parser, "SkullMassKg", defaults.SkullMassKg);
    addParameter(parser, "GravityY", defaults.GravityY);
    addParameter(parser, "GndrollCoordinate", "gndroll");
    addParameter(parser, "GndrollTimeWindow", []);
    addParameter(parser, "GndrollToleranceDeg", 1e-6);
    addParameter(parser, "TargetRateHz", defaults.TargetRateHz);
    addParameter(parser, "OffIntervals", zeros(0,2));
    addParameter(parser, "RampDuration", defaults.RampDuration);
    addParameter(parser, "RampShape", defaults.RampShape);
    addParameter(parser, "RadialSign", defaults.RadialSign);
    addParameter(parser, "AzimuthConvention", defaults.AzimuthConvention);
    addParameter(parser, "InterpolationMethod", defaults.InterpolationMethod);
    addParameter(parser, "ForcePrefix", defaults.ForcePrefix);
    addParameter(parser, "PointPrefix", defaults.PointPrefix);
    addParameter(parser, "TorquePrefix", defaults.TorquePrefix);
    addParameter(parser, "IncludeTorque", defaults.IncludeTorque);
    addParameter(parser, "Precision", "%.15g");

    parse(parser, positionFile, ikMotionFile, ...
        outputMotFile, conditionAngleDeg, varargin{:});

    ikMotion = opensimio.readMot(ikMotionFile);

    if isempty(parser.Results.GndrollTimeWindow)
        gndrollWindow = [ikMotion.Time(1), ikMotion.Time(end)];
    else
        gndrollWindow = parser.Results.GndrollTimeWindow;
    end

    gndroll = hsf.extractCoordinateValue( ...
        ikMotion, parser.Results.GndrollCoordinate, ...
        "TimeWindow", gndrollWindow, ...
        "Method", "median", ...
        "RequireConstant", true, ...
        "Tolerance", parser.Results.GndrollToleranceDeg);

    forceComponents = hsf.computeForceComponents( ...
        parser.Results.SkullMassKg, ...
        parser.Results.GravityY, ...
        conditionAngleDeg, ...
        gndroll.Value, ...
        "RadialSign", parser.Results.RadialSign, ...
        "AzimuthConvention", parser.Results.AzimuthConvention);

    com = hsf.readBodyCom(positionFile, parser.Results.BodyName);

    commonStart = max(com.Time(1), ikMotion.Time(1));
    commonEnd = min(com.Time(end), ikMotion.Time(end));

    if commonEnd <= commonStart
        error("hsf:NoCommonTimeRange", ...
            "IK and BodyKinematics files have no common time range.");
    end

    resampledCom = hsf.resampleCom( ...
        com, parser.Results.TargetRateHz, ...
        "TimeRange", [commonStart, commonEnd], ...
        "InterpolationMethod", ...
        parser.Results.InterpolationMethod);

    envelope = hsf.makeSupportEnvelope( ...
        resampledCom.Time, ...
        "OffIntervals", parser.Results.OffIntervals, ...
        "RampDuration", parser.Results.RampDuration, ...
        "RampShape", parser.Results.RampShape);

    built = hsf.buildMotion( ...
        resampledCom, forceComponents, envelope, ...
        "ForcePrefix", parser.Results.ForcePrefix, ...
        "PointPrefix", parser.Results.PointPrefix, ...
        "TorquePrefix", parser.Results.TorquePrefix, ...
        "IncludeTorque", parser.Results.IncludeTorque);

    opensimio.writeMot( ...
        outputMotFile, built.Motion, ...
        "Name", "head_support_force", ...
        "InDegrees", false, ...
        "Precision", parser.Results.Precision);

    validation = hsf.validateMotion( ...
        outputMotFile, ...
        "ExpectedRateHz", parser.Results.TargetRateHz, ...
        "ForcePrefix", parser.Results.ForcePrefix, ...
        "PointPrefix", parser.Results.PointPrefix);

    result = struct;
    result.OutputMotFile = string(outputMotFile);
    result.PositionFile = string(positionFile);
    result.IkMotionFile = string(ikMotionFile);
    result.Gndroll = gndroll;
    result.ForceComponents = forceComponents;
    result.Com = com;
    result.ResampledCom = resampledCom;
    result.Envelope = envelope;
    result.Motion = built.Motion;
    result.Validation = validation;
end
