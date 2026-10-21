REPORT METRIC REANALYSIS

Place reanalyze.py and this file in the final package's reanalysis/ folder.
Keep results_recomputed/ as the saved reference output alongside the script.
The parent package contains Project_Feedback_Two_NOIZEUS/ and Final_Project_Study/.

Use Python 3 with numpy, scipy and pystoi 0.4.1 installed. The exact dependency
versions used for the supplied replay are recorded in results_recomputed/REANALYSIS.json.

From the package root:
    python3 reanalysis/reanalyze.py

The script locates input files relative to its own location, so the current
working directory does not matter. To save a separate comparison run:
    python3 reanalysis/reanalyze.py --output replayed_tables

Alternative layouts can use explicit paths:
    python3 reanalyze.py --original-project path/to/Project_Feedback_Two_NOIZEUS --study-root path/to/Final_Project_Study --output path/to/recomputed

WHAT IS REPRODUCED
- Standard STOI and reference SNR for all 144 original method-case waveforms.
- Original evaluation means and paired comparisons with unified STOI.
- Nine-configuration development means from frozen per-case results.
- New-test method means, paired condition effects and sentence averages.
- Leave-one-sentence-out sensitivity without treating repeated conditions as
  independent speakers. These ranges are not confidence intervals.

DATA INTEGRITY AND SCOPE
The original MATLAB evidence ZIP is read directly in memory. It is neither
extracted nor modified. Input hashes, dependencies and scoring interval are
saved in REANALYSIS.json. Every recomputed SNR is checked against the original
archive; every recomputed STOI is checked against the existing validation CSV.
Only outputs are written. No parameter is selected or retuned by this script.

This is a metric replay of already generated original waveforms and arithmetic
reanalysis of the extension. To regenerate enhanced waveforms, use the MATLAB
runners in the corresponding experiment directories. The controlled noise
experiment has its own runner and scorer in controlled_study/.

The historical original metrics.csv continues to contain native MATLAB STOI.
Use reanalysis/results_recomputed/v1_rescored_metrics.csv for main-report v1
comparisons, which share pystoi 0.4.1 with the later studies. Never subtract a
native score from a Python score or overwrite the original results archive.
