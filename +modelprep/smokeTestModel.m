function report = smokeTestModel(baseModelFile)
%SMOKETESTMODEL Exercise model preparation on a real model without IK.
%
% report = modelprep.smokeTestModel(baseModelFile)
%
% A temporary initialization model is generated, reloaded, and checked for:
%   - all coordinates unlocked;
%   - all constraints enabled.
%
% The source model is never modified.

    assert(isfile(baseModelFile), ...
        "modelprep:FileNotFound", ...
        "Base model was not found:\n%s", baseModelFile);

    temporaryFolder = tempname;
    mkdir(temporaryFolder);

    cleanupObject = onCleanup( ...
        @() rmdir(temporaryFolder, "s")); %#ok<NASGU>

    outputModel = fullfile( ...
        temporaryFolder, "initialization_test.osim");

    buildResult = modelprep.buildInitializationModel( ...
        baseModelFile, outputModel);

    inspection = buildResult.Inspection;

    allUnlocked = ...
        all(~inspection.Coordinates.DefaultLocked);

    allConstraintsEnabled = ...
        all(inspection.Constraints.PropertyEnforced);

    report = struct;
    report.AllCoordinatesUnlocked = allUnlocked;
    report.AllConstraintsEnabled = allConstraintsEnabled;
    report.BuildResult = buildResult;

    if ~allUnlocked
        error("modelprep:SmokeTestLockedCoordinates", ...
            "Initialization model contains locked coordinates.");
    end

    if ~allConstraintsEnabled
        error("modelprep:SmokeTestDisabledConstraints", ...
            "Initialization model contains disabled constraints.");
    end
end
