function [model, state] = loadModel(modelInput)
%LOADMODEL Load or initialize an OpenSim Model.
%
% [model, state] = modelprep.loadModel(modelInput)
%
% modelInput may be:
%   - a path to an .osim file; or
%   - an org.opensim.modeling.Model object.
%
% The model is finalized and initialized before return.

    import org.opensim.modeling.*

    model = modelprep.internal.resolveModel(modelInput);
    [model, state] = modelprep.internal.finalizeAndInitialize(model);
end
