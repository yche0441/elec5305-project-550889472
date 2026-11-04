SOFT SPEECH-PRESENCE TRACKER FOLLOW-UP
ELEC5305 final project, 4 November 2026

Purpose
The earlier energy gate often blocked noise-estimate updates after a level
rise. This frozen follow-up replaces only the noise tracker with the published
Gerkmann/Hendriks soft speech-presence probability estimator. The original
TSNR processing remains shared. Default SPP alpha=0.8 and a predeclared
alpha=0.95 ablation test recovery and its speech-protection cost.

Requirements
MATLAB R2026a Update 4 was used. The implementation and demo use base MATLAB
FFT, numerical, WAV and graphics functions. Python 3.12 with numpy, scipy,
pandas, matplotlib and pystoi==0.4.1 is needed for full standard-STOI scoring
and the independent numerical checks. Python is not needed for the quick
MATLAB demo. The demonstrated environment is recorded in ANALYSIS_SUMMARY.json.

Quick fresh demonstration
1. Keep this directory and its data subdirectories together; extract first.
2. In MATLAB, change the current folder to this directory.
3. Enter:
      run_recovery_demo
The demo recomputes all six outputs from the source sp03 clean/street WAVs,
constructing the preselected +6 dB rising-noise input. It does not load stored
signals. Fresh SNR, late SNR and four-band tracking errors must match the
frozen metrics.csv within 1e-10. demo/DEMO_CHECK.json records the checks;
demo/Recovery_Demo.png shows the fresh computation. demo/*.wav are seven
playback examples sharing ONE gain. The MAT file preserves original doubles.
Any STOI value in Demo_Metrics.csv or DEMO_CHECK.json is explicitly a stored
standard Python score, not a fresh MATLAB STOI computation.

Complete reproduction
Run in a COPY because generated result files are replaced:
      verify_spp_synthetic
      run_recovery_study
Then, in a terminal from the same directory:
      python3 -m pip install numpy scipy pandas matplotlib pystoi==0.4.1
      python3 score_recovery.py
On macOS, headless MATLAB can use:
      matlab -nodisplay -batch "run_recovery_study"

The full run generates 24 unquantized MAT chunks under signals/, covering
252 input mixtures and six methods (1,512 rows). It checks source reconstruction,
initial PSD identity, safe unchanged prefixes, calibration/padding state
freezes, fixed-mode independence and all old baseline waveforms. The Python
scorer verifies the frozen input/core/protocol hashes, recomputes standard
STOI plus SNR, and independently rebuilds all noise-estimator recurrences,
tracking measures and effective update weights. It then checks the old
144 baseline metric rows and publishes all case, sentence and speaker results.
No parameters are selected from these follow-up outcomes.

Distribution
The ordinary GitHub repository includes runnable code, source WAVs, saved
CSV/JSON summaries, preselected_trace.mat and regression_reference.mat, but
omits the roughly 250 MB of generated signals/*.mat. Running the full MATLAB
study regenerates those chunks before Python scoring. The complete package
on the project's GitHub release additionally includes all generated chunks.
The quick demo works with either distribution and does not need those chunks.

Evidence and interpretation
There are 18 additional sentences from the same six known NOIZEUS speakers,
not six unseen speakers. The old six sentences are a separate diagnostic and
regression group. New constant-noise tests cover two noises and four nominal
SNRs; rising/falling changes are tested at nominal 10 dB. PROTOCOL.json and
PROTOCOL_CLARIFICATIONS.json specify all outcomes and aggregation rules.
RUN_HISTORY.json records startup implementation fixes, without parameter
changes or outcome-based redesign. EXECUTION_MANIFEST.json preserves the
pre-execution core/input/protocol hashes.

The primary endpoint is finite-window four-band noise-power agreement after
a rise. SPP improves this endpoint and reference SNR, but its default setting
reduces mean STOI relative to the selected gate. The matched-alpha ablation
reduces this STOI cost. See FINDINGS.txt and ANALYSIS_SUMMARY.json for all
profiles and comparisons. A lower tracking error does not prove better
perceived speech quality. No subjective listening evaluation was performed.

Figures and files
figures/recovery_tracking*: the preselected sp03/street/rise trace.
figures/recovery_paired_effects*: all six known-speaker paired effects;
compact variants preserve content for the report. Red bars are the means of the six speaker points.
metrics.csv: every individual method/input result.
case_paired_contrasts.csv: paired differences by input and analysis set.
sentence_* and speaker_*: all repeated-unit means and paired differences.
INDEPENDENT_DIAGNOSTIC_CHECKS.csv: separate Python vs MATLAB numerical checks.
SYNTHETIC_UNIT_CHECK.json: formula, safeguard and original-path regression.
The unprocessed signal has no estimated PSD; its tracking fields are undefined.
A proxy-specific mean is undefined when that proxy has zero frames.

Attribution
The TSNR core is derived from LIU Ming/Pascal Scalart; see license.txt.
The soft-SPP recurrence is adapted from Gerkmann and Hendriks (2012),
DOI 10.1109/TASL.2011.2180896. The author code licence is retained in
noise_psd_spp_update.m and LICENSE_GERKMANN_HENDRIKS.txt. See
SPP_SOURCE_AND_PARAMETERS.json for the official source URL and exact defaults.
The authors' standalone code uses 16 ms hops; this controlled adaptation
retains its coefficients on the project's common 10 ms grid and initial PSD.
The project contributes integration, controlled testing and interpretation;
it does not claim invention of the soft-SPP estimator or its safeguard.
