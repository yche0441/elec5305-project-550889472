---
title: ELEC5305 Real Speech Enhancement Project
---

# Evaluation of VAD-Guided Wiener Filtering for Speech Enhancement Using Real Recordings in Everyday Noise

**Student:** Yulong Chen  
**SID:** 550889472  
**GitHub username:** yche0441

## Project Overview

This project will compare a Wiener filter with a fixed noise estimate against a VAD-guided Wiener filter that updates its noise estimate during likely non-speech frames. The aim is to examine whether adaptive noise updating improves noise reduction while preserving speech in real everyday recordings.

## Research Question

How much does VAD-guided noise updating improve noise reduction and speech preservation compared with a fixed-noise Wiener filter when both systems are tested on real recordings made in everyday noisy environments?

## Real Audio Data

The planned data will include speech recorded in a quiet room and speech recorded while real electric-fan and traffic noise are present. The project will not generate noise in MATLAB, synthesise noisy speech, or digitally mix clean speech with noise files.

## Planned Processing

1. Waveform, spectrum, and spectrogram inspection
2. Short-time Fourier transform analysis
3. Fixed-noise Wiener filtering
4. Energy-based voice activity detection
5. VAD-guided noise updating and Wiener filtering
6. Inverse STFT reconstruction and comparison

## Planned Evaluation

The comparison will use estimated noise attenuation, estimated speech-to-noise ratio, speech-frame energy and spectral changes, processing time, spectrograms, and listening examples. Experimental results will be added only after the recordings have been collected and the MATLAB implementation has been tested.

## Proposal

The formal proposal PDF will be available from this repository.

