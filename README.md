# Head-Neck Pipeline Toolkit

MATLAB tools for a reproducible, quality-controlled OpenSim head-neck reprocessing workflow. The current pipeline takes trial marker trajectories through staged inverse kinematics, trial-specific model construction, simulated head-support-force (HSF) generation, Static Optimization, and condition-level force summaries.

The repository is currently designed around the included 4-month-old head-neck model and inclined-support trials. Its primary use cases are:

- validating model and coordinate behavior before large analyses;
- reprocessing individual trials with explicit QC checkpoints;
- estimating cervical muscle and reserve-actuator demand during supported-to-unsupported motion;
- comparing event-normalized flexor and extensor forces across support-angle conditions; and
- developing a parallel batch workflow after the single-trial pipeline has been validated.

This is a research toolkit, not a clinical application or a general-purpose OpenSim workflow. Coordinate groups, muscle groups, force conventions, templates, and QC tolerances are project-specific.

## Current status

The single-trial workflow is implemented end to end. It can build and validate Models A, B, and C; run both IK passes and Body Kinematics; detect lift-off and re-contact; generate HSF and ExternalLoads files; prepare and execute Static Optimization; audit its outputs; and create trial- and condition-level plots and tables.

The scripts in [`batch/`](batch/) define the intended four-process batch architecture, but they are still under active development. Their trial-processing loop bodies, path resolution, parallel-pool management, progress reporting, and summary aggregation remain TODOs. Do not treat them as runnable unattended drivers yet.

## Pipeline overview

1. **Initialization IK (Model A)**
   - Unlock all coordinates and enable coordinate-coupler constraints.
   - Generate a trial-specific IK setup and run initialization IK.
   - Audit model configuration, marker errors, coordinate coverage, and cervical motion.
   - Save a checkpoint for review before creating Model B.
2. **Locked final IK (Model B)**
   - Optionally low-pass filter selected noisy initialization-IK coordinates for lock-value extraction.
   - Estimate stable values over the initial supported-pose window.
   - Lock the six root coordinates and four independent out-of-plane coordinates while keeping couplers enabled.
   - Run final IK, audit locked and dependent coordinates, summarize sagittal motion, and save a checkpoint.
3. **Static Optimization preparation (Model C and HSF)**
   - Build Model C by disabling couplers and locking the root and all independent/dependent out-of-plane coordinates at final-IK values.
   - Optionally apply a saved force-capacity configuration.
   - Run skull Body Kinematics in ground, extract its center-of-mass trajectory, and resample it to the HSF target rate.
   - Detect lift-off and re-contact from native-rate 3-D skull-CoM displacement.
   - Generate the HSF `.mot`, trial-specific `ExternalLoads` XML, and Static Optimization setup XML.
   - Save preparation QC and a Model C checkpoint.
4. **Static Optimization**
   - Execute the prepared OpenSim `AnalyzeTool` setup.
   - Locate and audit the generated force and activation `.sto` files, including structure and requested time coverage.
   - Save the output audit and run checkpoint.
5. **Post-processing**
   - Identify muscle columns from Model C rather than fixed output indices.
   - Expand configured flexion/extension `ObjectGroup` members bilaterally.
   - Audit reserve/non-muscle actuators.
   - Normalize each trial into initial support, active/off-support, and final support phases.
   - Write per-trial plots, combined tables, condition summaries, and mean +/- SD plots.

The stage boundaries are deliberate. Inspect each checkpoint and its associated CSV/XML/model outputs before continuing, especially when introducing a new model, trial type, or force-capacity configuration.

## Requirements

- MATLAB with package-folder, string-array, table, JSON, UI, and `matlab.unittest` support.
- OpenSim 4.5 with its MATLAB/Java bindings configured for model operations and tool execution.
- Signal Processing Toolbox for Butterworth filtering, zero-phase filtering, and PSD diagnostics.
- Parallel Computing Toolbox only when the batch scripts are completed and parallel execution is enabled.

OpenSim-independent table I/O and many HSF/model-preparation helper tests do not require an OpenSim model to be loaded.

## Installation

Clone the repository and add its root directory to the MATLAB path:

```bash
git clone https://github.com/drewbossert/headneck-pipeline-toolkit.git
```

```matlab
repositoryRoot = "C:\path\to\headneck-pipeline-toolkit";
addpath(repositoryRoot);
```

Add the repository root, not the individual package directories. MATLAB resolves `+opensimio`, `+modelprep`, `+opensimrun`, and `+hsf` through their parent directory.

Confirm that MATLAB can find the toolkit and OpenSim bindings:

```matlab
which opensimio.readMot
which modelprep.buildInitializationModel
which opensimrun.runStaticOptimizationSetup
import org.opensim.modeling.*
```

## Configuration

Version-controlled defaults are stored in [`config/project_defaults.m`](config/project_defaults.m). Create the required machine-local configuration:

```matlab
copyfile( ...
    fullfile(repositoryRoot, "config", "project_local_example.m"), ...
    fullfile(repositoryRoot, "config", "project_local.m"));
```

Edit `config/project_local.m` to provide a real `rawDataRoot` and any machine-specific output or OpenSim paths. The local file is ignored by Git. Then load and validate the merged configuration:

```matlab
cfg = load_project_config();
```

For an operation that only needs repository defaults, local-file and path validation can be relaxed explicitly:

```matlab
cfg = load_project_config( ...
    "RequireLocalConfig", false, ...
    "ValidatePaths", false);
```

Important configuration groups include:

- `cfg.qc.lockExtraction` and `cfg.qc.lockExtractionFilter` for Model B lock estimation;
- `cfg.qc.lockAudit` for locked-coordinate validation;
- `cfg.qc.hsfEventDetection` for CoM-based contact-event detection;
- `cfg.forceCapacity` for optional JSON-based ForceSet changes; and
- `cfg.conditions`, `cfg.trials`, and `cfg.batchProcessing` for the developing batch workflow.

Generated results are written to `output/` unless `cfg.outputRoot` is overridden. Raw trials belong under the configured raw-data root or `input/trial_data/`; generated outputs and local configuration are excluded from version control.

## Running the validated single-trial workflow

The main example drivers are sectioned scripts intended to be run from the MATLAB Editor. Set the trial identity, paths, time windows, and execution/overwrite flags near the beginning of each script.

Run them in this order:

1. [`examples/run_single_trial_initialization_ik.m`](examples/run_single_trial_initialization_ik.m) builds Model A, prepares and runs initialization IK, writes QC tables, and saves the Phase A checkpoint.
2. [`examples/run_single_trial_model_b_filtered.m`](examples/run_single_trial_model_b_filtered.m) resumes from Phase A, filters selected lock-extraction trajectories when enabled, builds Model B, runs final IK, audits the result, and saves the Model B checkpoint.
3. [`examples/run_single_trial_static_optimization_prep.m`](examples/run_single_trial_static_optimization_prep.m) builds and validates Model C, runs Body Kinematics, detects contact events, generates HSF and ExternalLoads, prepares the Static Optimization XML, and saves the Model C/HSF checkpoint.
4. [`examples/run_single_trial_static_optimization_test.m`](examples/run_single_trial_static_optimization_test.m) executes one previously prepared and manually reviewed Static Optimization setup and audits the force/activation outputs.
5. [`examples/run_static_optimization_plotting_pipeline.m`](examples/run_static_optimization_plotting_pipeline.m) processes whichever completed trials are available, creates per-trial diagnostics, and aggregates condition-level results.

[`examples/run_single_trial_static_optimization_prep_force_config_test.m`](examples/run_single_trial_static_optimization_prep_force_config_test.m) is the preparation variant for validating an optional saved force-capacity configuration before it is incorporated into routine processing.

A typical output tree is:

```text
output/<condition>/<trial>/
|-- 01_initialization_ik/
|-- 02_locked_final_ik/
|-- 03_static_optimization_prep/
|   |-- body_kinematics/
|   |-- head_support_force/
|   `-- qc/
`-- 04_static_optimization/
    |-- results/
    `-- qc/

output/static_optimization_analysis/
```

The scripts default to project validation trials and may contain trial-specific settings. Review Section 0 in every driver rather than running the files unchanged.

## Batch workflow under development

The batch scripts mirror the validated single-trial stages and are intended to process every configured condition/trial combination. The current planned contract is:

| Script | Intended responsibility | Expected handoff | Current implementation status |
| --- | --- | --- | --- |
| [`batch_run_process_1.m`](batch/batch_run_process_1.m) | Build Model A, prepare/run initialization IK, validate essential outputs, and collect timing/summary records for each trial. | Phase A model, IK motion/setup, and machine-readable QC/checkpoint data. | Configuration scaffold and placeholder nested `parfor`/trial loop only. |
| [`batch_run_process_2.m`](batch/batch_run_process_2.m) | Read accepted Process 1 results, filter/extract supported-pose lock values, build Model B, run final IK, and audit locked/dependent coordinates. | Model B, final-IK motion/setup, lock/QC tables, and Model B checkpoint. | Configuration scaffold and placeholder nested `parfor`/trial loop only. |
| [`batch_run_process_3.m`](batch/batch_run_process_3.m) | Read accepted Model B results; build Model C; optionally apply force capacities; run skull Body Kinematics; detect events; generate HSF, ExternalLoads, and the trial-specific Static Optimization setup. | Validated Model C, HSF artifacts, SO setup, preparation QC, and checkpoint. | Configuration scaffold and placeholder nested `parfor`/trial loop only. |
| [`batch_run_process_4.m`](batch/batch_run_process_4.m) | Execute prepared Static Optimization analyses, which may take about 20 minutes per trial, then audit outputs and aggregate run summaries. | Force/activation `.sto` files, output-audit tables, timings, and batch status. | Execution guard and progress message only; no condition/trial loop yet. |

Before these drivers are ready for production, each needs deterministic input/output resolution, preflight validation of upstream checkpoints, overwrite/resume behavior, correct iteration over `cfg.conditions` and `cfg.trials`, parallel-pool handling through `cfg.batchProcessing`, error isolation, and consolidated status/timing reports. Until then, use the single-trial drivers as the executable reference implementation.

The plotting pipeline already supports multiple trials and conditions, skips missing trials, permits explicit exclusions, and can be used after manually or eventually batch-generated Static Optimization results.

## Package reference

### `opensimio`: OpenSim files and templates

Read and write `.mot` and `.sto` numeric tables while retaining labels and header metadata:

```matlab
motion = opensimio.readMot("coordinates.mot");
storage = opensimio.readSto("results.sto");

opensimio.writeMot("coordinates_copy.mot", motion);
opensimio.writeSto("results_copy.sto", storage);
```

The package also reads/writes XML and UTF-8 text, and performs strict `{{TOKEN}}` template rendering. See [`examples/example_io_usage.m`](examples/example_io_usage.m).

### `modelprep`: model construction, force capacities, and QC

The three model states are:

- **Model A:** all coordinates unlocked, constraints enabled, for initialization IK.
- **Model B:** root and independent out-of-plane coordinates locked, constraints enabled, for final IK.
- **Model C:** root and all out-of-plane coordinates locked, couplers disabled, for Static Optimization.

```matlab
groups = modelprep.coordinateGroups();

modelprep.buildInitializationModel(baseModelFile, modelAFile);

lockValues = modelprep.extractStableCoordinateValues( ...
    initializationIkMotion, modelAFile, ...
    groups.FinalIkLocked, [0.10, 0.15]);

modelprep.buildLockedIkModel(baseModelFile, lockValues, modelBFile);
modelprep.buildStaticOptimizationModel(modelBFile, finalIkFile, modelCFile);
```

Additional utilities inspect and validate models, audit locked coordinates, summarize/filter motion, assess cutoff sensitivity, resolve bilateral muscle groups, and inspect/edit ForceSet capacity values. The interactive editor can save reusable JSON configurations containing exact target values or scale factors; `target` application is recommended for idempotent pipeline runs.

### `opensimrun`: OpenSim setup and execution

This package prepares trial-specific IK, ExternalLoads, and Static Optimization XML files while preserving scientific settings in the shared templates. It executes IK, Body Kinematics/AnalyzeTool, and Static Optimization through the OpenSim MATLAB bindings.

```matlab
setup = opensimrun.prepareStaticOptimizationSetup( ...
    cfg.staticOptimizationTemplate, outputSetupFile, ...
    "ModelFile", modelCFile, ...
    "CoordinatesFile", finalIkFile, ...
    "ExternalLoadsFile", externalLoadsFile, ...
    "ResultsDirectory", resultsDirectory);

run = opensimrun.runStaticOptimizationSetup( ...
    setup.OutputFile, "Overwrite", false);
```

`runStaticOptimizationSetup` verifies the setup structure, executes `AnalyzeTool`, locates force and activation results, and checks their structure and time range.

### `hsf`: simulated head-support forces

The HSF model balances skull weight in global `+Y` while adding the radial force required by the inclined support condition:

```text
W  = skullMass * abs(gravityY)
Fr = W * tan(conditionAngle)
Fy = W
Fx = radialSign * Fr * cos(gndroll)
Fz = radialSign * Fr * sin(gndroll)
```

The force application point follows the skull CoM in ground. The default output rate is 1000 Hz. A half-cosine support envelope ramps force to zero before detected lift-off, keeps it off during the unsupported interval, and restores it after re-contact.

Generated load files contain `time`, the three `ground_force_1_v*` components, and the three `ground_force_1_p*` application-point components. Torque columns are intentionally omitted.

The package supports both an end-to-end convenience call (`hsf.generateTrial`) and explicit staged calls for QC (`readBodyCom`, `resampleCom`, `detectContactEventsFromCom`, and `generateFromResampledCom`). The validated pipeline uses the explicit staged route so raw/resampled CoM and event detection can be reviewed.

## Tests and diagnostics

With the repository root on the MATLAB path, run all checked-in unit tests with:

```matlab
results = runtests(fullfile(repositoryRoot, "tests"));
assertSuccess(results);
```

Some tests are OpenSim-independent; model integration and the executable example drivers require configured OpenSim bindings and appropriate trial data.

Additional diagnostic scripts include:

- [`examples/assess_single_trial_lock_filter.m`](examples/assess_single_trial_lock_filter.m) for lock-filter cutoff sensitivity;
- [`examples/assess_initialization_ik_psd.m`](examples/assess_initialization_ik_psd.m) for initialization-IK spectral diagnostics; and
- [`examples/example_audit_locked_coordinates.m`](examples/example_audit_locked_coordinates.m) for focused locked-coordinate auditing.

## Repository layout

```text
+opensimio/    OpenSim table, XML, text, and template I/O
+modelprep/    Model construction, force-capacity tools, and QC
+opensimrun/   OpenSim setup preparation and tool execution
+hsf/          Contact detection and head-support-force generation
batch/         Four-stage batch orchestration scaffolds under development
config/        Shared defaults and local configuration template
examples/      Sectioned validation drivers, plotting, and focused examples
input/         Reusable OpenSim templates and local trial-data location
models/        Project OpenSim models and geometry
tests/         MATLAB unit tests and fixtures
output/        Generated results; ignored except for `.gitkeep`
```

## Research-use note

Inspect generated models, motion files, marker errors, coordinate audits, detected event times, HSF directions and intervals, force-capacity changes, reserve activations, and OpenSim setup files before interpreting downstream results. Revalidate the assumptions and thresholds whenever the model, experimental protocol, coordinate convention, or trial population changes.
