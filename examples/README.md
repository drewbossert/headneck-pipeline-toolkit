# Examples Folder

This folder contains example scripts for the headneck pipeline toolkit. Run the provided example scripts in the following order, section-by-section, and verify outputs at each step. Note that the last script lives in the root folder. This script will scrape the outputs of your analysis to detect static optimization force results and produce quality control plots and perform statistical analysis if requested.

## Required execution order

1. `../examples/run_single_trial_initialization_ik.m`
2. `../examples/run_single_trial_model_b_filtered.m`
3. `../examples/run_single_trial_static_optimization_prep.m`
4. `../examples/run_single_trial_static_optimization.m`
5. `../run_static_optimization_analysis.m`

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
