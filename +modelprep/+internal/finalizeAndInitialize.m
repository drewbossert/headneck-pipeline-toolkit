function [model, state] = finalizeAndInitialize(model)
%FINALIZEANDINITIALIZE Finalize model properties/connections and init state.

    try
        model.finalizeFromProperties();
    catch
        % Some wrapper versions do not require or expose this call for
        % models loaded directly from disk.
    end

    model.finalizeConnections();
    state = model.initSystem();
end
