ELEC5305 Final Project — Yulong Chen, SID 550889472
Noise tracking and speech protection in Wiener enhancement
Final video release, 5 November 2026

LATEST INVESTIGATION
The report now completes a diagnosis–intervention–verification cycle. A
literature-based soft speech-presence probability tracker addresses the hard
energy gate's difficulty updating after rising noise. A predeclared smoothing
ablation tests whether the effect is only a consequence of faster smoothing.
The experiment retains all 252 inputs and 1,512 method rows, including costs.
The new confirmation uses 18 additional sentences from the same six speakers;
36 earlier diagnostic inputs are kept as a separate regression group.

QUICK DEMONSTRATION
Keep all Final_Project subfolders together, open START_HERE.m in MATLAB and
press Run. The new demonstration computes sp03 / street / nominal 10 dB with
a +6 dB noise rise from the source WAVs. All six outputs are freshly computed.
SNR, late SNR and band-power errors must match the frozen results. STOI values
shown in this quick demo are explicitly stored Python scores. This quick
MATLAB run does not require Python or the generated signals/*.mat archive.
The demo saves a figure, checks and same-gain WAVs in spp_recovery/demo.

Open RUN_ORIGINAL_DEMO.m for the earlier four-output example shown in the
first six chapters of the completed video. That earlier demo checks its Python dependencies
and computes fresh SNR/STOI for its original predetermined example. Its lower
panels are stored 48-condition means rather than a live full-study rerun.

ENVIRONMENT AND FULL REPRODUCTION
Enhancement and diagnostics ran in MATLAB R2026a Update 4. Standard PySTOI
0.4.1, extended=False, scores unquantized outputs in Python. The demonstrated
Python versions are pinned in requirements.txt:

    python3 -m pip install -r requirements.txt

For the complete follow-up, open RUN_RECOVERY_STUDY.m in MATLAB. It creates a
separate copy below reproduction_runs and runs all specified inputs there.
Then run the printed Python scoring command on that copy. The supplied
reference results remain unchanged. The full run regenerates all 24 waveform
chunks before scoring. See spp_recovery/README.txt for the protocol, checks,
same-gain audio conventions and interpretation of the new metrics.

The ordinary GitHub repository includes code, source WAVs, saved tables,
regression_reference.mat and preselected_trace.mat. Generated follow-up
signals/*.mat are omitted from that repository copy. The complete release ZIP
additionally includes all roughly 250 MB of those unquantized chunks, allowing
scoring replay without rerunning enhancement:
https://github.com/yche0441/elec5305-project-550889472/releases/download/final-video-2026-11-05/ELEC5305_Final_Project_Complete.zip

MAIN FINDINGS
For new rising-noise inputs, default SPP versus selected hard gate changes
late four-band noise-power error by -5.76163 dB, whole reference SNR by
+1.59304 dB, and standard STOI by -0.0139782. The alpha=0.95 ablation gives
-4.01704 dB, +1.38209 dB and -0.00252280 respectively. Both improve tracking
and whole-record reference SNR in all 18 sentence means and six known-speaker means, but default SPP
loses mean STOI for all six speakers. This is a targeted tracking improvement
with an intelligibility-prediction cost, not an overall quality improvement.

Constant-noise and falling-noise results are included to reveal trade-offs.
No parameter is selected after viewing the new test results. All main report
STOI values use the same standard implementation. No listening evaluation,
perceptual preference or unseen-speaker generalisation is claimed.

WHAT IS INCLUDED
- report: 12-page final PDF and editable DOCX, with stable project/video links;
  Supporting_Results.pdf retains the two earlier detailed result pages.
- spp_recovery: soft-SPP implementation, original licences, frozen protocol,
  180 source WAVs, all result tables, figures, unquantized examples, runnable
  demo and independent numerical checks. The full ZIP also includes all
  generated waveform chunks; the repository version regenerates those.
- video: completed 6 min 31 sec recording, English captions, eight chapter
  markers and the matching spoken transcript. The original six chapters
  retain the actual earlier MATLAB run and stored full-study results. New
  recorded narration presents the soft-SPP follow-up through figures and
  result cards: 18 additional sentences from the same six known speakers,
  SPP 0.8 versus the predeclared 0.95 smoother, and tracking/SNR gains with
  STOI costs. The final conclusion evaluates tracking and speech protection
  together. START_HERE.m separately runs the new sp03 soft-SPP example.
- Final_Project_Study: preserved original parameter study and results.
- Final_Project_Video_Prep: preserved earlier demonstration and same-gain audio.
- Project_Feedback_Two_NOIZEUS: original source, inputs, results and licences.
- controlled_study: preserved 36-mixture diagnostic and paired tracking plots.
- reanalysis: portable standard-STOI replay and original sentence analyses.

EARLIER REPRODUCTION PATHS
RUN_PARAMETER_STUDY.m creates a new copy and reruns the original development
grid and 48-condition comparison. To replay original scoring in a new folder:

    python3 reanalysis/reanalyze.py --output reproduction_runs/reanalysis

For the earlier controlled diagnostic, copy controlled_study, run its
run_controlled_study function in MATLAB, then run score_and_summarize.py in
that copy. Historical native MATLAB STOI scores remain archived separately;
do not substitute them into the current standard-PySTOI comparisons.

SOURCE CREDIT
TSNR derives from LIU Ming / Pascal Scalart and Plapous, Marro and Scalart
(2006), doi:10.1109/TASL.2006.872621. The soft-SPP estimator and safeguard
derive from Gerkmann and Hendriks (2012), doi:10.1109/TASL.2011.2180896.
Their original licences and source provenance are retained. The contribution
is integration, controlled experiments, verification and interpretation.

Audio is from NOIZEUS / Hu and Loizou (2007),
https://ecs.utdallas.edu/loizou/speech/noizeus/
doi:10.1016/j.specom.2006.12.006. Code licences do not relicense corpus audio.

SUBMISSION AND PUBLICATION
The report PDF and final MP4 are the Canvas submission files. Supporting
results and working code are linked through the GitHub site. Publication,
upload and formal Canvas submission are separate actions; inclusion here does
not itself claim a new Canvas submission.

Project: https://yche0441.github.io/elec5305-project-550889472/
Video: https://yche0441.github.io/elec5305-project-550889472/Final_Project/video/index.html
