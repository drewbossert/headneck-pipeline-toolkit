function result = computeForceComponents( ...
        skullMassKg, gravityY, conditionAngleDeg, gndrollDeg, varargin)
%COMPUTEFORCECOMPONENTS Compute global HSF vector components.
%
% result = hsf.computeForceComponents( ...
%     skullMassKg, gravityY, conditionAngleDeg, gndrollDeg)
%
% The implemented model imposes:
%   Fy = skull weight magnitude
%   radial magnitude = W*tan(condition angle)
%
% Therefore the total force points normal to the inclined support plane and
% has magnitude W/cos(condition angle).
%
% Name-value options:
%   RadialSign        1 or -1
%   AzimuthConvention "x_cos_z_sin" or "x_sin_z_cos"
%
% For x_cos_z_sin:
%   Fx = sign * Fr * cosd(gndroll)
%   Fz = sign * Fr * sind(gndroll)

    parser = inputParser;
    parser.FunctionName = "hsf.computeForceComponents";

    addRequired(parser, "skullMassKg", ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
    addRequired(parser, "gravityY", ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x ~= 0);
    addRequired(parser, "conditionAngleDeg", ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x));
    addRequired(parser, "gndrollDeg", ...
        @(x) isnumeric(x) && isscalar(x) && isfinite(x));

    addParameter(parser, "RadialSign", 1, ...
        @(x) isnumeric(x) && isscalar(x) && any(x == [-1, 1]));
    addParameter(parser, "AzimuthConvention", "x_cos_z_sin", ...
        @(x) any(strcmpi(string(x), ...
        ["x_cos_z_sin", "x_sin_z_cos"])));

    parse(parser, skullMassKg, gravityY, ...
        conditionAngleDeg, gndrollDeg, varargin{:});

    angle = double(conditionAngleDeg);
    cosineAngle = cosd(angle);

    if cosineAngle <= 1e-10
        error("hsf:InvalidConditionAngle", ...
            ["Condition angle %.9g deg produces a singular or downward " ...
             "support normal. Require cos(angle) > 0."], angle);
    end

    weightMagnitude = double(skullMassKg) * abs(double(gravityY));
    verticalForce = weightMagnitude;
    radialMagnitude = weightMagnitude * tand(angle);
    radialSign = double(parser.Results.RadialSign);
    convention = lower(string(parser.Results.AzimuthConvention));

    switch convention
        case "x_cos_z_sin"
            forceX = radialSign * radialMagnitude * cosd(gndrollDeg);
            forceZ = radialSign * radialMagnitude * sind(gndrollDeg);
        case "x_sin_z_cos"
            forceX = radialSign * radialMagnitude * sind(gndrollDeg);
            forceZ = radialSign * radialMagnitude * cosd(gndrollDeg);
    end

    forceY = verticalForce;
    forceVector = [forceX, forceY, forceZ];
    forceMagnitude = norm(forceVector);
    expectedMagnitude = weightMagnitude / cosineAngle;
    radialCheck = hypot(forceX, forceZ);

    unitNormal = forceVector / forceMagnitude;

    result = struct;
    result.SkullMassKg = double(skullMassKg);
    result.GravityY = double(gravityY);
    result.ConditionAngleDeg = angle;
    result.GndrollDeg = double(gndrollDeg);
    result.WeightMagnitudeN = weightMagnitude;
    result.RadialMagnitudeN = radialMagnitude;
    result.ForceX = forceX;
    result.ForceY = forceY;
    result.ForceZ = forceZ;
    result.ForceVector = forceVector;
    result.ForceMagnitudeN = forceMagnitude;
    result.ExpectedMagnitudeN = expectedMagnitude;
    result.UnitNormal = unitNormal;
    result.RadialSign = radialSign;
    result.AzimuthConvention = convention;
    result.ComponentCheckPassed = ...
        abs(radialCheck - radialMagnitude) <= ...
        max(1e-10, 1e-10 * radialMagnitude) && ...
        abs(forceY - weightMagnitude) <= ...
        max(1e-10, 1e-10 * weightMagnitude) && ...
        abs(forceMagnitude - expectedMagnitude) <= ...
        max(1e-10, 1e-10 * expectedMagnitude);
end
