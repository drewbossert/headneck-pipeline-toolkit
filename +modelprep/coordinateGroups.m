function groups = coordinateGroups()
%COORDINATEGROUPS Canonical coordinate groups for the head-neck workflow.
%
% groups = modelprep.coordinateGroups()
%
% Fields:
%   Root
%   IndependentOutOfPlane
%   DependentOutOfPlane
%   AllOutOfPlane
%   Sagittal
%   FinalIkLocked
%   StaticOptimizationLocked
%
% The final constrained IK model locks only the root coordinates and the
% independent roll/yaw coordinates. The dependent auxiliary r1/r2
% coordinates remain governed by enabled coordinate-coupler constraints.
%
% The Static Optimization model disables the couplers and therefore locks
% both the independent and dependent out-of-plane coordinates.

    groups = struct;

    groups.Root = [ ...
        "gndpitch"
        "gndroll"
        "gndyaw"
        "spine_tx"
        "spine_ty"
        "spine_tz"
    ];

    groups.IndependentOutOfPlane = [ ...
        "roll2"
        "yaw2"
        "roll1"
        "yaw1"
    ];

    groups.DependentOutOfPlane = [ ...
        "aux7jnt_r1"
        "aux7jnt_r2"
        "aux6jnt_r1"
        "aux6jnt_r2"
        "aux5jnt_r1"
        "aux5jnt_r2"
        "aux4jnt_r1"
        "aux4jnt_r2"
        "aux3jnt_r1"
        "aux3jnt_r2"
        "aux1jnt_r1"
        "aux1jnt_r2"
    ];

    groups.AllOutOfPlane = [ ...
        groups.IndependentOutOfPlane
        groups.DependentOutOfPlane
    ];

    groups.Sagittal = [ ...
        "pitch2"
        "aux7jnt_r3"
        "aux6jnt_r3"
        "aux5jnt_r3"
        "aux4jnt_r3"
        "aux3jnt_r3"
        "pitch1"
        "aux1jnt_r3"
    ];

    groups.FinalIkLocked = [ ...
        groups.Root
        groups.IndependentOutOfPlane
    ];

    groups.StaticOptimizationLocked = [ ...
        groups.Root
        groups.AllOutOfPlane
    ];
end
