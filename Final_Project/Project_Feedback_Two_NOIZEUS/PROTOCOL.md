# First controlled NOIZEUS experiment

Protocol ID: `2026-09-12-v1`. Package completed on 2026-09-13. Parameters were set before enhancement preflight, and were not changed after it. New native MATLAB results are pending.

## 1. Objective

The research question is: **When does VAD-guided noise updating improve Wiener speech enhancement compared with a fixed initial noise estimate, and how does this depend on the time variation of the background noise?**

The experiment follows the teacher's recommendation to use corresponding clean/noisy recordings for quantitative evaluation. Independently spoken quiet and noisy recordings would not supply sample-matched references.

## 2. Data and fixed split

The supplied NOIZEUS archives contain 30 clean sentences and 240 corresponding noisy files for car and street noise at nominal 0, 5, 10 and 15 dB. All files passed the ZIP integrity check. WAVs are mono, 8 kHz, signed 16-bit PCM. Every corresponding pair has the same length, and a lag check over -8 to +8 samples found its strongest cross-correlation at zero lag. This limited check does not prove every possible aspect of dataset preparation.

For a small first experiment, the package includes six evenly spaced sentence IDs. Their speaker identifiers were subsequently confirmed in Tables 1-2 of the [NOIZEUS paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC2098693/).

| Sentence | Speaker ID in the paper | Split |
| --- | --- | --- |
| sp01 | CH | Development |
| sp06 | DE | Evaluation |
| sp11 | JE | Evaluation |
| sp16 | KI | Development |
| sp21 | SI | Evaluation |
| sp26 | TI | Evaluation |

Each sentence contributes two noise types and four nominal SNRs: 48 input cases in total. Development comprises 16 cases; evaluation comprises 32 cases from four other speakers. Only development signals were enhanced in the local numerical preflight. No enhancement quality scores were computed on the evaluation split before delivery. Inspecting clean/noisy correspondence and validating unity-gain reconstruction did not select parameters by enhancement quality.

The noisy files are the dataset's prepared mixtures of speech and recorded noise. They are not the student's own simultaneous environmental recordings. There is no additional mixing, resampling, time alignment or amplitude fitting in this package. Native int16 amplitudes are read through `audioread`.

## 3. Initial noise estimate

Both modes estimate the initial noise PSD from the first 0.10 s (800 samples) of each noisy recording. The original demo's 10,000-sample setting is inappropriate for these much shorter sentences. Following the supplied source, the PSD averages 25 ms windowed power spectra at one-sample increments inside this initial interval. These overlapping spectra are strongly correlated; they are not 601 independent noise observations.

The prefix was checked against the corresponding clean signal. It is a **low-clean-energy approximation to a noise-only interval**, not an assertion of exact silence. Across the selected 48 cases, the largest clean-to-residual-noise energy ratio in this prefix is -19.71 dB, about 1.1%. Weak speech or residual recording noise may still contaminate initialization. The same approximation affects both modes. Reference samples are used for this audit only and are never supplied to the enhancer.

## 4. Shared signal-processing path

The comparison uses the TSNR branch of the supplied `WienerNoiseReduction.m`, associated with Plapous, Marro and Scalart (2006). The main experiment does not compare TSNR with HRNR. Both experimental modes use the same parameters:

| Setting | Value |
| --- | --- |
| Sample rate | 8 kHz |
| Window | 25 ms / 200 samples; the verified legacy `hanning` convention |
| Hop / overlap | 80 / 120 samples, or 10 ms / 60% |
| FFT size | 400 |
| Decision-directed smoothing | 0.99 |
| Source instantaneous-SNR floor | 0.1 after subtracting 1 from power/noise PSD |
| Source pre-constraint gain floor | 0.15 |
| Initial PSD | Same first 800 samples and same estimation function |
| PSD numerical floor | max(realmin, 1e-12 times mean initial PSD) |
| Gain constraint | The author's impulse constraint with a 200-sample Hamming taper |
| Reconstruction | Shared padded overlap-add with window-sum normalization |

For reproducibility, the analysis window is `0.5 - 0.5*cos(2*pi*(1:L)'/(L+1))`. The local comparison to the student's actual original MATLAB output verified this convention. Substituting a symmetric zero-endpoint Hann window changes the result.

The author's demo finishes by independently matching each output's peak to the input peak. The quantitative adaptation removes that normalization. Instead, it pads the input by 200 zeros on the left and 400 on the right, accumulates the full inverse-FFT blocks, divides by the accumulated analysis-window weights, and crops back to the original sample range. The same change applies to both modes. Unity gain reconstructs the input to numerical precision. These shared reconstruction changes are recorded adaptations, so the main output is not claimed to be bit-identical to the author's peak-normalized demo. A separate legacy mode verifies the original TSNR branch against the saved MATLAB result.

## 5. Only experimental difference: noise updating

Fixed mode holds the initial PSD constant. VAD mode starts with precisely the same PSD. Frame energy is compared with the current total estimated noise power. A ratio greater than 3 dB gives a speech decision; five further frames are protected by hangover. This is a simple energy detector, not the statistical Sohn detector.

After a frame classified as non-speech, VAD mode updates the PSD for the next frame:

`D_next = 0.95*D_current + 0.05*abs(Y_current).^2`

The initial 0.10 s, partially padded frames and frames outside the recording cannot update the PSD. Fixed mode can calculate the same diagnostic VAD decisions but does not use them to alter processing. The 3 dB threshold, five-frame hangover and 0.95 smoothing are fixed engineering choices, not claimed optimal values or parameters copied from Sohn's paper.

## 6. Evaluation and interpretation

Primary measures are reference SNR and STOI. Both compare samples 801 through the end against the same clean samples. The initial PSD interval is excluded for every method, including unprocessed input. An output whose speech is attenuated is penalized by reference SNR. No fitted gain, extra delay alignment or independent playback normalization enters the metrics. Nominal dataset SNR is kept as a condition label; measured input SNR is reported separately. See `METRIC_GUIDE.md`.

For each input, subtract the fixed-method result from the VAD-method result. Report all cases and the evaluation split separately from development. Each evaluation condition has four sentences; differences are exploratory, and repeated SNR versions are not independent speakers. The corpus can use different noise excerpts between nominal SNR conditions, so an across-SNR trend is not a pure rescaling experiment.

Noise time variation is described by the 90th-minus-10th percentile spread of residual-noise frame power in dB. This descriptor uses `noisy-clean` only after enhancement, for analysis. In the selected inputs, median spreads are 2.69 dB for car and 7.55 dB for street, using the protocol's frame grid. This is a data characteristic, not evidence that VAD enhancement succeeds. Individual cases overlap in their variation levels.

Inspect VAD decisions alongside clean-energy activity proxies. Missed weak speech may enter the noise update; a sudden loud noise may instead be labelled speech and prevent updating. These are mechanisms to investigate, not already established outcomes. Two listening examples and spectrogram comparisons are preselected: sp06, car/street, nominal 5 dB. The overview plots show every held-out case, including unfavourable results.

## 7. Remaining work

Run this package in MATLAB Online and review `RUN_STATUS.txt`. Complete STOI if Audio Toolbox is unavailable. Inspect quantitative differences, VAD errors and the listening examples before writing conclusions. A parameter sensitivity study, longer noise recordings and an optional real-world demonstration can follow this first controlled experiment; they are not reported as completed here.
