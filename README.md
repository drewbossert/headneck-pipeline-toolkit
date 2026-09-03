# Head-Neck Pipeline Toolkit

MATLAB and OpenSim tools for a reproducible, quality-controlled infant head-neck reprocessing workflow.

The toolkit takes experimental marker trajectories through staged inverse kinematics, trial-specific model construction, simulated head-support-force (HSF) generation, Static Optimization, per-trial quality control, and optional condition-level analysis.

The current repository is project-specific to the included 4-month-old head-neck model and inclined-support study. It is a research toolkit, not a clinical application or a general-purpose OpenSim framework. Coordinate groups, model assumptions, force conventions, templates, QC tolerances, and statistical definitions should be revalidated before adapting the workflow to a different model or experimental protocol.

## Current status

The computational workflow is implemented end to end for both single-trial validation and multi-trial batch processing.

The repository uses a shared-worker architecture:

- `examples/` contains thin, interactive single-trial wrappers for validating each processing stage.
- `batch/` contains four multi-trial orchestration scripts that call the same pipeline workers.
- `+pipeline/` contains the canonical stage implementations and trial-context/path resolution.
- `run_static_optimization_analysis.m` is the final study-level QC and optional pooled-analysis wrapper.

The single-trial and batch routes therefore use the same model-building, filtering, validation, HSF, and OpenSim execution code rather than maintaining separate implementations.

## Pipeline overview

### Process 1 — Initialization IK / Model A

1. Resolve the trial identity and canonical file paths.
2. Build **Model A** from the kinematic base model.
3. Unlock all coordinates.
4. Enable coordinate-coupler constraints.
5. Prepare and execute initialization inverse kinematics.
6. Audit model structure and initialization-IK coordinate behavior.
7. Save Process-1 QC outputs and a checkpoint.

Canonical worker:

```matlab
pipeline.runInitializationIkTrial
```

### Process 2 — Locked final IK / Model B

1. Validate the completed Process-1 checkpoint.
2. Optionally filter selected initialization-IK coordinates used for lock extraction.
3. Estimate stable supported-pose values over the configured lock window.
4. Build **Model B**.
5. Lock the six root coordinates and four independent out-of-plane coordinates.
6. Keep coordinate-coupler constraints enabled.
7. Prepare and execute final IK.
8. Audit requested locks, dependent out-of-plane behavior, and sagittal motion.
9. Save Process-2 QC outputs and a checkpoint.

Canonical worker:

```matlab
pipeline.runModelBTrial
```

### Process 3 — Static Optimization preparation / Model C / HSF

1. Validate the completed Process-2 checkpoint.
2. Build **Model C** from Model B and the accepted final-IK trajectory.
3. Disable coordinate-coupler constraints.
4. Lock the root and all independent/dependent out-of-plane coordinates.
5. Leave sagittal coordinates unlocked so the final-IK sagittal trajectories drive Static Optimization.
6. Optionally apply a saved force-capacity JSON configuration to Model C.
7. Run skull Body Kinematics in ground.
8. Extract the skull center-of-mass trajectory.
9. Resample skull CoM to the configured HSF rate.
10. Detect lift-off and re-contact from the native-rate skull-CoM trajectory.
11. Generate the HSF `.mot`.
12. Generate the trial-specific `ExternalLoads` XML.
13. Generate the trial-specific Static Optimization setup XML.
14. Save Process-3 QC outputs and a checkpoint.

Canonical worker:

```matlab
pipeline.prepareStaticOptimizationTrial
```

### Process 4 — Static Optimization

1. Validate the completed Process-3 checkpoint.
2. Validate the prepared Static Optimization setup.
3. Execute the OpenSim `AnalyzeTool` setup.
4. Locate the generated force and activation `.sto` files.
5. Audit result structure and requested time coverage.
6. Save Process-4 QC outputs and a checkpoint.

Canonical worker:

```matlab
pipeline.runStaticOptimizationTrial
```

### Final analysis — per-trial QC and optional pooled analysis

The root-level wrapper:

```matlab
run_static_optimization_analysis
```

does not assume that every configured trial completed Static Optimization.

Instead, it:

1. recursively searches `projectCfg.outputRoot` for existing `*StaticOptimization_force.sto` files;
2. creates an auditable discovery manifest;
3. verifies the companion activation, Model C, and event-summary artifacts required for QC;
4. generates per-trial QC plots for every complete detected result;
5. prompts the user whether to continue into pooled/condition-level analysis;
6. warns before pooling results that appear to come from multiple batch roots; and
7. writes combined normalized waveforms, trial metrics, reserve audits, muscle-group audits, condition summaries, and mean ± SD plots when pooled analysis is requested.

Discovery is handled by:

```matlab
pipeline.discoverStaticOptimizationResults
```

## Requirements

- MATLAB with support for:
  - package folders;
  - string arrays;
  - tables;
  - JSON;
  - UI functions;
  - `matlab.unittest`.
- OpenSim 4.5 with MATLAB/Java bindings configured for model operations and tool execution.
- Signal Processing Toolbox for Butterworth filtering, zero-phase filtering, and PSD diagnostics.
- Parallel Computing Toolbox when parallel batch execution is enabled.

Many configuration, file-I/O, discovery, and contract tests do not require OpenSim execution.

## Installation

Clone the repository:

```bash
git clone https://github.com/drewbossert/headneck-pipeline-toolkit.git
```

Add the **repository root** to the MATLAB path:

```matlab
repositoryRoot = ...
    "C:\path\to\headneck-pipeline-toolkit";

addpath(repositoryRoot);
```

Do not add the individual `+package` directories directly. MATLAB resolves package functions through the repository root.

Useful checks:

```matlab
which pipeline.resolveTrialContext
which pipeline.runInitializationIkTrial
which modelprep.buildInitializationModel
which opensimrun.runStaticOptimizationSetup
which opensimio.readMot

import org.opensim.modeling.*
```

## Configuration

Configuration is loaded through:

```matlab
projectCfg = ...
    load_project_config();
```

The configuration schema is versioned and separates shared scientific settings from machine-specific settings.

### Shared project settings

Version-controlled defaults live in:

```text
config/project_defaults.m
```

These include:

- canonical conditions and trials;
- model and template locations;
- pipeline stage settings;
- lock-extraction and lock-audit tolerances;
- filtering policy;
- HSF event-detection settings;
- HSF formulation parameters;
- optional force-capacity behavior;
- Static Optimization output requirements;
- analysis normalization/statistics settings; and
- batch execution defaults.

The current canonical study matrix is:

```matlab
cfg.conditions = [0 15 30 45];
cfg.trials = 1:5;
```

The current marker filename pattern is:

```matlab
cfg.pipeline.trialInput.markerFilePattern = ...
    "%dDEG%04d.trc";
```

### Machine-specific settings

Copy:

```text
config/project_local_example.m
```

to:

```text
config/project_local.m
```

or from MATLAB:

```matlab
copyfile( ...
    fullfile( ...
        repositoryRoot, ...
        "config", ...
        "project_local_example.m"), ...
    fullfile( ...
        repositoryRoot, ...
        "config", ...
        "project_local.m"));
```

Edit only the machine-specific values in `project_local.m`, such as:

- `cfg.rawDataRoot`;
- optional `cfg.outputRoot`;
- overwrite behavior;
- batch parallel settings; and
- an optional machine-local force-capacity JSON profile.

Study/scientific settings should remain in `project_defaults.m`.

For configuration-only tests that do not require local paths:

```matlab
cfg = ...
    load_project_config( ...
        "LocalConfigPolicy", "disabled", ...
        "ValidatePaths", false);
```

## Trial context and canonical paths

All production stages use:

```matlab
trial = ...
    pipeline.resolveTrialContext( ...
        projectCfg, ...
        conditionDeg, ...
        trialNumber);
```

The resolver is the single authority for:

- trial identity;
- condition/trial naming;
- marker-file resolution;
- process directories;
- QC directories;
- expected model/setup/motion filenames; and
- checkpoint locations.

It is intentionally side-effect free: resolving a trial does not create directories or execute OpenSim.

Example:

```matlab
trial = ...
    pipeline.resolveTrialContext( ...
        projectCfg, ...
        45, ...
        1);

trial.TrialStem
% "45deg_trial01"

trial.Inputs.MarkerFile
trial.Paths.Initialization.IkMotionFile
trial.Paths.ModelB.FinalIkMotionFile
trial.Paths.StaticOptimizationPrep.ModelCFile
trial.Paths.StaticOptimization.SetupFile
```

## Running one trial interactively

The four single-trial wrappers in `examples/` are intended for staged validation and interactive review.

Run them in order:

1. [`examples/run_single_trial_initialization_ik.m`](examples/run_single_trial_initialization_ik.m)
2. [`examples/run_single_trial_model_b_filtered.m`](examples/run_single_trial_model_b_filtered.m)
3. [`examples/run_single_trial_static_optimization_prep.m`](examples/run_single_trial_static_optimization_prep.m)
4. [`examples/run_single_trial_static_optimization.m`](examples/run_single_trial_static_optimization.m)

After Static Optimization results exist, run:

5. [`run_static_optimization_analysis.m`](run_static_optimization_analysis.m)

The example drivers select a trial locally but call the same `+pipeline` workers used by the batch scripts.

### Interactive force-capacity selection in Process 3

The single-trial Process-3 wrapper prompts the user to either:

- select a saved force-capacity JSON file through a file-selection dialog; or
- continue without applying a force-capacity configuration.

A selected profile is applied to a local copy of `projectCfg` for that run only. The project configuration files are not modified.

## Running the batch pipeline

The batch drivers process the configured condition × trial matrix and call the same workers used by the single-trial examples.

Run them sequentially:

1. [`batch/batch_run_process_1.m`](batch/batch_run_process_1.m)
2. [`batch/batch_run_process_2.m`](batch/batch_run_process_2.m)
3. [`batch/batch_run_process_3.m`](batch/batch_run_process_3.m)
4. [`batch/batch_run_process_4.m`](batch/batch_run_process_4.m)

Each process validates its upstream checkpoint before continuing.

Batch behavior is controlled by:

```matlab
cfg.batchProcessing.enableParallel
cfg.batchProcessing.maxWorkers
cfg.batchProcessing.continueOnError
cfg.batchProcessing.poolProfile
cfg.batchProcessing.closePoolWhenFinished
```

When parallel execution is enabled, jobs are distributed across the configured MATLAB parallel pool.

Each batch process writes an aggregate CSV and MAT summary under:

```text
<outputRoot>/batch_qc/
```

Individual job failures are captured in the batch summary so unrelated trials can continue when:

```matlab
cfg.batchProcessing.continueOnError = true;
```

### Force-capacity selection in direct batch Process 3

Batch execution is intentionally non-interactive.

To apply a saved profile to Model C during batch processing, configure:

```matlab
cfg.forceCapacity.enabled = true;

cfg.forceCapacity.configFile = ...
    "C:\path\to\force_capacity_profile.json";

cfg.forceCapacity.applyMode = ...
    "target";

cfg.forceCapacity.requireAllEntries = ...
    true;

cfg.forceCapacity.applyStages = ...
    "modelC";
```

`target` mode is recommended for routine pipeline execution because it is idempotent. `scale` mode applies a factor to the model's current value and can compound if applied repeatedly.

`cfg.forceCapacity.configFile` selects one profile for a direct Process-3 run.
It does not define the candidate pool or template used by the Static
Optimization strength-search controller. Those resources are configured
explicitly:

```matlab
cfg.optimization.staticOptimization.fixedGrid.configDirectory = ...
    fullfile(cfg.configDirectory);

cfg.optimization.staticOptimization.adaptiveBoundary.templateConfigFile = ...
    fullfile(cfg.configDirectory, "m15p_a15p.json");

cfg.optimization.staticOptimization.adaptiveBoundary.configDirectory = ...
    fullfile(cfg.configDirectory, "adaptive_generated");
```

During a strength search, the controller selects or generates a candidate and
passes that candidate to Process 3 for the current iteration. A direct
`cfg.forceCapacity.configFile` selection is therefore not required.

## Model states

The workflow uses three explicit model states.

### Model A

- all coordinates unlocked;
- coordinate-coupler constraints enabled;
- used for initialization IK.

### Model B

- root coordinates locked;
- independent out-of-plane coordinates locked;
- coordinate-coupler constraints enabled;
- sagittal drivers remain available;
- used for final IK.

### Model C

- root coordinates locked;
- independent and dependent out-of-plane coordinates locked;
- coordinate-coupler constraints disabled;
- sagittal coordinates remain unlocked;
- used for Body Kinematics, HSF preparation, and Static Optimization.

Coordinate definitions are centralized in:

```matlab
groups = ...
    modelprep.coordinateGroups();
```

## Model-B filtering and lock extraction

The production lock-extraction policy is version controlled.

Current settings include:

```matlab
cfg.pipeline.modelB.lockWindowSec = ...
    [0.10 0.15];

cfg.qc.lockExtractionFilter.filterCoordinates = [
    "yaw1"
    "yaw2"
];

cfg.qc.lockExtractionFilter.selectedCutoffHz = ...
    1.0;
```

The production filter is a second-order Butterworth low-pass filter applied with `filtfilt`, giving a zero-phase fourth-order magnitude response.

Scientific diagnostic scripts remain available for evaluating the filtering decision:

- [`examples/assess_single_trial_lock_filter.m`](examples/assess_single_trial_lock_filter.m)
- [`examples/assess_initialization_ik_psd.m`](examples/assess_initialization_ik_psd.m)

Both diagnostics use the same trial resolver and centralized filtering configuration as the production pipeline.

## Head-support-force formulation

The validated HSF workflow uses the skull center of mass as the force application point in ground.

For skull weight:

```text
W = skullMass * abs(gravityY)
```

and support angle `theta`:

```text
Fr = W * tan(theta)

Fy = W
Fx = radialSign * Fr * cos(gndroll)
Fz = radialSign * Fr * sin(gndroll)
```

The current project configuration uses:

- body: `skull`;
- target rate: `1000 Hz`;
- interpolation: `pchip`;
- ramp duration: `0.10 s`;
- ramp shape: half cosine;
- force prefix: `ground_force_1_v`;
- point prefix: `ground_force_1_p`.

When:

```matlab
cfg.hsf.useModelBodyMass = true;
```

Process 3 reads the skull mass from the generated Model C before HSF synthesis.

### Contact-event detection

Lift-off and re-contact are detected from the **native-rate** skull-CoM trajectory using baseline-relative 3-D displacement.

The current project configuration uses:

```matlab
cfg.qc.hsfEventDetection.liftOffThresholdM = ...
    0.00150;

cfg.qc.hsfEventDetection.recontactThresholdM = ...
    0.00149;

cfg.qc.hsfEventDetection.smoothingWindowSec = ...
    0.05;
```

with sustained threshold durations of `0.10 s`.

The support force is ramped to zero around lift-off/re-contact and remains zero during the unsupported interval.

Generated HSF loads contain:

```text
time
ground_force_1_vx
ground_force_1_vy
ground_force_1_vz
ground_force_1_px
ground_force_1_py
ground_force_1_pz
```

Torque columns are intentionally omitted.

The production pipeline uses the explicit staged HSF functions:

```text
readBodyCom
resampleCom
detectContactEventsFromCom
extractCoordinateValue
generateFromResampledCom
```

to retain auditable intermediate CoM and event-detection outputs.

## Static Optimization analysis

The study-level analysis settings are stored under:

```matlab
cfg.analysis.staticOptimization
```

The current piecewise normalization is:

```text
0–20%    initial support
20–80%   active / off-support interval
80–100%  final support
```

The complete normalized waveform is retained for plotting and QC.

Reported force and reserve summary statistics use only:

```matlab
cfg.analysis.staticOptimization. ...
    statisticsWindowPercent = [20 80];
```

The functional muscle groups are read from authoritative `ObjectGroup` definitions in Model C rather than fixed output-column positions.

The current expected resolved group sizes are:

```text
Flexion:   16 bilateral muscles
Extension: 36 bilateral muscles
```

Muscles outside those explicit groups remain in the model but are excluded from the flexor/extensor sums.

The final analysis wrapper also audits non-muscle/reserve activation columns.

## Output structure

A canonical trial output tree is:

```text
<outputRoot>/
└── <condition>/
    └── <trial>/
        ├── 01_initialization_ik/
        │   └── qc/
        ├── 02_locked_final_ik/
        │   └── qc/
        ├── 03_static_optimization_prep/
        │   ├── body_kinematics/
        │   │   ├── results/
        │   │   └── qc/
        │   ├── head_support_force/
        │   │   └── qc/
        │   └── qc/
        └── 04_static_optimization/
            ├── results/
            └── qc/
                └── plots/
```

Batch-level summaries are written to:

```text
<outputRoot>/batch_qc/
```

Study-level Static Optimization analysis is written to:

```text
<outputRoot>/static_optimization_analysis/
```

including the result-discovery manifest and, when requested, combined trial/condition tables and plots.

## Package reference

### `+pipeline`

Shared workflow orchestration and study-level result discovery.

Key functions:

```matlab
pipeline.resolveTrialContext
pipeline.runInitializationIkTrial
pipeline.runModelBTrial
pipeline.prepareStaticOptimizationTrial
pipeline.runStaticOptimizationTrial
pipeline.discoverStaticOptimizationResults
```

### `+modelprep`

Model construction, coordinate configuration, validation, filtering, muscle-group resolution, locked-coordinate QC, and force-capacity tools.

Representative functions include:

```matlab
modelprep.coordinateGroups
modelprep.buildInitializationModel
modelprep.buildLockedIkModel
modelprep.buildStaticOptimizationModel
modelprep.validateModelConfiguration
modelprep.auditLockedCoordinates
modelprep.filterCoordinateMotion
modelprep.assessCoordinateFilterSensitivity
modelprep.getBilateralMuscleGroupMembers
modelprep.applyConfiguredForceCapacitiesIfEnabled
```

The package also contains an interactive force-capacity editor for building reusable JSON configurations.

### `+opensimrun`

Preparation and execution of OpenSim tools and setup files.

Representative functions include:

```matlab
opensimrun.prepareInverseKinematicsSetup
opensimrun.runInverseKinematicsSetup
opensimrun.runBodyKinematicsForCom
opensimrun.prepareExternalLoadsSetup
opensimrun.prepareStaticOptimizationSetup
opensimrun.runStaticOptimizationSetup
```

### `+opensimio`

OpenSim table, XML, text, and template I/O.

Representative usage:

```matlab
motion = ...
    opensimio.readMot("coordinates.mot");

storage = ...
    opensimio.readSto("results.sto");

opensimio.writeMot( ...
    "coordinates_copy.mot", ...
    motion);
```

See:

```text
examples/example_io_usage.m
```

for focused library examples.

### `+hsf`

Skull-CoM processing, contact-event detection, HSF mechanics, and HSF motion generation.

The production pipeline uses staged calls so the native/resampled CoM trajectories and event-detection results remain available for QC.

## Tests

Run all repository tests from MATLAB with the repository root on the path:

```matlab
results = ...
    runtests( ...
        fullfile( ...
            repositoryRoot, ...
            "tests"));

assertSuccess(results);
```

The test suite includes:

- OpenSim table-I/O tests;
- HSF helper tests;
- model-preparation helper tests;
- configuration contract tests;
- trial-context/path contract tests;
- Process-1 pipeline contract tests;
- Process-2 pipeline contract tests;
- Process-3 pipeline contract tests;
- Process-4 pipeline contract tests; and
- Static Optimization result-discovery tests.

The pipeline contract tests are intentionally lightweight and generally validate configuration, path contracts, dependencies, and worker availability without rerunning OpenSim.

## Repository layout

```text
+pipeline/      Shared pipeline workers, trial context, result discovery
+modelprep/     Model construction, coordinate/ForceSet tools, QC
+opensimrun/    OpenSim setup preparation and tool execution
+opensimio/     OpenSim table, XML, text, and template I/O
+hsf/           Skull-CoM, event detection, and HSF mechanics

batch/          Four operational multi-trial processing wrappers
config/         Version-controlled defaults and local-config template
examples/       Thin single-trial wrappers and focused diagnostics/examples
input/          Reusable OpenSim setup templates
models/         Project OpenSim models and geometry
tests/          Unit and pipeline contract tests
output/         Default generated-output root

load_project_config.m
run_static_optimization_analysis.m
```

## Recommended development pattern

When extending the toolkit:

1. put reusable scientific/model logic in the appropriate package;
2. keep `+pipeline` workers non-interactive and deterministic;
3. keep `examples/` and `batch/` as thin orchestration layers;
4. use `pipeline.resolveTrialContext()` rather than rebuilding trial paths;
5. keep study/scientific policy in `project_defaults.m`;
6. keep machine-specific settings in `project_local.m`;
7. preserve machine-readable QC and checkpoints between stages; and
8. add or update contract tests when changing the configuration or path interfaces.

## Research-use note

Inspect generated models, marker errors, coordinate audits, lock-extraction behavior, detected event times, skull-CoM trajectories, HSF directions and support intervals, force-capacity changes, reserve activations, OpenSim setup files, and output audits before interpreting downstream results.

Revalidate model assumptions, thresholds, functional muscle groups, and normalization/statistical definitions whenever the model, coordinate convention, experimental protocol, force-capacity profile, or study population changes.
