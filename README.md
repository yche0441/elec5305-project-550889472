# When does VAD-guided noise updating help Wiener speech enhancement?

**ELEC5305 Final Project · Yulong Chen · SID 550889472 · 21 October 2026**

[Project website](https://yche0441.github.io/elec5305-project-550889472/) · [Final report](ELEC5305_Final_Project_Yulong_Chen.pdf) · [Final video](https://yche0441.github.io/elec5305-project-550889472/Final_Project/video/index.html) · [Working code and reproduction instructions](Final_Project/README.txt)

This project studies the trade-off between tracking noise and protecting speech in a shared two-step noise-reduction (TSNR) Wiener enhancer. The contribution is a controlled adaptation, reproducibility checks, a frozen parameter study, new-sentence testing and a matched noise-level experiment. The common TSNR method derives from the credited implementation by LIU Ming / Pascal Scalart.

## Final findings

- On 48 conditions from six new sentences, selected VAD improved mean standard STOI over original VAD by **0.00404**, but remained **0.00064 below fixed estimation**. Selected-minus-fixed mean reference SNR was **+0.0636 dB**. These are small descriptive differences.
- A new **36-mixture matched diagnostic** holds the speech and base noise fixed and varies only the noise level: constant, +6 dB or -6 dB. All parameters remain frozen; previously used sentences make this a mechanism diagnostic, not a new generalisation test.
- After the +6 dB rise, neither VAD updates in the late interval. Increased energy can prevent an energy-based detector from recognising a safe noise-update opportunity. After the -6 dB fall, updating resumes; selected-minus-fixed whole-record SNR is **+0.143 dB** and STOI **+0.00201**, averaged across sentence units.
- Cautious gating reduces speech entering the noise update, but does not provide universal noise tracking. SNR, STOI and subjective quality are different quantities; no listener study is claimed.

All main-report STOI values use **standard PySTOI 0.4.1, `extended=False`**. Original native MATLAB STOI scores are preserved as historical evidence and are not mixed into the main comparisons.

## Run and inspect

1. Download the repository and keep the `Final_Project` subfolders together.
2. Install the dependencies listed in [requirements.txt](Final_Project/requirements.txt), if needed.
3. Open [START_HERE.m](Final_Project/START_HERE.m) in MATLAB and press Run. It checks the environment, reruns a predetermined single example, and verifies all four fresh SNR/STOI pairs against saved results.
4. The lower plot panels display **stored 48-condition means**. They are not a full live experiment. Enter `play_demo_audio` for optional same-gain audio; enter `show_controlled_results` to display the saved diagnostic plots.

The [complete reproduction guide](Final_Project/README.txt) covers the full parameter study, [portable metric replay](Final_Project/reanalysis/README_REANALYSIS.txt), and [controlled noise-change experiment](Final_Project/controlled_study/README.txt). Saved results, protocols, source provenance and licences are included.

## Report and video

[Download the final project report](ELEC5305_Final_Project_Yulong_Chen.pdf).

[Watch the final demonstration (5 min 24 sec)](https://yche0441.github.io/elec5305-project-550889472/Final_Project/video/index.html), with English captions and an actual MATLAB run. [Download the MP4](Final_Project/video/ELEC5305_Final_Project_Video.mp4), [SRT captions](Final_Project/video/ELEC5305_Final_Project_English.srt), or [spoken transcript](Final_Project/video/Final_Video_Transcript.txt). The recording distinguishes the freshly computed single example from the stored full-study and controlled-study results.

## Data, limitations and earlier work

Speech/noise inputs are an unchanged subset of the **NOIZEUS** corpus (Hu and Loizou), rather than new environmental recordings by the student. Controlled mixtures are explicit remixes of those paired inputs. The corpus attribution and original code licence are retained.

The six new test sentences reuse some speakers, and the controlled experiment reuses those sentences. Repeated conditions are not independent speakers. Small sample sizes, short recordings, energy-proxy labels and the lack of listener evaluation limit the conclusions. Sentence-level and leave-one-sentence-out analyses are descriptive checks, not confidence intervals.

The [original Feedback Two source and native results](Project_Feedback_Two_NOIZEUS/README.md), [original progress report](ELEC5305_Project_Feedback_Two_Yulong_Chen_550889472.pdf), and earlier project files remain preserved. Their native STOI values describe the earlier analysis; use the final package's reanalysis tables for the final report.
