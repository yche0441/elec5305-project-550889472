# How to read the experiment outputs

## Primary measures

Reference SNR is `10*log10(sum(s.^2)/sum((z-s).^2))`, where `s` is the clean reference and `z` is the unprocessed or enhanced signal. All main SNR/STOI measurements use samples 801 through the end. `SNRImprovement_dB` subtracts measured input SNR. It measures closeness to the paired clean waveform, so remaining noise and speech distortion both contribute to the error. It is not a direct measurement of residual noise alone.

`STOI` is calculated by MATLAB as `stoi(processed,reference,fs)` on the same interval. Larger scores indicate greater predicted intelligibility; scores are not percentages of correctly understood words. An unavailable or failed STOI call produces NaN and a clearly marked partial run. The implementation and range are described in the [MathWorks documentation](https://www.mathworks.com/help/audio/ref/stoi.html); the research reference is Taal et al. (2011) in the literature review.

The dataset's nominal SNR uses active speech level in its preparation. Our global reference SNR uses the energy in the stated sample interval. Their values need not agree. The generation procedure is described in [Hu and Loizou, Section 2.2](https://pmc.ncbi.nlm.nih.gov/articles/PMC2098693/). The programme keeps both numbers and does not rescale signals to force agreement.

## Files and columns

| File / column | Meaning |
| --- | --- |
| `metrics.csv` | 144 rows: three methods for each of 48 inputs. |
| `condition_summary.csv` | Means by split, noise, nominal SNR and method. Evaluation N=4; development N=2. STOI means with missing rows are incomplete. |
| `paired_comparisons.csv` | VAD minus fixed SNR and STOI for each identical noisy input. Positive favours VAD for that measure. |
| `dataset_diagnostics.csv` | Duration, initialization audit, noise variation and counts behind the proxy diagnostics. |
| `InputWholeRecordSNR_dB` | Audit-only whole-recording SNR; its interval differs from the primary measure. |
| `Runtime_s` | One filter-call timing, excluding evaluation and plotting. NaN for unprocessed input. No repeated timing benchmark is claimed; fixed always runs before VAD. |
| `PeakAbsolute` | Output peak before any listening-copy gain; values above one are kept in the MAT data. |
| `NoiseVariation_dB` | P90-P10 of unwindowed residual-noise frame power in dB, on valid 25 ms frames after initialization. Percentiles use linear interpolation at 1+(N-1)*p/100. |
| `InitialCleanToResidual_dB` | Clean/noise energy ratio in the first 800 samples; a prefix-contamination diagnostic. |
| `ProxySpeechMissFraction` | Fraction of clean-speech-proxy frames given a non-speech VAD decision. |
| `ProxyNonSpeechFalseAlarmFraction` | Fraction of clean-non-speech-proxy frames given a speech decision. |
| `UpdateOnSpeechProxyFraction` | Fraction of speech-proxy frames actually used in noise updating; zero for fixed mode by design. |
| `NoiseUpdateFraction` | Updated frames divided by valid frames after initialization. |

For activity diagnostics, each clean frame's power is expressed relative to the maximum clean-frame power in the evaluated recording. Frames at or above -30 dB are a speech-energy proxy. Frames at or below -40 dB are a non-speech-energy proxy. The middle band is unlabelled. These are energy-derived reference proxies, not manual phonetic annotations or gold-standard VAD labels. Quiet consonants can fall below a threshold, so inspect the plots and listen before attributing speech loss.

`experiment_results.mat` retains every unscaled clean/noisy/fixed/VAD signal and both diagnostic traces. The frame trace stores PSD power **before** any update at that frame. Updating affects the next frame. Computational padding is not included in evaluation.

Listening WAVs use a shared gain within each clean/input/fixed/VAD quartet only if needed to avoid clipping. This gain is written to the adjacent text file. Metrics use the unscaled double-precision MAT signals. Spectrograms share one amplitude reference and one colour range within each quartet.

`RUN_STATUS.txt` distinguishes a complete SNR/STOI run from a partial run. Completion means the computation finished; it does not establish that VAD is superior or that the project report is ready to submit.
