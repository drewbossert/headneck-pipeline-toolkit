function coordinateType = inferCoordinateType(coordinate)
%INFERCOORDINATETYPE Classify coordinate as rotation, translation, or other.

    try
        motionType = string(char( ...
            coordinate.getMotionType().toString()));
    catch
        try
            motionType = string(coordinate.getMotionType());
        catch
            motionType = "Unknown";
        end
    end

    lowerType = lower(motionType);

    if contains(lowerType, "rotation")
        coordinateType = "rotation";
        return;
    elseif contains(lowerType, "translation")
        coordinateType = "translation";
        return;
    end

    coordinateName = lower(modelprep.internal.osimString( ...
        coordinate.getName()));

    if contains(coordinateName, "pitch") || ...
            contains(coordinateName, "roll") || ...
            contains(coordinateName, "yaw") || ...
            ~isempty(regexp(coordinateName, "_r[123]$", "once"))
        coordinateType = "rotation";
    elseif contains(coordinateName, "_tx") || ...
            contains(coordinateName, "_ty") || ...
            contains(coordinateName, "_tz")
        coordinateType = "translation";
    else
        coordinateType = "other";
    end
end
