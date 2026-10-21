ELEC5305 Final Project: bounded VAD sensitivity and new-sentence study
Yulong Chen, SID 550889472

CONTENTS AND STATUS
This folder contains the completed local study, its frozen protocol, source code,
unchanged NOIZEUS input WAVs, and CSV/MAT results. RUN_STATUS.txt records MATLAB
R2026a Update 4 (26.1.0.3312084). No parameter search beyond the stated grid was run.
The original v1 project and its native MATLAB STOI results are preserved separately.

REPRODUCING THE STUDY
Work in a COPY of this folder: the runner writes result files in its own folder.
Keep the supplied result files and provenance intact in the original copy.

1. Install Python 3.12 and the metric dependencies. The executed environment used
   Python 3.12.14, numpy 2.3.5, scipy 1.18.1 and pystoi 0.4.1:

   python3 -m pip install numpy==2.3.5 scipy==1.18.1 pystoi==0.4.1

2. Open the copied folder in MATLAB. If Python is not named python3 on MATLAB's
   system PATH, set its full executable path in the MATLAB Command Window:

   setenv('ELEC5305_PYTHON','/absolute/path/to/python3');

   On Windows the value can be the full path to python.exe. It is an executable
   path, not a shell command with extra arguments.

3. From this folder run:

   run_final_study

The function reads all inputs relative to its own location. It first runs the
unchanged v1 native verification against the small reference_v1 fixture bundle.
It then computes the development grid, writes SELECTION.json before testing,
and evaluates the fixed test split. Reference SNR is calculated in MATLAB.
STOI is calculated by stoi_bridge.py from unquantized double-precision arrays
saved to metric_input.mat. No Audio Toolbox stoi function is required.

The recorded study was executed before the later portability-only path changes.
provenance/run_final_study_executed_20261005.m is the exact executed runner;
provenance/EXECUTED_RUNNER_SHA256.json identifies it. The portable runner changes
only the reference-fixture location and Python-executable selection. The portable
entry point has been checked statically and its dependencies verified. A local
MATLAB smoke check passed every v1 verification gate using the bundled fixtures,
and the Python bridge reproduced the last saved test score. See
PORTABLE_SMOKE_CHECK.json and its two logs. The full parameter grid and test
study were not rerun solely to test portability.

PROTOCOL AND SELECTION
Read PROTOCOL.json including its metric_implementation_amendment. The original
native-STOI wording records the initial plan; the amendment, written before any
scoring, changes the actual metric to standard PySTOI (extended=False) because
local MATLAB lacked stoi. PROTOCOL_NATIVE_ATTEMPT.json and the first MATLAB log
preserve the failed initial attempt. MATLAB_RUN_LOG_V2.txt records the completed
study; no native MATLAB STOI scores are claimed for this new experiment.

Development: sp01 and sp16, each with car/street noise at nominal 0/5/10/15 dB
(16 cases). Thresholds [1,3,5] dB cross hangovers [0,5,10] frames; noise PSD
smoothing remains 0.95. Selection maximises mean development PySTOI. Candidates
within 1e-6 of the best mean are ordered by higher mean reference SNR, then
|threshold-3| + |hangover-5|; remaining exact ties retain the grid order. The
selected setting was threshold 1 dB and hangover 10 frames. The original setting
(3 dB, 5 frames) remains in the grid and the test comparison.

New-sentence test: sp02, sp07, sp12, sp17, sp22 and sp27 with the same eight
noise/SNR conditions (48 cases). These are new sentences, NOT held-out speakers:
speakers overlap with the earlier material. The IDs and selection rule were
recorded before scoring, and no retuning followed test inspection. Earlier v1
evaluation outcomes had already been seen; this is a bounded exploratory follow-up.
Test methods: unprocessed, fixed, original VAD and selected VAD (192 metric rows).
All metrics exclude the first 0.10 s: MATLAB samples 801:end. No delay fitting,
amplitude fitting, resampling or remixture of the source inputs is performed.

INTERPRETATION AND METRIC VALIDATION
The selected setting improved mean test PySTOI over original VAD by 0.00404 but
remained 0.00064 below fixed estimation. Mean SNR was 0.0636 dB above fixed.
These small descriptive changes do not establish universal or statistically
significant superiority. Clean-energy speech proxies are not manual annotations;
listening files are demonstrations, not evidence of a completed listener study.

validation/PYSTOI_VALIDATION.json and pystoi_vs_native_rows.csv compare standard
PySTOI 0.4.1 with 144 stored v1 native MATLAB STOI scores on identical waveforms
and intervals. Maximum absolute difference is 0.0184532, mean absolute difference
0.00285492; the maximum paired VAD-minus-fixed discrepancy is 0.00542369 and one
of 48 paired effect directions changes. These implementations are not numerically
interchangeable. Compare methods within this new study using the same PySTOI
implementation; do not merge its absolute scores with v1 native scores. Scores
predict intelligibility, not percentages of words correctly understood.

IMPORTANT OUTPUTS
- development_metrics.csv: 9 configurations x 16 cases
- development_summary.csv: descriptive development means and proxy diagnostics
- development_fixed.csv: 16 fixed-baseline development cases
- SELECTION.json: selection saved before the new-sentence test
- new_test_metrics.csv: 48 test cases x 4 methods
- study_results.mat: configurations, rows, verification and run metadata
- ANALYSIS_SUMMARY.json: summary of the completed results
- DATA_MANIFEST.json: original-archive provenance for the new test inputs
- INPUT_FILES_SHA256.json: hashes for all 72 study input WAV files
- reference_v1/MANIFEST.json: hashes for the nine unchanged verification fixtures
- PORTABILITY_CHECKS.json: dependency, input and portability checks
Absolute archive paths in historical manifests identify this machine's provenance;
those archives are not needed to run the included subset. Numerical fixtures
validate the unchanged v1 configuration, not agreement of new parameters with v1.

ATTRIBUTION
The common TSNR path derives from WienerNoiseReduction.m by LIU Ming / Pascal
Scalart and Plapous, Marro and Scalart (2006), doi:10.1109/TASL.2006.872621.
The original code licence is retained unchanged in license.txt. The project's
additional work is the controlled noise update, reconstruction adaptation,
experiment design, diagnostics and evaluation; the inherited TSNR code is not
presented as wholly student-written.

The audio is the unmodified NOIZEUS corpus subset, prepared clean/noisy recordings
from https://ecs.utdallas.edu/loizou/speech/noizeus/ . Cite Hu and Loizou (2007),
"Subjective comparison and evaluation of speech enhancement algorithms",
doi:10.1016/j.specom.2006.12.006. These are not the student's own environmental
recordings. The code licence does not transfer ownership of the corpus audio or
claim a new licence for it. Retain the corpus attribution when using this package.

MATLAB performed enhancement and reference-SNR calculations; Python calculated
STOI.
