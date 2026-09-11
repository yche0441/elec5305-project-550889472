# Project Feedback Two: preliminary implementation

**Project:** Evaluation of VAD-Guided Wiener Filtering for Speech Enhancement Using Real Recordings in Everyday Noise  
**Student:** Yulong Chen, SID 550889472  
**Status:** Four pilot cases completed in MATLAB Online on 11 September 2026, using MATLAB R2026a Update 5. Actual outputs are included and have been checked.

## 1. Objective

Compare a fixed-noise Wiener filter with an energy-VAD-guided noise update under the same settings. The modification being tested is the noise update. Neither method is assumed to perform better.

## 2. Run in MATLAB

Upload the entire `Project_Feedback_Two` folder to MATLAB Drive. Open `run_project_feedback2.m` and click **Run**. The included version was run successfully in MATLAB Online R2026a Update 5. The signal-processing calculations use base MATLAB functions; figures use `tiledlayout` and `exportgraphics`.

The runner saves:

- `results_matlab/metrics.csv`: twelve rows, covering four input cases and three methods.
- `results_matlab/dataset_summary.csv`: sample counts, evaluation lengths and calibration intervals.
- `results_matlab/figures/`: comparable spectrograms and VAD diagnostics.
- `results_matlab/listening/`: original, fixed and adaptive audio for each case.
- `results_matlab/RUN_COMPLETED.txt`: MATLAB version and completion time, created only after all cases finish.
- `Project_Feedback_Two_MATLAB_Results.zip`: a convenient copy of those MATLAB outputs.

Run the script once. Eight figures are expected. The code does not automatically play sound or require a microphone. After rerunning, only this experiment's output files are overwritten. Existing unrelated files are not used.

## 3. Pilot data and change from the proposal

The proposal planned student recordings of a fan and traffic. This first implementation uses the already supplied SpEAR database to test the processing steps. This is a stated pilot-data change, not evidence that the proposed field recordings have been collected.

Two utterances, `butter` and `scholars`, each have a factory-noise and a Volvo-noise acoustic re-recording plus a matching clean room reference. These utterances differ from the `bigtips`, `draw` and `peaches` examples used in Report One. SpEAR's documentation says the speech and recorded noise were played through separate monitors and re-recorded synchronously with a microphone. Factory noise originated in a car production hall; the Volvo recording was made inside a moving car. These are not student-recorded fan or open-window traffic clips. No generated white/pink/burst noise is used, and the submitted code does not digitally mix speech and noise.

The input WAVs retain the original archive names and bytes. All are mono, 16-bit, 16 kHz. When lengths differ, only the unmatched tail is excluded from the evaluation. No time shift, gain fitting or per-output normalisation is applied to the numerical measurements. The independent check found zero-sample peak correlation delay for all four pairs within a +/-199-sample search. This supports sample alignment; the room-reference error remains a limitation.

## 4. Processing choices

1. Use 25 ms Hamming windows, 10 ms hops and a 512-point FFT. Pad and normalise weighted overlap-add so that an identity spectral gain reconstructs the original samples.
2. Estimate the initial noise power from the same annotated interval for both methods. The pilot intervals are 2.42-2.50 s for `butter` and 1.90-2.20 s for `scholars`. They were selected by inspecting low energy in the aligned reference and fixed before outcome comparison. They have not been validated by a listening test.
3. Estimate non-negative speech-to-noise ratio as `xi = max(observedPower/noisePower - 1, 0)`. Use Wiener amplitude gain `xi/(1+xi)`, with a 0.10 floor and temporal gain smoothing of 0.60.
4. Hold the baseline noise power fixed. For the adaptive method, compare frame energy with the current noise estimate using a 3 dB threshold and five-frame hangover. Update the noise spectrum with coefficient 0.90 only on complete, likely non-speech frames outside the calibration interval.
5. Reconstruct using observed phase and identical synthesis for both methods.

The late noise pause makes this an **offline** experiment. It does not implement the proposal's planned 5-10 s opening noise segment or a causal live-input workflow. Both methods receive the same annotation. The clean reference does not enter `wiener_enhance`; it supplies the pilot annotation and evaluation proxies, so this is not a fully reference-free test.

The implementation is a simplified Wiener comparison. It is not a reproduction of Ephraim-Malah MMSE-STSA, statistical VAD, or minima-controlled recursive averaging. The papers in the proposal motivate the investigation; their full methods are not claimed as implemented.

## 5. Measures and limits

| Measure | Interpretation |
| --- | --- |
| Reference SNR | `10 log10(var(reference)/var(processed-reference))`, following the supplied SpEAR convention, over the common record. Penalises noise and signal distortion; not a perceptual score. |
| Reference SNR gain | Difference from the unprocessed input, using unchanged scale. |
| Non-speech attenuation | Input/output power ratio in reference-energy-selected low-speech intervals, excluding calibration. Higher attenuation alone does not establish better speech quality. |
| Speech level change | Output/input power ratio during high-reference-energy intervals, excluding calibration. Includes speech and noise; not a direct measure of preserved speech alone. |
| Runtime | Time for a single enhancement call in MATLAB, excluding figures and file exports; includes STFT. Preliminary and affected by timing variability. |
| Noise update fraction | Fraction of complete non-calibration frames used for adaptive noise estimation. |

Reference-energy thresholds are -35 dB and -25 dB relative to peak smoothed reference energy. The middle region is excluded from interval metrics. These are automatic proxies, not phonetic ground truth or manually checked VAD labels. The non-speech evaluation material is short, particularly for `butter/volvo`; those figures should not support broad conclusions. Reference SNR includes the calibration region, while interval-based metrics exclude it.

## 6. Actual MATLAB results and verification

The run completed in MATLAB Online on 11 September 2026. The original execution record identifies MATLAB `26.1.0.3346908 (R2026a) Update 5`. The archived clock time is retained exactly; its time zone is not recorded in that text file.

The result folder contains 12 metric rows, 8 PNG figures, 12 mono 16 kHz listening WAVs, 5 MAT files, 2 CSV files and the completion record. All four STFT identity checks passed. The largest relative reconstruction error was approximately 2.13e-16.

Reference SNR in dB, rounded from the actual MATLAB CSV:

| Recording | Unprocessed | Fixed Wiener | VAD-guided Wiener |
| --- | ---: | ---: | ---: |
| butter / factory | 2.99 | 7.84 | 6.99 |
| butter / volvo | 7.18 | 14.12 | 12.28 |
| scholars / factory | 9.98 | 14.90 | 13.99 |
| scholars / volvo | 13.75 | 19.96 | 19.50 |

Both methods increased reference SNR for all four recordings. The fixed baseline exceeded VAD-guided filtering in all four cases, by approximately 0.45-1.84 dB. This result does not support an advantage for adaptive updating with the current parameters. It is a preliminary comparison of four recordings, not a general ranking of the methods.

The prior independent Python implementation agrees with the six shared numerical evaluation fields to within 4.3e-14. Python checks are retained separately under `verification/`; the results in the table above come from the uploaded MATLAB run. All 12 exported listening files have the expected lengths and sample rate, and none reaches a PCM16 clipping limit. The original listening samples match the corresponding cropped inputs. No subjective speech-quality judgment has been made.

The VAD figures include padded edge frames in their energy-ratio trace. Those frames can have very low ratios and extend the time axis beyond the recording; they are excluded from noise adaptation. The figures and MATLAB result files are retained without alteration.

`verification/matlab_review_validation.json` records the result checks. The four MATLAB source files and six input WAVs are byte-identical to the first run package. No parameter or algorithm changes were made for this update.

## 7. Source acknowledgement

E. Wan, A. Nelson and R. Peterson, *Speech Enhancement Assessment Resource (SpEAR) Database*, Beta Release v1.0, CSLU, Oregon Graduate Institute of Science and Technology. The original [README](source_information/README.md) and [technical description](source_information/details.md) are retained. The supplied archive was obtained from the [SpEAR repository](https://github.com/dingzeyuli/SpEAR-speech-database).

Background references remain those of the original proposal, including Scalart and Filho, ICASSP 1996, DOI 10.1109/ICASSP.1996.543199; Ephraim and Malah, 1984, DOI 10.1109/TASSP.1984.1164453; Sohn et al., 1999, DOI 10.1109/97.736233; Cohen and Berdugo, 2002, DOI 10.1109/97.988717.

## 8. Next checkpoint

Inspect the frames used for noise updates, then define one conservative change to the VAD or noise update based on that diagnosis. Freeze the evaluation procedure before testing the change, and include additional utterances to check whether the observation extends beyond this pilot. Any separate tuning and evaluation sets should be defined before that work begins. Document whether the final data collection retains the SpEAR acoustic recordings or adds the originally planned live recordings.

The checkpoint materials include preliminary code, measured outcomes, examples and a progress description. Publication to the GitHub project and submission of the brief description with its site link are separate steps.
