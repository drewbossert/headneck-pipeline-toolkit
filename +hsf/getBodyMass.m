function massKg = getBodyMass(modelInput, bodyName)
%GETBODYMASS Return a body mass from an OpenSim model.

    [model, ~] = modelprep.loadModel(modelInput);
    bodyName = string(bodyName);
    bodySet = model.getBodySet();

    if ~bodySet.contains(char(bodyName))
        error("hsf:BodyNotFound", ...
            "Body '%s' is not present in the model.", bodyName);
    end

    massKg = bodySet.get(char(bodyName)).getMass();
end
