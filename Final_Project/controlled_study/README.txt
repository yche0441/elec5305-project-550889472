ELEC5305 FINAL PROJECT — CONTROLLED NOISE-LEVEL DIAGNOSTIC
Yulong Chen, SID 550889472

PURPOSE AND STATUS
Completed MATLAB/Python experiment: 6 previously evaluated sentences  x 2 noise
types  x 3 matched level profiles = 36 mixtures and 144 method rows. This is a
controlled diagnostic extension, NOT a new independent test set or an original
NOIZEUS benchmark condition. Parameters were frozen before execution; no
configuration was tuned on these results. PROTOCOL.json and its SHA256 were
saved before the first run. RUN_HISTORY.json records implementation-only fixes.

DESIGN
For each original 10 dB NOIZEUS pair, form residual n = noisy - clean. The
constant profile reconstructs the original input exactly. The other profiles
preserve the same clean speech and residual, but ramp residual amplitude by
+6 or -6 dB over 50 ms halfway through the post-calibration recording, then
hold that level. All profiles share the initial 100 ms and exact pre-change
samples. Natural variation remains inside the noise; 'constant' means constant
ADDED gain, not stationary noise. No clipping, normalization, resampling, gain
fitting, delay fitting or new recordings are introduced. Residual subtraction
includes any original quantization/scaling discrepancy.

The four methods are unprocessed, fixed noise estimation, original VAD
(3 dB threshold/5-frame hangover), and the previously selected VAD
(1 dB/10 frames). tsnr_enhance.m, experiment_config.m, pair_diagnostics.m and
measure_snr.m are copied byte-for-byte from Final_Project_Study, with its
original licence. The selected setting changes only a local configuration
copy. Noise smoothing remains 0.95; frame length 25 ms and hop 10 ms.

METRICS AND DIAGNOSTICS
Whole-record reference SNR and standard PySTOI use samples 801:end, excluding
the shared 100 ms initial estimate. MATLAB saves unquantized double arrays;
Python applies pystoi 0.4.1 with extended=False. Post-change SNR additionally
uses the interval after the 50 ms ramp plus100 ms guard. No short-segment STOI
is used. These short utterances do not establish listener-level intelligibility.

For each valid frame, compare the existing noise-PSD SUM used BEFORE that
frame's update with summed FFT power of the known injected-noise component
through the same 200-sample legacy Hann window/400-point FFT. This is a
broadband realization-based tracking descriptor, not an expected-noise-PSD
ground truth, full spectral error measure, or perceptual score. The figures
also show the actual update decisions and the original clean-energy proxies:
speech >= -30 dB and non-speech <= -40 dB relative to peak valid clean-frame
energy. These are diagnostic proxies, not manually labelled VAD truth.

Each sentence's two noise-type outcomes are averaged before displaying six
sentence-level paired effects. All cases are supplied. Neither overlapping
frames nor the 36 mixtures are treated as independent samples for inference.
There are no significance tests, formal confidence intervals, or claims of
new-speaker generalization. FINDINGS.txt gives the numerical interpretation.

REPRODUCING
Work in a COPY of this folder: the runner replaces result files in its folder.
Keep the supplied original results/protocol/provenance intact.

1. Use MATLAB (executed: MATLAB R2026a; full version in MATLAB_RUN_STATUS.json).
   Open this copied folder and run:
       run_controlled_study
   Only MATLAB base functions are required for this experiment's enhancer.

2. Install Python 3.12 and the supplied pinned requirements in an environment:
       python3 -m pip install -r requirements.txt

3. In that copied folder run:
       python3 score_and_summarize.py
   This scores STOI, independently checks SNR/tracking, compares the constant
   profile with prior test metrics, and regenerates CSV/JSON summaries/plots.
   The script uses paths relative to its own location; no machine-specific
   source folder is required. The large MAT file contains all reference and
   processed arrays, so scoring can be repeated without rerunning MATLAB.

MAIN FILES
PROTOCOL.json / PROTOCOL_SHA256.txt — original frozen design and hash.
INPUT_AND_CORE_MANIFEST.json — all included input/core SHA256 hashes.
run_controlled_study.m — MATLAB construction, enhancement and assertions.
score_and_summarize.py — metrics, independent checks, paired summaries/plots.
unquantized_signals.mat — all36 mixture/reference/4-method arrays.
metrics.csv —144 rows of whole SNR/STOI, late SNR and tracking descriptors.
frame_diagnostics.csv — same-frame injected power, estimate, gates and updates.
sentence_means.csv / sentence_paired_contrasts.csv — all six sentence effects.
sentence_profile_interactions.csv — changed-minus-constant paired contrasts.
ANALYSIS_SUMMARY.json — descriptive summaries, environment and verification.
paired_effects.png/.pdf — all six sentence effects, with means.
tracking_example.png/.pdf — example chosen in protocol before scoring.
verification_cases.csv —36 case-level invariance/reconstruction checks.
MATLAB_RUN_LOG_FINAL.txt / SCORING_LOG_FINAL.txt — executed run logs.
RUN_HISTORY.json — implementation fixes, final checks, no design retuning.

VALIDATION
All constant profiles reproduce previous 10 dB method scores: maximum absolute
STOI difference 4.45e-16 and SNR difference 0. Independent NumPy checks reproduce
all reference SNRs within 5.87e-14 dB, windowed injected-noise powers within
5.06e-15 relative error and before-update recursive estimates within 7.50e-15.
The fixed estimate is identical across profiles and its late tracking ratio
shifts by exactly the opposite of the imposed 6 dB level change. Identity
reconstruction error is at most 1.67e-16. Shared prefixes, initial PSDs and
pre-change traces are identical. Output-prefix equality excludes a conservative
two-window support margin before the change. All scores are finite; STOI emits
no short-input warnings. The maximum mixture peak is 0.461, so clipping is absent.

ATTRIBUTION
The common TSNR path derives from WienerNoiseReduction.m by LIU Ming / Pascal
Scalart and Plapous, Marro and Scalart (2006), doi:10.1109/TASL.2006.872621.
The original code licence is retained unchanged in license.txt. Additional work
here comprises the matched experiment design, controlled noise manipulation,
diagnostics and evaluation. The inherited enhancer is not wholly new code.

Source audio is the NOIZEUS clean/noisy corpus subset:
https://ecs.utdallas.edu/loizou/speech/noizeus/
Hu and Loizou (2007), "Subjective comparison and evaluation of speech
enhancement algorithms", doi:10.1016/j.specom.2006.12.006.
Original WAVs are copied unchanged; transformed waveforms are controlled
remixes saved in the MAT results, not newly recorded environmental audio.
No new licence or ownership is claimed for corpus audio.
