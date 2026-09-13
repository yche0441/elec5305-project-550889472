# When does VAD-guided noise updating improve Wiener speech enhancement?

**ELEC5305 Project · Yulong Chen · SID 550889472 · GitHub yche0441**

[Project website](https://yche0441.github.io/elec5305-project-550889472/) · [Detailed progress and results](Project_Feedback_Two_NOIZEUS/review/RESULTS.md) · [Working MATLAB code](Project_Feedback_Two_NOIZEUS/run_noizeus_experiment.m)

## Project Feedback Two progress

Following Craig Jin's feedback, the project reproduced an existing Wiener enhancement implementation and moved the main quantitative experiment to paired NOIZEUS clean/noisy speech. The controlled comparison uses the same TSNR processing in both modes and changes only whether the noise PSD is updated following an energy-VAD non-speech decision. The earlier proposal describes the initial plan; the NOIZEUS experiment is the current quantitative method.

The native MATLAB run completed on 13 September 2026, with 48 input cases and 144 complete SNR/STOI rows. There are six sentences, car/street noise and four nominal SNR levels. Two sentences form the development set; four other speakers' sentences form the 32-case evaluation set.

## Initial findings

These means use 16 evaluation cases per noise type and method.

| Noise | Method | Mean reference SNR (dB) | Mean SNR gain over input (dB) | Mean STOI |
| --- | --- | ---: | ---: | ---: |
| Car | Unprocessed | 7.103 | +0.000 | 0.7959 |
| Car | Fixed TSNR Wiener | 10.814 | +3.711 | 0.7964 |
| Car | VAD-updated TSNR Wiener | 10.863 | +3.760 | 0.7891 |
| Street | Unprocessed | 7.207 | +0.000 | 0.8234 |
| Street | Fixed TSNR Wiener | 9.656 | +2.449 | 0.8029 |
| Street | VAD-updated TSNR Wiener | 9.800 | +2.593 | 0.8021 |


Relative to fixed estimation, VAD raised mean SNR by 0.049 dB for car and 0.144 dB for street, while lowering mean STOI by 0.0073 and 0.0008. Six of 32 evaluation cases improved both metrics. The findings motivate inspecting speech frames incorrectly used in noise updating; they do not establish general superiority of VAD adaptation.

![Paired effects and noise variation](Project_Feedback_Two_NOIZEUS/results/run_20260913_120452/figures/variation_and_paired_effect.png)

## Explore and reproduce

- [Full progress report](Project_Feedback_Two_NOIZEUS/review/RESULTS.md) and [eight-paper short literature review](Project_Feedback_Two_NOIZEUS/source_information/LITERATURE_REVIEW.md).
- [MATLAB running instructions](Project_Feedback_Two_NOIZEUS/README.md), [protocol](Project_Feedback_Two_NOIZEUS/PROTOCOL.md) and [metric definitions](Project_Feedback_Two_NOIZEUS/METRIC_GUIDE.md).
- [Complete native results ZIP](Project_Feedback_Two_NOIZEUS/evidence/NOIZEUS_Results_20260913_120452.zip), including all saved waveforms and native records.
- [Results table](Project_Feedback_Two_NOIZEUS/results/run_20260913_120452/metrics.csv) and [checked results](Project_Feedback_Two_NOIZEUS/review/CHECKED_RESULTS.json).

The next work is listening review, clearer VAD error annotation and a small parameter sensitivity study using development data. The original proposal PDF can remain in the repository as a record of the initial plan.
