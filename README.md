# Noise tracking and speech protection in Wiener enhancement

**ELEC5305 Final Project · Yulong Chen · SID 550889472 · 4 November 2026**

[Project website](https://yche0441.github.io/elec5305-project-550889472/) · [Final report](ELEC5305_Final_Project_Yulong_Chen.pdf) · [Supporting results](Final_Project/report/Supporting_Results.pdf) · [Recorded demonstration](https://yche0441.github.io/elec5305-project-550889472/Final_Project/video/index.html) · [Running instructions](Final_Project/README.txt)

This project investigates when a noise-update rule helps a shared two-step noise-reduction (TSNR) Wiener enhancer, and what it costs in speech protection. It follows an implementation–evaluation–revision cycle: reproduce the existing enhancer, compare fixed and hard-gated noise estimates, diagnose blocked updates after a noise rise, then test a published soft speech-presence probability (SPP) tracker on additional sentences.

## Latest result: recovery has a cost

The new frozen follow-up uses **18 previously unused sentences from the same six known NOIZEUS speakers**, with three sentences per speaker. It contains **216 distinct new inputs**: 144 constant-noise conditions and 72 rising/falling-noise conditions. A separate group of 36 earlier diagnostic inputs provides regression checks. All **252 inputs × 6 methods = 1,512 rows** are retained.

The published SPP coefficients use PSD smoothing **0.8**. A predeclared **0.95** ablation matches the hard gate's PSD smoother. Both variants retain the project's common 10 ms hop, initialisation, TSNR gains and reconstruction. Neither is chosen using the new test results.

| New +6 dB rise, relative to selected hard gate | SPP 0.8 | SPP 0.95 |
| --- | ---: | ---: |
| Late four-band noise-power error change (dB), lower is better | −5.76163 | −4.01704 |
| Whole-record reference SNR change (dB) | +1.59304 | +1.38209 |
| Late reference SNR change (dB) | +2.04997 | +1.85994 |
| Standard STOI change | −0.0139782 | −0.00252280 |

Both SPP variants improve the rise-condition band-power error and whole-record reference SNR in all **18 sentence means and six speaker means**. The default variant loses mean STOI in all six speaker means. It reduces the tracking failure without improving every speech measure. The slower variant retains much of the SNR benefit with a smaller STOI cost, so recovery cannot be attributed only to faster raw smoothing.

The 144-condition constant-noise benchmark also exposes costs: SPP 0.8 changes SNR by **−0.05915 dB** and STOI by **−0.0077954** against the selected gate; SPP 0.95 changes them by **+0.19929 dB** and **−0.0038978**. The method is not a universal replacement for fixed or hard-gated estimation. Band-power agreement is measured against the known injected noise over finite windows, not an expected-PSD oracle or a listening-quality score.

## Run a fresh example

1. Download this repository and keep the `Final_Project` subfolders together.
2. Open [START_HERE.m](Final_Project/START_HERE.m) in MATLAB and press Run.
3. It recomputes the preselected **sp03 / street / nominal 10 dB / +6 dB rise** from the source WAV files. Fresh SNR, late SNR and tracking measurements are checked against the frozen results. The displayed STOI values are labelled **stored Python scores**, not a fresh MATLAB STOI calculation.
4. The demonstration writes same-gain playback examples under `spp_recovery/demo`. These are output examples, not a subjective listening study.

The quick demo needs base MATLAB and does not need the large generated waveform archive or Python. Full scoring uses standard **PySTOI 0.4.1, `extended=False`**, with the dependencies in [requirements.txt](Final_Project/requirements.txt).

[Download the complete reproducibility package](https://github.com/yche0441/elec5305-project-550889472/releases/download/final-recovery-2026-11-04/ELEC5305_Final_Project_Complete.zip), including all unquantized waveform chunks. The ordinary repository omits approximately 250 MB of generated `spp_recovery/signals/*.mat`; a full MATLAB rerun regenerates them before Python scoring. See the [follow-up README](Final_Project/spp_recovery/README.txt), [frozen protocol](Final_Project/spp_recovery/PROTOCOL.json), [all results](Final_Project/spp_recovery/metrics.csv), and [independent checks](Final_Project/spp_recovery/checks/README.txt).

## Earlier stages remain available

The selected hard gate was chosen on development data, then frozen for the original 48-condition new-sentence test. It improved mean STOI by **0.00404** over the original gate while remaining **0.00064 below fixed estimation**. In the earlier 36-mixture diagnostic, both gates blocked all late updates after a rise. In the larger new confirmation set, the selected gate has no late updates in **32/36** rising cases; that older all-case result is not generalised to every new input.

The earlier benchmark spectrogram, condition table and sentence-sensitivity figure are retained in [Supporting Results](Final_Project/report/Supporting_Results.pdf); the main report stays at 12 pages. The [original project source](Project_Feedback_Two_NOIZEUS/README.md), [parameter study](Final_Project/Final_Project_Study/README.txt), [unified score replay](Final_Project/reanalysis/README_REANALYSIS.txt), and [earlier controlled diagnostic](Final_Project/controlled_study/README.txt) remain available. [RUN_ORIGINAL_DEMO.m](Final_Project/RUN_ORIGINAL_DEMO.m) runs the earlier four-output demonstration.

## Recorded demonstration

The completed [5 min 24 sec recording](https://yche0441.github.io/elec5305-project-550889472/Final_Project/video/index.html) includes English captions and an actual MATLAB run. It covers the original hard-gate comparison and the first controlled noise-change experiment. The follow-up soft-tracker methods and results are documented in report Sections 8–9, the website and the new runnable demo; they are not claimed to be part of that earlier narration.

[MP4](Final_Project/video/ELEC5305_Final_Project_Video.mp4) · [English SRT](Final_Project/video/ELEC5305_Final_Project_English.srt) · [Spoken transcript](Final_Project/video/Final_Video_Transcript.txt)

## Attribution and scope

The TSNR enhancer derives from **LIU Ming / Pascal Scalart** and Plapous et al. The soft-SPP estimator and safeguard derive from **Gerkmann and Hendriks (2012)**; their source licence and exact parameter provenance are retained. Inputs come from the **NOIZEUS corpus / Hu and Loizou**. The contribution is integration, controlled experiments, numerical verification and interpretation, not invention of the inherited algorithms.

The follow-up tests new sentences but not unseen speakers. Results are aggregated within sentence and then within the six known speakers; repeated conditions are not independent people. Short recordings, constructed level changes and energy-based diagnostic proxies restrict the conclusions. No significance, perceptual-preference or subjective-listening claim is made.
