"""Plot matched rise/fall diagnostics from saved MATLAB outputs; no re-fitting.

Usage:
  python build_paired_tracking_figure.py
  python build_paired_tracking_figure.py --data-dir /path/to/controlled_study --output /path/to/figures

The default data folder is the helper's own directory; figures go in ./figures.
The same sp02/street
example as the original tracking figure is retained; its matched fall condition
is added. The figure is explanatory and is not a representative-case estimate.
"""
from pathlib import Path
import argparse
import hashlib
import json
import wave

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_pcm16(path):
    with wave.open(str(path), "rb") as f:
        assert f.getnchannels() == 1 and f.getsampwidth() == 2 and f.getframerate() == 8000
        return np.frombuffer(f.readframes(f.getnframes()), dtype="<i2").astype(float) / 32768


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--data-dir", type=Path, default=Path(__file__).resolve().parent)
    ap.add_argument("--output", type=Path)
    args = ap.parse_args()
    study = args.data_dir.resolve()
    out = args.output.resolve() if args.output else study / "figures"
    out.mkdir(parents=True, exist_ok=True)
    traces = pd.read_csv(study / "frame_diagnostics.csv")
    checks = pd.read_csv(study / "verification_cases.csv")
    fs = 8000
    clean = read_pcm16(study / "data/clean/sp02.wav")
    noisy = read_pcm16(study / "data/street/10dB/sp02_street_sn10.wav")
    residual = noisy - clean
    methods = ["fixed", "vad_original", "vad_selected"]
    profiles = ["rise_6dB", "fall_6dB"]
    labels = {"fixed": "Fixed estimate", "vad_original": "Original VAD estimate",
              "vad_selected": "Selected VAD estimate"}
    colors = {"fixed": "#454545", "vad_original": "#BA5A18", "vad_selected": "#126D9B"}
    styles = {"fixed": "--", "vad_original": "-.", "vad_selected": "-"}
    evidence = {"example": "sp02 / street", "profiles": {}, "normalisation":
                "10 log10(frame broadband power / shared initial noise PSD sum)",
                "input_sha256": {name: sha256(study / name) for name in
                    ["frame_diagnostics.csv", "verification_cases.csv",
                     "data/clean/sp02.wav", "data/street/10dB/sp02_street_sn10.wav"]}}

    plt.rcParams.update({
        "font.family": "DejaVu Sans", "font.size": 10,
        "axes.titlesize": 11, "axes.labelsize": 10.5, "legend.fontsize": 10.2,
        "xtick.labelsize": 10.2, "ytick.labelsize": 10.2,
        "axes.spines.top": False, "axes.spines.right": False,
        "svg.fonttype": "none", "savefig.facecolor": "white",
    })
    fig, axs = plt.subplots(2, 2, figsize=(7.35, 3.8), sharex=True,
                            gridspec_kw={"height_ratios": [2.35, 0.85]})
    fig.subplots_adjust(left=.145, right=.985, top=.79, bottom=.20,
                        hspace=.20, wspace=.12)
    prefix_estimates = {}
    maxima = []
    for col, profile in enumerate(profiles):
        check = checks[(checks.Utterance == "sp02") & (checks.Noise == "street") &
                       (checks.Profile == profile)].iloc[0]
        change_sample = int(check.ChangeStartSample)
        post_sample = int(check.PostStartSample)
        gain_db = np.zeros(len(clean))
        target_db = 6 if profile == "rise_6dB" else -6
        ramp_n = round(.05 * fs)
        gain_db[change_sample-1:change_sample-1+ramp_n] = np.linspace(0, target_db, ramp_n)
        gain_db[change_sample-1+ramp_n:] = target_db
        injected = residual * 10**(gain_db / 20)
        mixture = clean + injected
        g = traces[(traces.Utterance == "sp02") & (traces.Noise == "street") &
                   (traces.Profile == profile)]
        base = g[g.Method == "fixed"].reset_index(drop=True)
        starts = base.FrameStartSample.to_numpy(dtype=int)
        time = base.Time_s.to_numpy()
        power = base.InjectedFramePower.to_numpy()
        reference = float(base.EstimateBeforeUpdate.iloc[0])
        assert np.all(base.EstimateBeforeUpdate.to_numpy() == reference)
        # Recompute injected-noise broadband FFT power independently.
        idx = starts[:, None] - 1 + np.arange(200)[None, :]
        window = .5 - .5 * np.cos(2 * np.pi * np.arange(1, 201) / 201)
        measured = np.sum(abs(np.fft.fft(injected[idx] * window, 400, axis=1))**2, axis=1)
        max_noise_rel_error = float(np.max(abs(measured - power) / measured))
        assert max_noise_rel_error < 1e-12
        change = (change_sample - 1) / fs
        late = (post_sample - 1) / fs
        late_mask = base.LatePost.to_numpy(dtype=bool)
        low_energy = base.NonSpeechProxy.to_numpy(dtype=bool)
        assert len(time) == 251 and int(late_mask.sum()) == 109
        assert np.array_equal(late_mask, starts >= post_sample)
        input_frame_power = np.sum(abs(np.fft.fft(mixture[idx] * window,
                                                  400, axis=1))**2, axis=1)
        panel = {"change_start_s": change, "ramp_end_s": change + .05,
                 "late_start_sample_s": late, "valid_frames": len(time),
                 "late_frames": int(late_mask.sum()),
                 "late_low_energy_proxy_frames": int((late_mask & low_energy).sum()),
                 "initial_broadband_estimate": reference,
                 "max_injected_noise_power_relative_error": max_noise_rel_error,
                 "methods": {}}
        ax = axs[0, col]
        ax.plot(time, 10 * np.log10(power / reference), color="#9B9B9B", lw=.85,
                label="Injected noise power", zorder=2)
        for mi, method in enumerate(methods):
            d = g[g.Method == method].reset_index(drop=True)
            assert np.array_equal(time, d.Time_s.to_numpy())
            assert np.array_equal(power, d.InjectedFramePower.to_numpy())
            estimate = d.EstimateBeforeUpdate.to_numpy()
            updated = d.Updated.to_numpy(dtype=bool)
            expected_next = np.where(updated, .95 * estimate + .05 * input_frame_power, estimate)
            recurrence_error = float(np.max(abs(estimate[1:] - expected_next[:-1]) / estimate[1:]))
            assert recurrence_error < 1e-12
            prefix = (starts + 199) < change_sample
            prefix_estimates[(profile, method)] = estimate[prefix]
            ax.plot(time, 10 * np.log10(estimate / reference), color=colors[method],
                    ls=styles[method], lw=1.5, label=labels[method], zorder=3+mi)
            panel["methods"][method] = {"late_updates": int((updated & late_mask).sum()),
                                          "total_updates": int(updated.sum()),
                                          "max_recurrence_relative_error": recurrence_error}
            if method != "fixed":
                row = 2 if method == "vad_original" else 1
                axs[1, col].plot(time[updated], np.full(updated.sum(), row),
                                 "|", color=colors[method], markersize=9,
                                 markeredgewidth=1.15, zorder=4)
        axs[1, col].plot(time[low_energy], np.zeros(low_energy.sum()), "|", color="#687483",
                         markersize=9, markeredgewidth=1.1, zorder=3)
        nums = panel["methods"]
        title = "(a) Noise rise +6 dB" if profile == "rise_6dB" else "(b) Noise fall -6 dB"
        ax.set_title(title, loc="left", pad=9, fontweight="bold")
        ax.text(.025, .96, "Late updates: " + str(nums["vad_original"]["late_updates"]) +
                " original, " + str(nums["vad_selected"]["late_updates"]) + " selected",
                transform=ax.transAxes, fontsize=10.0, va="top", color="#222222",
                bbox={"facecolor": "white", "edgecolor": "none", "alpha": .9, "pad": 1.5}, zorder=7)
        ax.set_ylim(-11, 19)
        ax.set_yticks([-10, 0, 10])
        ax.grid(axis="y", color="#DFDFDF", lw=.6, zorder=0)
        axs[1, col].set_ylim(-.55, 2.55)
        axs[1, col].set_yticks([0, 1, 2])
        axs[1, col].set_yticklabels(["Low energy", "Selected", "Original"]
                                  if col == 0 else [])
        axs[1, col].tick_params(axis="y", length=0, labelsize=10.2)
        axs[1, col].set_xticks([0, .5, 1, 1.5, 2, 2.5])
        axs[1, col].set_xlim(0, len(clean) / fs)
        axs[1, col].set_xlabel("Time (s)", labelpad=3)
        for a in axs[:, col]:
            a.axvspan(change, change + .05, facecolor="#E7BF62", alpha=.42, zorder=1)
            a.axvline(late, color="#6F6F6F", ls=":", lw=1, zorder=2)
        if col:
            ax.tick_params(labelleft=False)
        evidence["profiles"][profile] = panel

    for method in methods:
        assert np.array_equal(prefix_estimates[(profiles[0], method)],
                              prefix_estimates[(profiles[1], method)])
    assert evidence["profiles"][profiles[0]]["initial_broadband_estimate"] == \
           evidence["profiles"][profiles[1]]["initial_broadband_estimate"]
    axs[0, 0].set_ylabel("Broadband power relative to\ninitial estimate (dB)", labelpad=5)
    handles = [Line2D([], [], color="#9B9B9B", lw=1, label="Injected noise power")]
    handles += [Line2D([], [], color=colors[m], ls=styles[m], lw=1.5, label=labels[m]) for m in methods]
    fig.legend(handles=handles, loc="upper center", bbox_to_anchor=(.54, .985), ncol=2,
               frameon=False, handlelength=2.7, columnspacing=1.8)
    fig.text(.55, .035, "Gold: 50 ms ramp   |   Dotted: late interval begins   |   sp02 / street",
             ha="center", va="center", fontsize=10.2, color="#333333")
    for suffix in ["png", "svg"]:
        fig.savefig(out / ("paired_tracking." + suffix), dpi=300)
    plt.close(fig)
    evidence["checks"] = {"matched_prechange_estimates_exact": True,
                            "shared_initial_estimate_exact": True,
                            "no_MATLAB_rerun": True,
                            "no_parameter_changes": True}
    (out / "paired_tracking_validation.json").write_text(json.dumps(evidence, indent=2) + "\n")
    caption = (
        "Figure 4. Matched noise tracking for the original diagnostic sentence sp02 with street noise: "
        "(a) +6 dB rise and (b) -6 dB fall. Gray traces show the actual injected-noise broadband power "
        "in each 25 ms analysis window; estimator traces show the summed noise PSD before each update. "
        "All powers are normalized by the same initial estimate. The 50 ms ramp is shaded; the dotted "
        "line marks the late interval, which begins 100 ms after the ramp. Raster marks identify accepted "
        "noise updates and the independent low-clean-energy proxy, not manually labelled silence. "
        "Across 109 late frames per condition, neither gate updates after the rise; the original and "
        "selected gates accept 31 and 11 updates after the fall. These paired traces illustrate the "
        "asymmetry of gating, not a general guarantee of tracking accuracy or perceptual improvement."
    )
    (out / "paired_tracking_caption.txt").write_text(caption + "\n")
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
