# v5 initialization-IK driver

- Added `opensimrun.prepareInverseKinematicsSetup`.
- Added `opensimrun.runInverseKinematicsSetup`.
- Added a sectioned single-trial Model A and initialization-IK validation script.
- Added coordinate-coverage and cervical-motion checkpoint reporting.

# v4 HSF test loading update

- Renamed the class-based HSF test to `TestHsfHelpers.m`.
- Removed the local function following the `classdef` block.
- Moved nearest-sample lookup into a private static class method.
- Updated `run_hsf_tests` to use `TestSuite.fromClass(?TestHsfHelpers)`.
- Added `diagnose_hsf_test_class` for path and class-loading diagnostics.
- Removed the stale `tests/test_hsf_helpers.m` file.

# v3 test compatibility update

- Replaced the HSF function-based test file with a class-based test suite.
- Updated `run_hsf_tests` to use `matlab.unittest.TestSuite.fromFile`.
- Added `run_hsf_sanity_checks` as a direct test-discovery-independent runner.
- Replaced exact floating-point time equality checks with nearest-sample lookup.

# v2 additions

- Added `+opensimrun` for programmatic AnalyzeTool/BodyKinematics execution.
- Added `+hsf` for skull CoM extraction, 1000 Hz resampling, force mechanics,
  contact envelopes, MOT creation, validation, and trial orchestration.
- Added pure MATLAB HSF tests and a separate OpenSim integration smoke test.

# Changelog

## v4

- Fixed MATLAB compatibility in `parseHeaderMetadata` and `renderTemplate`.
- Table constructors now use character-vector name/value syntax and cell-array variable names.
- No public API changes.
