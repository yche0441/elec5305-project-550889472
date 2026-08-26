# Evaluation of VAD-Guided Wiener Filtering for Speech Enhancement Using Real Recordings in Everyday Noise

This ELEC5305 project evaluates VAD-guided Wiener filtering for speech enhancement using real speech recordings captured in everyday noisy environments.

## Student Information

- **Name:** Yulong Chen
- **SID:** 550889472
- **GitHub username:** yche0441

## Project Overview

The project will compare a Wiener filter with a fixed noise estimate against a VAD-guided Wiener filter that updates its noise estimate during likely non-speech frames. The aim is to examine whether adaptive noise updating improves noise reduction while preserving the speech signal.

## Research Question

How much does VAD-guided noise updating improve noise reduction and speech preservation compared with a fixed-noise Wiener filter when both systems are tested on real recordings made in everyday noisy environments?

## Real Recording Requirement

The project will use speech recorded in a quiet room and in the presence of real electric-fan and traffic noise. It will not use MATLAB-generated noise, synthesised noisy speech, or digital mixing of clean speech and noise files.

## Planned MATLAB Methods

1. Inspect each recording using waveforms, spectra, and spectrograms.
2. Apply short-time Fourier transform analysis.
3. Implement a Wiener filter with one fixed noise estimate.
4. Implement energy-based voice activity detection.
5. Update the noise estimate during likely non-speech frames.
6. Reconstruct and compare the enhanced recordings.

## Planned Evaluation

The comparison will use estimated noise attenuation, estimated speech-to-noise ratio, speech-frame energy and spectral changes, processing time, spectrograms, and listening examples. Results will be added only after the recordings have been collected and the MATLAB code has been tested.

## Repository Contents

- `ELEC5305_Project_Proposal_Yulong_Chen.pdf` - formal project proposal
- `src/` - MATLAB source code to be added during implementation
- `audio/` - shareable real recording examples to be added after collection
- `results/` - figures, tables, and processed examples to be added after testing

## Project Site

[GitHub Pages project site](https://yche0441.github.io/elec5305-project-550889472/)
