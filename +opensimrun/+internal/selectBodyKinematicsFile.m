function selectedFile = selectBodyKinematicsFile(files, quantity)
%SELECTBODYKINEMATICSFILE Select position, velocity, or acceleration file.

    files = string(files);
    quantity = lower(string(quantity));
    lowerFiles = lower(files);

    switch quantity
        case "pos"
            mask = contains(lowerFiles, "_pos_") | ...
                contains(lowerFiles, "_pos.");
        case "vel"
            mask = contains(lowerFiles, "_vel_") | ...
                contains(lowerFiles, "_vel.");
        case "acc"
            mask = contains(lowerFiles, "_acc_") | ...
                contains(lowerFiles, "_acc.");
        otherwise
            error("opensimrun:UnknownKinematicsQuantity", ...
                "Unknown BodyKinematics quantity '%s'.", quantity);
    end

    candidates = files(mask);

    if isempty(candidates)
        selectedFile = "";
        return;
    end

    globalCandidates = candidates( ...
        contains(lower(candidates), "global"));

    if ~isempty(globalCandidates)
        selectedFile = globalCandidates(1);
    else
        selectedFile = candidates(1);
    end
end
