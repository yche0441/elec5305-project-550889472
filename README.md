# Evaluation of VAD-Guided Wiener Filtering for Speech Enhancement Using Real Recordings in Everyday Noise

**Yulong Chen** | **SID 550889472** | **ELEC5305**

This project compares fixed-noise Wiener filtering with an energy-VAD-guided noise update. Four pilot cases were completed in MATLAB Online R2026a Update 5 on 11 September 2026. Both methods increased reference SNR, and the fixed baseline produced higher reference SNR in all four cases.

The current data are laboratory acoustic re-recordings from SpEAR, using factory and Volvo noise. They differ from the student-recorded fan and traffic data in the original proposal. The code does not generate noise or digitally mix speech and noise.

- [Project website](https://yche0441.github.io/elec5305-project-550889472/)
- [Project Feedback Two progress](Project_Feedback_Two/feedback_two_progress.md)
- [Method and MATLAB run instructions](Project_Feedback_Two/README.md)
- [Measured results](Project_Feedback_Two/results_matlab/metrics.csv)
- [MATLAB results ZIP](Project_Feedback_Two/Project_Feedback_Two_MATLAB_Results.zip)
- [Original proposal](ELEC5305_Project_Proposal_Yulong_Chen.pdf)

To reproduce the pilot, download this repository, open the `Project_Feedback_Two` folder in MATLAB and run `run_project_feedback2.m`. All required pilot inputs and helper functions are included. The source documentation is retained in `Project_Feedback_Two/source_information`.
