# Head-Neck Pipeline Toolkit

MATLAB tools for a reproducible OpenSim head-neck reprocessing workflow. The repository supports OpenSim table and XML I/O, staged model preparation, inverse kinematics, Body Kinematics analysis, and generation of simulated head-support forces for static optimization.

The toolkit is organized as MATLAB packages so that workflow scripts can call focused, testable functions instead of directly editing OpenSim files.

## Workflow

The current single-trial workflow is organized into the following stages:

1. Build an initialization model with all coordinates unlocked and coordinate-coupler constraints enabled.
2. Run initialization inverse kinematics and review coordinate coverage, marker errors, and cervical motion.
3. Estimate stable lock values and build a constrained final-IK model.
4. Run final inverse kinematics and audit the locked and dependent coordinates.
5. Run Body Kinematics to obtain the skull center-of-mass trajectory.
6. Generate a 1000 Hz head-support-force motion file and a trial-specific `ExternalLoads` XML file.
7. Build a static-optimization model with couplers disabled and the required out-of-plane coordinates locked.

Static-optimization model construction is implemented. The final Static Optimization setup runner is still being developed, so this repository should currently be treated as a staged, QC-oriented research workflow rather than a fully unattended batch pipeline.

## Requirements

- MATLAB with support for package folders, string arrays, and `matlab.unittest`.
- OpenSim 4.5 with its MATLAB/Java bindings configured for functions that load models or execute OpenSim tools.
- Signal Processing Toolbox for Butterworth filtering, zero-phase filtering, and the optional PSD diagnostics.

The OpenSim-independent table I/O and force-generation helper tests can be run without loading an OpenSim model.

## Installation

Clone the repository and add its root directory to the MATLAB path:

```bash
git clone https://github.com/drewbossert/headneck-pipeline-toolkit.git
```

```matlab
repositoryRoot = "C:\path\to\headneck-pipeline-toolkit";
addpath(repositoryRoot);
```

Add the repository root, not the individual `+opensimio`, `+modelprep`, `+opensimrun`, or `+hsf` directories. MATLAB resolves package functions through the parent directory.

Confirm that MATLAB can find the toolkit and OpenSim bindings:

```matlab
which opensimio.readMot
which modelprep.buildInitializationModel
import org.opensim.modeling.*
```

## Configuration

Shared defaults are stored in [`config/project_defaults.m`](config/project_defaults.m). Create a machine-specific configuration before running the trial scripts:

```matlab
copyfile( ...
    fullfile(repositoryRoot, "config", "project_local_example.m"), ...
    fullfile(repositoryRoot, "config", "project_local.m"));
```

Edit `config/project_local.m` to set the raw-data location, optional output location, OpenSim installation paths, and local runtime settings. This file is ignored by Git.

Load and validate the merged configuration with:

```matlab
cfg = load_project_config();
```

For operations that only need the version-controlled defaults, the local-file requirement can be disabled:

```matlab
cfg = load_project_config("RequireLocalConfig", false);
```

Generated results are written to `output/` by default. Raw trial inputs, local configuration, and generated outputs are excluded from version control; reusable setup templates remain under `input/templates/`.

## Packages

### `opensimio` — OpenSim files and templates

Read and write `.mot` and `.sto` numeric tables while retaining labels and header metadata:

```matlab
motion = opensimio.readMot("coordinates.mot");
storage = opensimio.readSto("results.sto");

opensimio.writeMot("coordinates_copy.mot", motion);
opensimio.writeSto("results_copy.sto", storage);
```

The returned structure includes the original header, parsed metadata, column labels, numeric data, time, row and column counts, and the `inDegrees` state.

XML files can be edited through the MATLAB DOM interface:

```matlab
xmlData = opensimio.readXml("setup.xml");
nodes = xmlData.Document.getElementsByTagName("model_file");
nodes.item(0).setTextContent("trial_model.osim");
opensimio.writeXml("setup_trial.xml", xmlData);
```

Text templates use `{{PLACEHOLDER}}` tokens. Rendering is strict by default, so unresolved placeholders raise an error:

```matlab
template = opensimio.readTemplate("setup_template.xml");
values = struct( ...
    "MODEL_FILE", "trial.osim", ...
    "MARKER_FILE", "trial.trc");

rendered = opensimio.renderTemplate( ...
    template, values, "EscapeXmlValues", true);

opensimio.writeText("setup_rendered.xml", rendered);
```

See [`examples/example_io_usage.m`](examples/example_io_usage.m) for a complete example.

### `modelprep` — staged model construction and QC

The model-preparation package implements the three model states used by the workflow:

- Model A: all coordinates unlocked, constraints enabled, for initialization IK.
- Model B: root and independent out-of-plane coordinates locked, constraints enabled, for final IK.
- Model C: all required out-of-plane coordinates locked and couplers disabled, for static optimization.

```matlab
groups = modelprep.coordinateGroups();

modelprep.buildInitializationModel( ...
    baseModelFile, initializationModelFile);

lockValues = modelprep.extractStableCoordinateValues( ...
    initializationIkMotion, initializationModelFile, ...
    groups.FinalIkLocked, [0.10, 0.35]);

modelprep.buildLockedIkModel( ...
    baseModelFile, lockValues, lockedIkModelFile);

modelprep.buildStaticOptimizationModel( ...
    lockedIkModelFile, finalIkMotionFile, staticOptimizationModelFile);
```

The package also provides coordinate inspection, validation, locked-coordinate audits, motion summaries, filtering, and cutoff-sensitivity assessment. See [`examples/example_modelprep_usage.m`](examples/example_modelprep_usage.m).

### `opensimrun` — OpenSim setup and execution

This package prepares trial-specific setup files while preserving the project-specific settings in the version-controlled templates. It can execute inverse kinematics and AnalyzeTool/BodyKinematics through the OpenSim MATLAB bindings.

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

Body Kinematics can be run directly:

```matlab
analysis = opensimrun.runBodyKinematics( ...
    modelFile, ikMotionFile, resultsDirectory, ...
    "BodyNames", "skull", ...
    "ToolName", "skull_com", ...
    "SetupFile", fullfile(resultsDirectory, "analyze.xml"));
```

Create a trial-specific external-loads file from the shared template and a generated HSF motion file:

```matlab
externalLoads = opensimrun.prepareExternalLoadsSetup( ...
    cfg.externalLoadsTemplate, outputExternalLoadsFile, ...
    "DataFile", headSupportForceFile);
```

### `hsf` — simulated head-support forces

The HSF package uses the skull center-of-mass trajectory as the force application point and implements the global-coordinate force convention

```text
W  = mass * abs(gravityY)
Fy = W
Fr = W * tan(conditionAngle)
Fx = radialSign * Fr * cos(gndroll)
Fz = radialSign * Fr * sin(gndroll)
```

The azimuth convention and radial sign are configurable. Force can be turned off over verified lift-off intervals with a configurable ramp at contact transitions.

Generated loads contain the force and application-point triads only: `time`, `ground_force_1_vx/vy/vz`, and `ground_force_1_px/py/pz`. Moment columns are intentionally omitted.

Run a trial end to end from final-IK motion to the HSF `.mot` file:

```matlab
result = hsf.generateTrial( ...
    modelFile, ikMotionFile, outputDirectory, conditionAngleDeg, ...
    "SkullMassKg", 1.1704014720812095, ...
    "GravityY", -9.80665, ...
    "TargetRateHz", 1000, ...
    "OffIntervals", [liftOffTime recontactTime], ...
    "RampDuration", 0.1);
```

This retains the Body Kinematics outputs, resamples skull CoM positions, writes the HSF motion file, and validates its labels and sample rate. See [`examples/example_hsf_trial.m`](examples/example_hsf_trial.m).

## Running a single trial

The validation drivers are intended to be run section by section in the MATLAB Editor:

1. [`examples/run_single_trial_initialization_ik.m`](examples/run_single_trial_initialization_ik.m) builds Model A, runs initialization IK, produces QC reports, and saves a checkpoint for manual review.
2. [`examples/run_single_trial_model_b_filtered.m`](examples/run_single_trial_model_b_filtered.m) resumes from that checkpoint, assesses or applies lock filtering, builds Model B, runs final IK, and audits the result.
3. [`examples/example_hsf_trial.m`](examples/example_hsf_trial.m) demonstrates skull Body Kinematics and HSF generation from accepted final-IK motion.

Update the trial identity, marker file, time range, support interval, and execution flags at the beginning of each driver before running it. Review each checkpoint before continuing to the next model state.

Additional diagnostic scripts are available for lock-filter sensitivity and initialization-IK power spectral density:

- [`examples/assess_single_trial_lock_filter.m`](examples/assess_single_trial_lock_filter.m)
- [`examples/assess_initialization_ik_psd.m`](examples/assess_initialization_ik_psd.m)

## Tests

From MATLAB with the repository root on the path:

```matlab
ioResults = run_opensimio_tests();
modelprepResults = run_modelprep_tests();
hsfResults = run_hsf_tests();
```

If MATLAB test-class discovery is unavailable or unreliable, run the direct HSF checks:

```matlab
run_hsf_sanity_checks();
```

The model-preparation runner optionally accepts a real `.osim` model for an OpenSim integration smoke test:

```matlab
run_modelprep_tests(cfg.kinematicBaseModel);
```

Body Kinematics has a separate integration smoke test:

```matlab
smoke_test_body_kinematics( ...
    modelFile, ikMotionFile, outputDirectory);
```

Integration tests write generated files to temporary or explicitly supplied output directories and do not modify the source model.

## Repository layout

```text
+opensimio/    OpenSim table, XML, text, and template I/O
+modelprep/    Model construction, coordinate configuration, and QC
+opensimrun/   OpenSim setup preparation and tool execution
+hsf/          Head-support-force mechanics and motion generation
config/        Shared defaults and local configuration template
examples/      Sectioned trial drivers and focused usage examples
input/         Reusable OpenSim setup and simulated-load templates
models/        Shared OpenSim models and geometry
tests/         MATLAB unit tests and test fixtures
output/        Generated results; ignored except for .gitkeep
```

## Research-use note

This toolkit encodes project-specific model coordinates, force conventions, templates, and QC thresholds. Inspect the generated models, motion files, marker errors, coordinate audits, force intervals, and OpenSim setup files before using results in downstream analysis.

See [`CHANGELOG.md`](CHANGELOG.md) for the development history.
