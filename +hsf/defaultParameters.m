function parameters = defaultParameters()
%DEFAULTPARAMETERS Default head-support-force parameters.
%
% The force model balances the entire skull weight in global +Y while the
% force vector remains normal to a support plane inclined by ConditionAngle.
% The resulting radial magnitude is W*tan(ConditionAngle).

    parameters = struct;
    parameters.BodyName = "skull";
    parameters.SkullMassKg = 1.1704014720812095;
    parameters.GravityY = -9.80665;
    parameters.TargetRateHz = 1000;
    parameters.RampDuration = 0.1;
    parameters.RampShape = "halfcosine";
    parameters.RadialSign = 1;
    parameters.AzimuthConvention = "x_cos_z_sin";
    parameters.InterpolationMethod = "pchip";
    parameters.ForcePrefix = "ground_force_1_v";
    parameters.PointPrefix = "ground_force_1_p";
    parameters.TorquePrefix = "ground_torque_1_";
    parameters.IncludeTorque = false;
end
