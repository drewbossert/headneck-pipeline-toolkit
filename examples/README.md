# Examples

This folder contains the interactive single-trial wrappers and focused diagnostic/library examples for the head-neck pipeline toolkit.

For the complete repository architecture, configuration contract, batch workflow, HSF formulation, QC outputs, and analysis definitions, see the root [`README.md`](../README.md).

## Single-trial pipeline workflow

Use the four single-trial wrappers to validate the pipeline interactively before or alongside batch execution.

Run them in order:

1. [`run_single_trial_initialization_ik.m`](run_single_trial_initialization_ik.m)
   - Process 1
   - builds Model A;
   - runs initialization IK;
   - writes initialization-IK QC and checkpoint outputs.

2. [`run_single_trial_model_b_filtered.m`](run_single_trial_model_b_filtered.m)
   - Process 2
   - applies the configured lock-extraction filtering;
   - extracts supported-pose lock values;
   - builds Model B;
   - runs final IK;
   - audits locked, dependent out-of-plane, and sagittal coordinate behavior.

3. [`run_single_trial_static_optimization_prep.m`](run_single_trial_static_optimization_prep.m)
   - Process 3
   - builds Model C;
   - optionally applies a saved force-capacity JSON configuration;
   - runs skull Body Kinematics;
   - extracts/resamples skull CoM;
   - detects lift-off and re-contact;
   - generates the head-support-force MOT;
   - generates the trial-specific `ExternalLoads` XML and Static Optimization setup XML.

4. [`run_single_trial_static_optimization.m`](run_single_trial_static_optimization.m)
   - Process 4
   - validates the Process-3 outputs;
   - executes Static Optimization;
   - audits the generated force and activation STO files.

All four wrappers call the same functions in `+pipeline` that are used by the scripts in `batch/`. They are therefore interactive front ends to the production implementation rather than independent processing pipelines.

### Running the wrappers

The wrappers are organized into MATLAB sections so that intermediate results can be reviewed during development or troubleshooting.

For routine use:

- select the desired `conditionDeg` and `trialNumber` near the top of each wrapper;
- execute the script section-by-section when manual inspection is useful;
- verify the reported QC outputs before progressing to the next stage.

Trial identity and output paths are resolved by:

```matlab
pipeline.resolveTrialContext
```

Do not manually reconstruct condition/trial output paths in new example or diagnostic scripts.

## Final Static Optimization analysis

The final QC and optional pooled-analysis wrapper is intentionally located at the repository root:

[`../run_static_optimization_analysis.m`](../run_static_optimization_analysis.m)

It searches the project output tree for existing Static Optimization force results rather than assuming that every configured trial completed.

The wrapper:

- creates a discovery manifest;
- identifies complete result sets;
- generates per-trial QC plots;
- prompts the user before performing pooled/condition-level analyses; and
- warns if detected results appear to span multiple batch roots.

## Scientific diagnostics

The following scripts are diagnostic tools tied to the current production configuration.

### [`assess_single_trial_lock_filter.m`](assess_single_trial_lock_filter.m)

Assesses lock-extraction filter sensitivity for a selected initialization-IK trial.

It uses:

```matlab
pipeline.resolveTrialContext
projectCfg.pipeline.modelB.lockWindowSec
projectCfg.qc.lockExtraction
projectCfg.qc.lockExtractionFilter
```

so the diagnostic uses the same lock window, coordinates, candidate cutoffs, and tolerances as Process 2.

It does not modify pipeline data.

### [`assess_initialization_ik_psd.m`](assess_initialization_ik_psd.m)

Evaluates the frequency content of the configured initialization-IK assessment coordinates using Welch PSD analysis.

It uses the current production assessment coordinates and candidate cutoff frequencies from:

```matlab
projectCfg.qc.lockExtractionFilter
```

The historical 5- and 10-Hz thresholds are retained only as additional PSD reporting frequencies; they are not production filter candidates.

It does not modify pipeline data.

## Library/API examples

The remaining `example_*` scripts demonstrate lower-level package APIs outside the production pipeline.

### [`example_io_usage.m`](example_io_usage.m)

Demonstrates representative `+opensimio` operations such as:

- reading/writing MOT files;
- reading/writing STO files;
- editing XML through DOM methods; and
- rendering text/XML templates.

The paths in this script are placeholders and must be replaced before execution.

### [`example_modelprep_usage.m`](example_modelprep_usage.m)

Demonstrates representative `+modelprep` model-building calls for Model A, Model B, and Model C.

This is an API illustration, not an alternate project workflow. The production scientific settings and canonical trial paths are defined by `projectCfg` and the `+pipeline` workers.

## Force-capacity editor

The interactive force-capacity utility is:

```matlab
modelprep.interactiveForceCapacityEditor
```

Related inspection/configuration functions include:

```matlab
modelprep.inspectForceCapacities
modelprep.saveForceCapacityConfig
modelprep.loadForceCapacityConfig
modelprep.applyForceCapacityConfig
```

Saved JSON configurations can be selected interactively by the Process-3 single-trial wrapper or configured non-interactively for Batch Process 3.

## Development convention

When adding examples or diagnostics:

- use `load_project_config()` for shared project settings;
- use `pipeline.resolveTrialContext()` for trial paths;
- avoid duplicating model-building or OpenSim execution logic already implemented in `+pipeline`;
- keep interactive/UI behavior in examples rather than in pipeline workers; and
- make it explicit when a script is diagnostic-only and does not modify production data.
