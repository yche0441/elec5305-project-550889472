# Project Feedback Two

**Project:** Evaluation of VAD-Guided Wiener Filtering for Speech Enhancement Using Real Recordings in Everyday Noise  
**Student:** Yulong Chen | SID 550889472  
**Evidence date:** 11 September 2026

## 1. Objective

Does updating a Wiener filter's noise estimate during likely non-speech frames improve enhancement compared with keeping that estimate fixed? The comparison uses identical STFT, gain and reconstruction settings for both methods.

## 2. Work completed

The project now has a MATLAB prototype for a fixed-noise Wiener filter and an energy-VAD-guided alternative. The VAD controls when the noise power estimate is updated. Both filters use 25 ms Hamming windows, 10 ms hops, a 512-point FFT, a 0.10 gain floor and the same temporal gain smoothing. The VAD uses a 3 dB energy threshold and a five-frame hangover.

Four cases were completed in MATLAB Online R2026a Update 5. The run produced a 12-row measurement table, eight figures and twelve audio examples. Source code, six input files, source documentation and the original result archive are included. All four identity reconstruction checks passed, with relative error below 2.13e-16. The numerical evaluation agrees with the earlier independent Python check within floating-point precision.

## 3. Data and change from the proposal

The pilot uses the SpEAR utterances `butter` and `scholars`, each with factory and Volvo noise. The supplied documentation describes speech and recorded noise played through separate speakers and recorded together through a microphone. Matching clean room recordings support evaluation. These are laboratory acoustic re-recordings. They are not the student-recorded fan and traffic examples originally proposed. No noise is generated or digitally mixed by this project's MATLAB code.

The same offline noise-calibration intervals are supplied to both methods: 2.42-2.50 s for `butter` and 1.90-2.20 s for `scholars`. These intervals were selected from low energy in the aligned clean reference. This makes the pilot partly reference-assisted and offline. Only unmatched tails are trimmed; evaluation uses the original level and no time shift.

## 4. Measured results

Table 1. Reference SNR in dB from the actual MATLAB run.

| Recording | Unprocessed | Fixed Wiener | VAD-guided Wiener |
| --- | ---: | ---: | ---: |
| butter / factory | 2.99 | 7.84 | 6.99 |
| butter / volvo | 7.18 | 14.12 | 12.28 |
| scholars / factory | 9.98 | 14.90 | 13.99 |
| scholars / volvo | 13.75 | 19.96 | 19.50 |

Source: [metrics.csv](results_matlab/metrics.csv). Reference SNR is `10 log10(var(reference) / var(output - reference))`. It measures reference error, including residual noise and distortion; it is not a listening-quality score.

Both filters improved this metric relative to the input. The fixed baseline was higher in every case. Fixed-filter gains were 4.86-6.94 dB, while VAD-guided gains were 4.00-5.75 dB. A claim that VAD guidance improved performance is therefore not supported by this pilot.

The saved spectrograms use the same colour scale for all three conditions within each case. They show stronger suppression in some frequency regions with the VAD-guided method. Suppression alone does not establish better enhancement. The CSV also reports non-speech attenuation, speech-interval level changes and the runtime of individual filter calls. These runtimes come from one run and should not be used to claim a stable speed advantage.

## 5. Interpretation and limits

One possible explanation for the lower VAD result is that low-energy speech is sometimes included in the noise estimate. This is a hypothesis to test by inspecting the update decisions against the reference and listening examples. The present checks do not establish the cause.

The pilot covers two utterances and two noise recordings, each evaluated over approximately 2.25-2.63 seconds. Non-speech evaluation material outside calibration ranges from approximately 0.071 to 0.196 seconds. Those short intervals limit the reliability of the attenuation comparison. Reference-based interval labels are automatic proxies and have not been checked by listening. The matching room reference can also differ slightly from the speech component of a noisy recording.

## 6. Next work

1. Inspect and listen to frames selected for noise updating, including quiet speech regions.
2. Define one conservative change to VAD or noise updating based on the observed errors, then compare it with the current baseline using a fixed evaluation procedure.
3. Add further utterances and define any separate tuning and evaluation sets before tuning.
4. Document the final recording plan and extend the discussion with the next measured results.

## 7. Evidence and source

- [MATLAB run record](results_matlab/RUN_COMPLETED.txt)
- [Dataset summary](results_matlab/dataset_summary.csv)
- [Original MATLAB result ZIP](Project_Feedback_Two_MATLAB_Results.zip)
- [Run instructions and full method](README.md)
- [Result validation record](verification/matlab_review_validation.json)
- E. Wan, A. Nelson and R. Peterson, *Speech Enhancement Assessment Resource (SpEAR) Database*, Beta Release v1.0, CSLU, Oregon Graduate Institute of Science and Technology. The supplied [source README](source_information/README.md) and [technical description](source_information/details.md) are retained.
