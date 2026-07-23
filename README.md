# OpenSim MATLAB I/O Toolkit

A small MATLAB namespace for parsing and writing OpenSim workflow files.

## Installation

Add the toolkit root to the MATLAB path:

```matlab
addpath("C:\path\to\opensimio_toolkit");
```

Do not add the `+opensimio` directory directly. MATLAB resolves package
functions through the toolkit root.

## Public functions

### OpenSim numeric tables

```matlab
motion = opensimio.readMot("coordinates.mot");
storage = opensimio.readSto("results.sto");

opensimio.writeMot("coordinates_copy.mot", motion);
opensimio.writeSto("results_copy.sto", storage);
```

Both wrappers use the shared functions:

```matlab
data = opensimio.readOpenSimTable(filePath);
opensimio.writeOpenSimTable(filePath, data);
```

The returned structure contains header lines, parsed metadata, labels, numeric
data, time, and `inDegrees`.

### XML

```matlab
xmlData = opensimio.readXml("setup.xml");

nodes = xmlData.Document.getElementsByTagName("model_file");
nodes.item(0).setTextContent("trial_model.osim");

opensimio.writeXml("setup_trial.xml", xmlData);
```

### Text templates

Template placeholders use the form:

```text
{{MODEL_FILE}}
{{MARKER_FILE}}
{{OUTPUT_FILE}}
```

Render them with:

```matlab
template = opensimio.readTemplate("setup_template.xml");

values = struct( ...
    "MODEL_FILE", "trial.osim", ...
    "MARKER_FILE", "trial.trc", ...
    "OUTPUT_FILE", "trial_ik.mot");

rendered = opensimio.renderTemplate( ...
    template, values, ...
    "EscapeXmlValues", true);

opensimio.writeText("setup_rendered.xml", rendered);
```

`Strict=true` by default, so unresolved placeholders produce an error.

## Tests

From the toolkit root:

```matlab
results = runtests("tests");
table(results)
```

## Recommended role in the reprocessing pipeline

Keep these functions limited to file I/O. Trial-specific operations such as
coordinate locking, constraint configuration, IK setup patching, support-force
generation, and quality control should live in separate workflow packages or
scripts that call this namespace.

Internal parsing helpers are stored in `+opensimio/+internal` and are not intended as the workflow-facing API.


# Model preparation package

The toolkit now also contains `+modelprep`, which manages OpenSim model
properties for the head-neck reprocessing workflow.

```matlab
addpath("C:\path\to\headneck_pipeline_toolkit");

groups = modelprep.coordinateGroups();

initialization = modelprep.buildInitializationModel( ...
    baseModelFile, initializationModelFile);

lockValues = modelprep.extractStableCoordinateValues( ...
    initializationIkMotion, initializationModelFile, ...
    groups.FinalIkLocked, [0.00, 0.25]);

lockedIk = modelprep.buildLockedIkModel( ...
    baseModelFile, lockValues, lockedIkModelFile);

staticOptimization = modelprep.buildStaticOptimizationModel( ...
    lockedIkModelFile, finalIkMotionFile, soModelFile);
```

Run package tests:

```matlab
results = run_modelprep_tests();

% Optional OpenSim integration smoke test:
results = run_modelprep_tests("C:\path\to\base_model.osim");
```

The smoke test writes only to a temporary directory and does not modify the
source model.


# Body Kinematics and head-support-force packages

## Body Kinematics

`+opensimrun` configures and executes OpenSim's AnalyzeTool with a
BodyKinematics analysis:

```matlab
analysis = opensimrun.runBodyKinematics( ...
    modelFile, ikMotionFile, resultsDirectory, ...
    "BodyNames", "skull", ...
    "ToolName", "skull_com", ...
    "SetupFile", fullfile(resultsDirectory, "analyze.xml"));
```

The result includes the generated position, velocity, and acceleration files.
The HSF workflow uses `PositionFile` for the skull center-of-mass trajectory.

## Head-support force

`+hsf` implements the global-coordinate support-force convention:

```text
Fy = W
Fr = W*tan(conditionAngle)
Fx = sign*Fr*cos(gndroll)
Fz = sign*Fr*sin(gndroll)
```

where `W = mass*abs(gravityY)`. The azimuth convention and radial sign are
configurable.

Run one trial end-to-end:

```matlab
result = hsf.generateTrial( ...
    modelFile, ikMotionFile, outputDirectory, conditionAngleDeg, ...
    "SkullMassKg", 1.1704014720812095, ...
    "GravityY", -9.80665, ...
    "OffIntervals", [liftOffTime, recontactTime], ...
    "RampDuration", 0.1);
```

This retains the BodyKinematics outputs, resamples skull CoM positions to
1000 Hz, constructs the HSF force and application-point columns, writes the
`.mot` file, and validates its labels and sample rate.

Pure MATLAB tests:

```matlab
results = run_hsf_tests();
```

OpenSim integration smoke test:

```matlab
result = smoke_test_body_kinematics( ...
    modelFile, ikMotionFile, outputDirectory);
```


# Single-trial initialization IK

The example script below is intended to be run section-by-section:

```text
examples/run_single_trial_initialization_ik.m
```

It performs only the first validation phase:

1. validates toolkit and source files;
2. creates a trial output structure;
3. builds Model A with all coordinates unlocked and constraints enabled;
4. validates and audits Model A;
5. copies and patches a known-working IK setup template;
6. runs initialization IK;
7. audits coordinate coverage and excursions; and
8. saves a checkpoint for manual visual review.

The associated `+opensimrun` functions are:

```matlab
setup = opensimrun.prepareInverseKinematicsSetup( ...
    templateFile, outputSetupFile, ...
    "ModelFile", modelFile, ...
    "MarkerFile", markerFile, ...
    "OutputMotionFile", outputMotionFile, ...
    "TimeRange", [startTime endTime]);

run = opensimrun.runInverseKinematicsSetup( ...
    outputSetupFile, ...
    "ExpectedOutputMotionFile", outputMotionFile);
```
