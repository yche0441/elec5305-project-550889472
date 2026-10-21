ELEC5305 Final Project — Yulong Chen, SID 550889472
When does VAD-guided noise updating help Wiener speech enhancement?
Final release, 21 October 2026

QUICK DEMONSTRATION
Extract the complete package, keeping its subfolders together. Open START_HERE.m
in MATLAB and press Run. It checks the required Python modules, then recomputes
the predetermined sp02 / street / nominal 5 dB example. The four fresh SNR/STOI
pairs must match the saved study within 1e-8. This does not rerun the full study.
The optional command play_demo_audio plays four same-gain clips, in order.

The lower figure panels explicitly show the stored 48-condition test means.
They are completed experiment results, not computations performed live during
the single-case demonstration. The chosen example is not selected for success:
SNR improves, STOI falls below the input, and selected VAD is not best there.

ENVIRONMENT
Executed MATLAB: R2026a. Enhancement and reference SNR use the included MATLAB
helpers; the current metric workflow uses standard PySTOI 0.4.1, extended=False.
No Audio Toolbox stoi function is needed for the current demo or extension.
Python 3.12 with the exact dependencies in requirements.txt reproduces the
recorded scoring environment:

  python3 -m pip install -r requirements.txt

If MATLAB cannot find that interpreter, set its full executable path before Run:

  setenv('ELEC5305_PYTHON','/full/path/to/python3');

On Windows use the full path to python.exe. This value is an executable path,
not a shell command with extra arguments. START_HERE checks before computing;
it never installs dependencies or changes system settings. A local-only setup
file may be present on the author's machine; it is excluded from distribution.

WHAT IS INCLUDED
- report: the checked 12-page final report PDF and editable DOCX, with links
  to the project site, working code and final video.
- video: completed 5 min 24 sec demonstration with English captions, MP4,
  downloadable SRT and the actual spoken transcript. Open video/index.html.
- Final_Project_Study: unchanged parameter study, clean/noisy WAV subset, portable
  MATLAB runner, all saved per-case metrics, frozen selection and provenance.
- Final_Project_Video_Prep: tested one-case demonstration, same-gain audio,
  the final narration transcript, Chinese explanations and 10 tutor questions.
- Project_Feedback_Two_NOIZEUS: unchanged original source, data, literature notes,
  original native MATLAB results and licences, preserved as historical evidence.
- requirements.txt: exact Python scoring dependency versions.
- START_HERE.m and check_environment.m: short demonstration entry point.
- RUN_PARAMETER_STUDY.m: optional complete rerun in a new output copy.
- reanalysis: portable replay of 144 original waveform scores using standard
  PySTOI, plus the development/test/sentence-level tables in the final report.
- controlled_study: frozen matched level-change experiment (36 mixtures,
  144 method rows), its unchanged source inputs, MATLAB/Python runners,
  complete unquantized results, validation and scientific plots.

The strengthened report presents standard PySTOI throughout its main results.
Earlier native MATLAB STOI values remain archived in the original project;
the historical README/tables there describe that earlier analysis. They should
not be substituted into the current report or mixed with its PySTOI values.

REPRODUCING THE PARAMETER STUDY
Run RUN_PARAMETER_STUDY.m from this release. It creates a new copy below
reproduction_runs and executes the complete 9-by-16 development grid and
48-by-4 test comparison there. The supplied reference results are not overwritten.
The output log states where the new files were written. See the study README
and PROTOCOL.json for the exact split, tie-break rule and metric amendment.

OTHER REPRODUCTION PATHS
To replay original-waveform scoring and the final report's comparison tables,
run the following from this release folder with the configured Python:

  python3 reanalysis/reanalyze.py --output reproduction_runs/reanalysis

This writes separate outputs and leaves the supplied results_recomputed folder
intact. Its defaults locate the two included source folders automatically.

For the matched noise-change experiment, make a copy of controlled_study,
open the copy in MATLAB and run run_controlled_study. Then run the configured
Python on the copied score_and_summarize.py. All paths are relative to that
script. Its README describes what is measured and which checks must pass.
Scoring can also be repeated directly from the supplied unquantized MAT file
without rerunning enhancement. Use a copy to preserve the reference results.

The controlled experiment applies a 50 ms transition to the same injected
noise residual: constant, +6 dB or -6 dB. Original and selected VAD parameters
remain frozen. Six previously used sentences each have two base noise types;
these are repeated diagnostic mixtures, not new independent test speakers.

INTERPRETATION
New test sentences are not new speakers. Several conditions share each sentence.
The small differences are descriptive, not evidence of universal superiority.
Clean-energy speech proxies are not manual VAD labels. The demonstrative audio
has no listener scores, and no subjective listening evaluation is claimed.

SOURCE CREDIT
The common TSNR branch derives from WienerNoiseReduction.m by LIU Ming / Pascal
Scalart and Plapous, Marro and Scalart (2006), doi:10.1109/TASL.2006.872621.
Original licences are retained in the included source folders. The contribution
is the controlled update/reconstruction adaptation, verification, experiments
and analysis, not invention of the inherited TSNR algorithm.

Unchanged corpus audio comes from NOIZEUS, prepared by Hu and Loizou:
https://ecs.utdallas.edu/loizou/speech/noizeus/
Hu and Loizou (2007), doi:10.1016/j.specom.2006.12.006.
The code licence does not change the corpus audio's ownership or terms.

SUBMISSION CONTENTS
The final report PDF and final MP4 are the two Canvas submission files.
The repository supplies downloadable working code, evidence and the report.
The project site links the report, code, final video and same-gain audio examples.
Canvas submission status is checked separately in Canvas; inclusion in this
archive does not itself indicate that a submission has been made.

Project site: https://yche0441.github.io/elec5305-project-550889472/
Video: https://yche0441.github.io/elec5305-project-550889472/Final_Project/video/index.html
