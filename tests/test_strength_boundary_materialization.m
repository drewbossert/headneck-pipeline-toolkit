function tests = test_strength_boundary_materialization
%TEST_STRENGTH_BOUNDARY_MATERIALIZATION Tests adaptive proposal materialization.

    tests = functiontests(localfunctions);
end


function testMaterializesAndReusesTopProposal(testCase)

    [cfg, root, cleanup] = localCreateFixture(); %#ok<ASGLU>
    proposals = localProposals();

    first = soopt.materializeBoundaryRefinement(cfg, proposals);
    second = soopt.materializeBoundaryRefinement(cfg, proposals);

    verifyEqual(testCase, first.ConfigId, "m25p_a20p");
    verifyEqual(testCase, first.MusclePercent, 25);
    verifyEqual(testCase, first.ActuatorPercent, 20);
    verifyTrue(testCase, first.Created);
    verifyFalse(testCase, second.Created);
    verifyTrue(testCase, second.ReusedExisting);
    verifyEqual(testCase, first.ConfigFile, second.ConfigFile);
    verifyEqual(testCase, first.ConfigDirectory, ...
        string(fullfile(root, "adaptive_generated")));
    verifyTrue(testCase, isfile(first.ConfigFile));
end


function testRankTwoAndMetadata(testCase)

    [cfg, root, cleanup] = localCreateFixture(); %#ok<ASGLU>
    proposals = localProposals();

    proposals.ExistingIncomplete(2) = true;
    proposals.ExistingConfigId(2) = "m30p_a15p";

    customDirectory = string(fullfile(root, "adaptive_custom"));

    selection = soopt.materializeBoundaryRefinement( ...
        cfg, proposals, ...
        "ProposalRank", 2, ...
        "ConfigDirectory", customDirectory);

    verifyEqual(testCase, selection.ConfigId, "m30p_a15p");
    verifyTrue(testCase, selection.ExistingIncomplete);
    verifyEqual(testCase, selection.ExistingConfigId, "m30p_a15p");
    verifyEqual(testCase, selection.IncrementPercent, 5);
    verifyEqual(testCase, selection.ConfigDirectory, customDirectory);
end


function testIdentityMismatchRejectedBeforeWrite(testCase)

    [cfg, root, cleanup] = localCreateFixture(); %#ok<ASGLU>
    proposals = localProposals();
    proposals.MusclePercent(1) = 30;

    verifyError(testCase, ...
        @() soopt.materializeBoundaryRefinement(cfg, proposals), ...
        "StrengthBoundaryMaterialize:ProposalIdentityMismatch");

    verifyFalse(testCase, isfile(string(fullfile( ...
        root, "adaptive_generated", "m25p_a20p.json"))));
end


function testEmptyAndMissingRankRejected(testCase)

    [cfg, ~, cleanup] = localCreateFixture(); %#ok<ASGLU>
    proposals = localProposals();

    verifyError(testCase, ...
        @() soopt.materializeBoundaryRefinement(cfg, proposals([], :)), ...
        "StrengthBoundaryMaterialize:NoProposals");

    verifyError(testCase, ...
        @() soopt.materializeBoundaryRefinement( ...
            cfg, proposals, "ProposalRank", 3), ...
        "StrengthBoundaryMaterialize:ProposalRankNotFound");
end


function proposals = localProposals()

    PriorityRank = [1; 2];
    ConfigId = ["m25p_a20p"; "m30p_a15p"];
    MusclePercent = [25; 30];
    ActuatorPercent = [20; 15];
    ExistingIncomplete = [false; false];
    ExistingConfigId = strings(2,1);
    IncrementPercent = [5; 5];

    proposals = table( ...
        PriorityRank, ConfigId, MusclePercent, ActuatorPercent, ...
        ExistingIncomplete, ExistingConfigId, IncrementPercent);
end


function [cfg, root, cleanup] = localCreateFixture()

    root = string(fullfile( ...
        tempdir, ...
        "headneck_boundary_materialize_" + ...
        string(java.util.UUID.randomUUID())));

    mkdir(root);
    cleanup = onCleanup(@() localRemoveTree(root));

    templateFile = string(fullfile(root, "m50p_a50p.json"));
    localWriteTemplate(templateFile);

    cfg = struct;
    cfg.forceCapacity = struct;
    cfg.forceCapacity.configFile = templateFile;
end


function localWriteTemplate(filePath)

    entries = repmat(localEntry(), 4, 1);

    entries(1) = localSetEntry( ...
        "stern_mast_r", "Millard2012EquilibriumMuscle", ...
        "Muscle", "Flexion", "max_isometric_force", 100, 0.50);

    entries(2) = localSetEntry( ...
        "splen_cap_r", "Millard2012EquilibriumMuscle", ...
        "Muscle", "Extension", "max_isometric_force", 80, 0.50);

    entries(3) = localSetEntry( ...
        "pitch1_reserve", "CoordinateActuator", ...
        "Actuator", "Coordinate actuator", "optimal_force", 2, 0.50);

    entries(4) = localSetEntry( ...
        "yaw1_reserve", "TorqueActuator", ...
        "Actuator", "Torque actuator", "optimal_force", 1, 0.50);

    sourceModel = struct;
    sourceModel.FileName = "synthetic.osim";
    sourceModel.FullPath = "C:\synthetic\synthetic.osim";
    sourceModel.Bytes = 1234;
    sourceModel.Modified = "synthetic";

    config = struct;
    config.Schema = "headneck-force-capacity-config";
    config.Version = 1;
    config.CreatedAt = "2026-08-31T00:00:00";
    config.Description = "synthetic template";
    config.SourceModel = sourceModel;
    config.DefaultApplyMode = "target";
    config.EntryCount = numel(entries);
    config.Entries = entries;

    try
        jsonText = jsonencode(config, "PrettyPrint", true);
    catch
        jsonText = jsonencode(config);
    end

    fid = fopen(filePath, "w");

    assert(fid >= 0, ...
        "StrengthBoundaryMaterializeTest:FileCreateFailed", ...
        "Could not create synthetic JSON:\n%s", ...
        filePath);

    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fwrite(fid, jsonText, "char");
end


function entry = localEntry()

    entry = struct( ...
        "Name", "", ...
        "ObjectType", "", ...
        "Category", "", ...
        "Group", "", ...
        "CapacityParameter", "", ...
        "CapacityAction", "preserve", ...
        "ReferenceValue", [], ...
        "TargetValue", [], ...
        "ScaleFactor", [], ...
        "UnitNote", "", ...
        "AppliesForceAction", "preserve", ...
        "ReferenceAppliesForce", true, ...
        "TargetAppliesForce", true);
end


function entry = localSetEntry( ...
        name, objectType, category, group, capacityParameter, ...
        referenceValue, scaleFactor)

    entry = localEntry();
    entry.Name = name;
    entry.ObjectType = objectType;
    entry.Category = category;
    entry.Group = group;
    entry.CapacityParameter = capacityParameter;
    entry.CapacityAction = "set";
    entry.ReferenceValue = referenceValue;
    entry.TargetValue = referenceValue * scaleFactor;
    entry.ScaleFactor = scaleFactor;
    entry.UnitNote = "synthetic";
end


function localRemoveTree(root)

    if isfolder(root)
        rmdir(root, "s");
    end
end
