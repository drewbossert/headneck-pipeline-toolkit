function model = resolveModel(modelInput)
%RESOLVEMODEL Return an OpenSim Model object from path or object.

    import org.opensim.modeling.*

    if ischar(modelInput) || ...
            (isstring(modelInput) && isscalar(modelInput))

        modelFile = string(modelInput);

        assert(isfile(modelFile), ...
            "modelprep:FileNotFound", ...
            "Model file was not found:\n%s", modelFile);

        model = Model(char(modelFile));
        return;
    end

    if isa(modelInput, "org.opensim.modeling.Model")
        model = modelInput;
        return;
    end

    error("modelprep:InvalidModelInput", ...
        ["modelInput must be an .osim path or an " ...
         "org.opensim.modeling.Model object."]);
end
