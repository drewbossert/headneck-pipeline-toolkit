function values = rampUp(progress, rampShape)
%RAMPUP Evaluate a zero-to-one ramp.

    progress = min(max(double(progress), 0), 1);
    rampShape = lower(string(rampShape));

    switch rampShape
        case "linear"
            values = progress;
        case "halfcosine"
            values = 0.5 * (1 - cos(pi * progress));
        otherwise
            error("hsf:UnknownRampShape", ...
                "Unknown ramp shape '%s'.", rampShape);
    end
end
