function outputFile = saveModel(modelInput, outputFile, varargin)
%SAVEMODEL Validate and write an OpenSim model.
%
% outputFile = modelprep.saveModel(modelInput, outputFile)
%
% Name-value options:
%   VerifyReload  true
%   CreateFolder  true

    parser = inputParser;
    parser.FunctionName = "modelprep.saveModel";

    addRequired(parser, "modelInput");
    addRequired(parser, "outputFile", ...
        @(x) ischar(x) || (isstring(x) && isscalar(x)));

    addParameter(parser, "VerifyReload", true, ...
        @(x) islogical(x) && isscalar(x));

    addParameter(parser, "CreateFolder", true, ...
        @(x) islogical(x) && isscalar(x));

    parse(parser, modelInput, outputFile, varargin{:});

    outputFile = string(outputFile);

    [~, ~, extension] = fileparts(outputFile);

    if lower(string(extension)) ~= ".osim"
        error("modelprep:InvalidModelExtension", ...
            "Output model must use the .osim extension:\n%s", ...
            outputFile);
    end

    if parser.Results.CreateFolder
        parentFolder = fileparts(outputFile);

        if strlength(parentFolder) > 0 && ~isfolder(parentFolder)
            mkdir(parentFolder);
        end
    end

    model = modelprep.internal.resolveModel(modelInput);
    [model, ~] = modelprep.internal.finalizeAndInitialize(model);

    success = logical(model.print(char(outputFile)));

    if ~success || ~isfile(outputFile)
        error("modelprep:ModelWriteFailed", ...
            "OpenSim did not write the model successfully:\n%s", ...
            outputFile);
    end

    if parser.Results.VerifyReload
        reloaded = org.opensim.modeling.Model(char(outputFile));
        reloaded.finalizeConnections();
        reloaded.initSystem();
    end
end
