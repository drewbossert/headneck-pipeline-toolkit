# Examples Folder

This folder contains example scripts for the headneck pipeline toolkit. Run the provided example scripts in the following order, section-by-section, and verify outputs at each step.

## Required execution order

1. `run_single_trial_initialization.m`
2. `run_single_trial_model_b_filtered.m`
3. `run_single_trial_static_optimization_prep.m`
4. `run_single_trial_static_optimization_test.m`
5. `run_static_optimization_plotting_pipeline.m`

## Instructions

- Execute each script section-by-section rather than running the entire file in one go.
- After each script finishes, verify that the expected outputs are generated before moving to the next script.
- The five scripts above form the main example workflow.

## Other scripts

- All other scripts in this folder are lightweight use case examples.
- They are provided to be adapted as abstractions in personalized scripts.

## Interactive utility

- If you want to run the provided interactive force scaling utility, use the app located at:
  `+modelprep/interactiveForceCapacityEditor.m`
