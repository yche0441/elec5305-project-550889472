# Short literature review for the revised experiment

This review connects eight relevant papers to the first controlled experiment. It describes published ideas and the planned comparison; it does not claim new enhancement results or a comprehensive survey of current speech-enhancement systems. The cited methods are established foundations appropriate to the teacher's requested scope.

## Wiener enhancement and the existing implementation

Scalart and Vieira Filho [1] examine frequency-domain enhancement and emphasize estimating the a priori SNR. This supports using an established SNR estimator when studying noise tracking, so the comparison does not simultaneously change several parts of the filter. The accessible abstract supports this overview; detailed claims about every equation or parameter in the 1996 paper are not made here.

Plapous, Marro and Scalart [2] discuss the delayed response of decision-directed SNR estimation and propose two-step noise reduction (TSNR), followed by harmonic regeneration noise reduction (HRNR). The supplied MATLAB function implements both branches. The present comparison uses only its TSNR branch, with the same gain calculation in fixed and VAD modes. HRNR would introduce an additional processing change and is left outside this first comparison. The paper provides the direct technical context for the reproduced source. [Author full text](https://www.researchgate.net/publication/3457674_Improved_Signal-to-Noise_Ratio_Estimation_for_Speech_Enhancement).

## Voice activity and changing noise

Sohn, Kim and Sung [3] use statistical modelling, a likelihood-ratio decision and a hangover scheme to detect speech activity. This is a useful reference for why frame decisions and temporal continuity both matter. The project instead uses a simple energy ratio and five-frame hangover, as permitted by the teacher. It does not claim to reproduce Sohn's likelihood model. The simpler detector makes the interaction between missed speech and noise updating easier to inspect. [Author full text](https://www.researchgate.net/publication/3342424_A_statistical_model-based_voice_activity_detection).

Martin [4] estimates noise from smoothed spectral minima without requiring a speech/non-speech detector. It supplies an alternative to hard VAD gating: background noise can be tracked using spectral history. Its treatment of smoothing and minimum-statistics bias also shows that noise estimation is more than selecting quiet frames. Implementing this alternative is outside the first controlled comparison, but it provides context if the energy detector fails in changing noise. [Author paper record and text](https://www.researchgate.net/publication/3333805_Noise_power_spectral_density_estimation_based_on_optimal_smoothing_and_minimum_statistics).

Cohen and Berdugo [5] use minima-controlled recursive averaging (MCRA). Their noise estimate depends on speech-presence information derived from a comparison with local minima. This supports recursive updating while showing why an uncertain decision may need more care than an immediate binary update. The project's update coefficient is fixed and its VAD is energy-based; this is not an implementation of MCRA. [Author PDF](https://israelcohen.com/wp-content/uploads/2018/05/SPL_Jan2002.pdf).

Cohen [6] develops improved MCRA for adverse noise conditions. This extends the discussion from whether to update to how reliably speech absence can be inferred. Together, [4]-[6] motivate recording VAD errors and update activity alongside enhancement scores. They do not establish in advance that this project's simple VAD will outperform a fixed estimate. [Author PDF](https://israelcohen.com/wp-content/uploads/2018/05/SAP_Sep2003.pdf).

## Evaluation

Taal et al. [7] present STOI as a predictor of the intelligibility of noisy and time-frequency-processed speech. It complements reference SNR because waveform error and intelligibility are different properties. The experiment uses MATLAB's established `stoi` implementation, not a new approximation. A higher STOI score remains a prediction and does not replace listening. The paper's abstract and publication details, and the implementation documentation, were checked; a complete derivation review remains future reading. [Paper record](https://www.researchgate.net/publication/224219052_An_Algorithm_for_Intelligibility_Prediction_of_Time-Frequency_Weighted_Noisy_Speech), [MATLAB implementation](https://www.mathworks.com/help/audio/ref/stoi.html).

Hu and Loizou [8] introduce a common noisy-speech corpus and compare enhancement algorithms using judgments that distinguish speech distortion, background distortion and overall quality. This supports using the same paired recordings for both methods and retaining listening examples. This small project does not reproduce their listener study or treat objective scores as listener ratings. [Author manuscript](https://pmc.ncbi.nlm.nih.gov/articles/PMC2098693/).

## Implication for this project

The first experiment holds the TSNR processing path constant and changes only noise updating. It asks whether the change helps for each noise condition and whether any gain comes with speech loss. Failure cases are useful: a rise in background noise may prevent updates when it triggers a speech decision, while weak speech may be absorbed into the noise estimate. The code records the information needed to examine these possibilities after the native MATLAB run.

## References

[1] P. Scalart and J. Vieira Filho, “Speech enhancement based on a priori signal to noise estimation,” in *Proc. IEEE ICASSP*, vol. 2, pp. 629-632, 1996. [doi:10.1109/ICASSP.1996.543199](https://doi.org/10.1109/ICASSP.1996.543199). [Accessible abstract](https://www.researchgate.net/publication/3644389_Speech_enhancement_based_on_a_priori_signal_to_noise_estimation).

[2] C. Plapous, C. Marro, and P. Scalart, “Improved signal-to-noise ratio estimation for speech enhancement,” *IEEE Trans. Audio, Speech, Language Process.*, vol. 14, no. 6, pp. 2098-2108, 2006. [doi:10.1109/TASL.2006.872621](https://doi.org/10.1109/TASL.2006.872621).

[3] J. Sohn, N. S. Kim, and W. Sung, “A statistical model-based voice activity detection,” *IEEE Signal Process. Lett.*, vol. 6, no. 1, pp. 1-3, 1999. [doi:10.1109/97.736233](https://doi.org/10.1109/97.736233).

[4] R. Martin, “Noise power spectral density estimation based on optimal smoothing and minimum statistics,” *IEEE Trans. Speech Audio Process.*, vol. 9, no. 5, pp. 504-512, 2001. [doi:10.1109/89.928915](https://doi.org/10.1109/89.928915).

[5] I. Cohen and B. Berdugo, “Noise estimation by minima controlled recursive averaging for robust speech enhancement,” *IEEE Signal Process. Lett.*, vol. 9, no. 1, pp. 12-15, 2002. [doi:10.1109/97.988717](https://doi.org/10.1109/97.988717).

[6] I. Cohen, “Noise spectrum estimation in adverse environments: Improved minima controlled recursive averaging,” *IEEE Trans. Speech Audio Process.*, vol. 11, no. 5, pp. 466-475, 2003. [doi:10.1109/TSA.2003.811544](https://doi.org/10.1109/TSA.2003.811544).

[7] C. H. Taal, R. C. Hendriks, R. Heusdens, and J. Jensen, “An algorithm for intelligibility prediction of time-frequency weighted noisy speech,” *IEEE Trans. Audio, Speech, Language Process.*, vol. 19, no. 7, pp. 2125-2136, 2011. [doi:10.1109/TASL.2011.2114881](https://doi.org/10.1109/TASL.2011.2114881).

[8] Y. Hu and P. C. Loizou, “Subjective comparison and evaluation of speech enhancement algorithms,” *Speech Communication*, vol. 49, pp. 588-601, 2007. [doi:10.1016/j.specom.2006.12.006](https://doi.org/10.1016/j.specom.2006.12.006).
