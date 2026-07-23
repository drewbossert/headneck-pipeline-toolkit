function valuesSI = motionValuesToSI(values, coordinateType, inDegrees)
%MOTIONVALUESTOSI Convert motion-file values to OpenSim SI units.

    valuesSI = double(values);

    if coordinateType == "rotation"
        if isnumeric(inDegrees) && isnan(inDegrees)
            error("modelprep:UnknownMotionUnits", ...
                "Motion-file header does not specify inDegrees.");
        end

        if logical(inDegrees)
            valuesSI = deg2rad(valuesSI);
        end
    end
end
