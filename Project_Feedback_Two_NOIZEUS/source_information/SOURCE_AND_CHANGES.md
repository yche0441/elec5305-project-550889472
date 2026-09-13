# Source provenance and changes

## Existing code

The supplied source is `WienerNoiseReduction.m`, from Pascal Scalart's [Wiener filter for Noise Reduction and speech enhancement](https://www.mathworks.com/matlabcentral/fileexchange/24462-wiener-filter-for-noise-reduction-and-speech-enhancement) File Exchange submission. Its header credits LIU Ming (2008), with modifications by Pascal Scalart (2008 and 2020). It cites Plapous, Marro and Scalart (2006), not only the earlier Scalart and Vieira Filho paper. The unchanged source and original licence are in `original_reference/`.

The source includes TSNR, HRNR and its own `gaincontrol` helper. The project adaptation retains the TSNR equations and gain constraint. Its additional work is the controlled noise-update option, shared reconstruction changes, reproducible corpus selection and explicit evaluation/diagnostics. The original source must not be presented as wholly student-written code.

## Original MATLAB evidence

The student supplied `Scalart_Original_Results.zip`, containing the original source, demo WAV, licence, plots and `Scalart_Original_Run.mat`. That MAT file stores `x`, `fs`, `esTSNR`, `esHRNR` and `matlabVersion`. It reports MATLAB R2026a Update 5. The visible run used `WienerNoiseReduction(x,fs,10000)`. The saved MAT does not itself contain the initial-silence parameter or a runtime measurement.

The current package preserves that MAT as compatibility evidence. The separate Python preflight's legacy TSNR path agrees with `esTSNR` to a maximum absolute difference of about 5.0e-16. This is agreement with an actual previous MATLAB run, not a claim that the new experiment has been executed in MATLAB. The old demo has no clean reference and cannot supply true reference SNR or STOI.

## Changes shared by both experimental modes

1. The TSNR branch is isolated as a callable function without automatic figures. HRNR remains only in the archived original.
2. The verified legacy analysis window and original gain constraint are written explicitly, avoiding a silent change of window convention.
3. Mono/8 kHz input, finite values, recording length and reconstruction coverage are checked. PSD divisions and silent input have numerical guards.
4. Initial calibration is 800 samples, selected by input inspection. Its small clean-energy contamination is quantified, rather than described as exact silence.
5. Common computational padding and window-sum overlap-add normalization replace the author's fixed overlap-add scale and independent output peak normalization. The output length is unchanged. This adaptation is necessary to make output amplitude interpretable in reference-error measurements.
6. A separate legacy verification option preserves the old boundary, overlap-add and peak-normalization behaviour only for comparison with the saved author-code output.

## Experimental change

VAD mode recursively updates the noise PSD on eligible non-speech decisions. Fixed mode keeps the initial PSD. The two systems share the same function and configuration. Clean reference data never enter this function. The initial PSD is asserted equal in every paired run, and a gate checks identical output when the update coefficient is set to one.

## Verification scope

`verification/PREFLIGHT.json` records the checks actually performed in Python. They include legacy agreement with saved MATLAB evidence, identity reconstruction for the six sentence lengths, fixed/frozen-VAD equivalence for 16 development cases and silent-input handling. `verification/python_reference.mat` contains numerical test fixtures for sp01/car/0 dB. These are not project metric results.

`verify_core.m` repeats the important gates in native MATLAB before processing the experiment. The fixture is specific to protocol v1. A deliberate later parameter change needs a versioned protocol and corresponding verification update; it should not be mixed into the v1 results.

The MATLAB files were parsed with MISS_HIT in syntax-check mode. Parsing is not a replacement for running them in MATLAB. STOI availability, native plot export and the complete native result archive still need confirmation through the user's run.

## Audio provenance

The user downloaded the clean and car/street 0/5/10/15 dB archives from the [official NOIZEUS page](https://ecs.utdallas.edu/loizou/speech/noizeus/) and uploaded all nine files. The package copies 54 selected WAV files without modifying their bytes. `DATA_AUDIT.json` records the original archive hashes and every selected WAV hash. The dataset is cited separately from the code. The original code licence does not transfer ownership of the corpus recordings.
