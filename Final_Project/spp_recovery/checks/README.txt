Independent verification of the frozen recovery study

The JSON records describe the completed 4 November independent checks.
All 252 raw cases and 1,512 SNR rows were independently checked, together
with the preselected spectral diagnostic/SPP recurrences, representative
STOI calculations, and every sentence/speaker/paired table.

To replay, use a COPY of the complete package (or first regenerate the
signals/*.mat chunks with run_recovery_study). With requirements.txt
installed, run either Python file in this checks directory. Both use
relative paths. Their only packaging change is the root-directory
lookup, recorded in AUDIT_SCRIPT_PACKAGING.json. They write audit JSON
in this directory, so use a copy to preserve the supplied records.
