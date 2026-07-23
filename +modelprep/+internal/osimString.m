function valueString = osimString(value)
%OSIMSTRING Convert OpenSim/Java string-like values to MATLAB string.

    try
        valueString = string(char(value));
    catch
        try
            valueString = string(char(value.toString()));
        catch
            valueString = string(value);
        end
    end
end
