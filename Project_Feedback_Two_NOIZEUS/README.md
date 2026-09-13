# NOIZEUS controlled Wiener experiment

The first native MATLAB experiment completed on 13 September 2026: **48 inputs, 144 SNR/STOI rows, all verification gates passed**. This is the current experiment for Yulong Chen's ELEC5305 Project.

Read the [results and interpretation](review/RESULTS.md). VAD updating gave a small mean SNR advantage and a lower mean STOI than fixed estimation. The complete evaluation set and observed limitations are reported.

## Run the code

Download this project folder with its subfolders. Open `run_noizeus_experiment.m` in MATLAB and press Run. All 54 required corpus WAVs and the verification reference data are included. Audio Toolbox is needed for MATLAB's `stoi`. The original run used MATLAB R2026a Update 5.

The runner creates a new timestamped `NOIZEUS_Results_*.zip`. It preserves the existing reviewed run in `results/run_20260913_120452`. The full saved signals from that run are inside [the original native results ZIP](evidence/NOIZEUS_Results_20260913_120452.zip), rather than duplicated beside the smaller tables and figures.

## Evidence and methods

- [Run status](results/run_20260913_120452/RUN_STATUS.txt) and [run log](results/run_20260913_120452/run_log.txt).
- [Per-case metrics](results/run_20260913_120452/metrics.csv), [paired comparisons](results/run_20260913_120452/paired_comparisons.csv) and [condition summary](results/run_20260913_120452/condition_summary.csv).
- [Frozen experiment protocol](PROTOCOL.md), [metric definitions](METRIC_GUIDE.md) and [short literature review](source_information/LITERATURE_REVIEW.md).
- [Source attribution and changes](source_information/SOURCE_AND_CHANGES.md) and [original licence](license.txt).
- [Independent review record](review/CHECKED_RESULTS.json) and [optional Python audit](review/audit_results.py). The audit requires NumPy, SciPy and pandas and reads the original MAT directly from the native ZIP.

`PROTOCOL.md` and the source/preflight notes retain their pre-run wording as an experiment record. Current completion and findings are documented in `review/RESULTS.md`. The existing implementation is credited to LIU Ming / Pascal Scalart; its TSNR branch supplies the common filter. The project change is controlled VAD-guided noise updating and its evaluation. Corpus attribution is separate from the code licence.
