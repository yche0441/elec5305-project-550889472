"""Independent Python numerical check; this is NOT MATLAB execution evidence.

Run from any directory with Python, NumPy, SciPy and Matplotlib installed.
The authoritative MATLAB runner is ../run_project_feedback2.m. This optional
check exercises STFT reconstruction and identical-method controls on real WAVs.
"""
from pathlib import Path
import csv
import hashlib
import json
import platform

import numpy as np
import scipy
from scipy.io import wavfile
from scipy.signal import correlate, correlation_lags
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(__file__).resolve().parent
UTTERANCES = ("butter", "scholars")
ENVIRONMENTS = ("factory", "volvo")
INTERVALS = {"butter": (2.42, 2.50), "scholars": (1.90, 2.20)}
L, H, K, FS = 400, 160, 512, 16000


def read_wav(path):
    fs, x = wavfile.read(path)
    assert fs == FS and x.ndim == 1 and x.dtype == np.int16
    return x.astype(np.float64) / 32768.0


def enhance(x, interval, method, threshold=3.0):
    count = int(np.ceil((len(x) + L) / H)) + 1
    length = (count-1)*H + L
    buffer = np.zeros(length)
    buffer[L:L+len(x)] = x
    starts = np.arange(count)*H
    window = 0.54 - 0.46*np.cos(2*np.pi*np.arange(L)/(L-1))
    indices = np.arange(L)[:, None] + starts[None, :]
    spectrum = np.fft.rfft(buffer[indices]*window[:, None], K, axis=0)
    power = np.abs(spectrum)**2
    begin = (starts-L)/FS
    end = (starts-L+L)/FS
    complete = (begin >= 0) & (end <= len(x)/FS)
    calibration = complete & (begin >= interval[0]-1e-12) & (end <= interval[1]+1e-12)
    assert calibration.sum() >= 3
    initial = power[:, calibration].mean(axis=1)
    floor = max(initial.max()*1e-12, np.finfo(float).eps)
    noise = np.maximum(initial, floor)
    previous_gain = np.ones(len(noise))
    output = np.zeros_like(spectrum)
    update = np.zeros(count, dtype=bool)
    hold = 0
    for k in range(count):
        observed = power[:, k]
        ratio = 10*np.log10((observed.sum()+np.finfo(float).eps)/(noise.sum()+np.finfo(float).eps))
        speech = False
        if ratio > threshold:
            speech = True
            hold = 5
        elif hold > 0:
            speech = True
            hold -= 1
        if method == "vad" and complete[k] and not calibration[k] and not speech:
            noise = np.maximum(0.90*noise + 0.10*observed, floor)
            update[k] = True
        if method == "identity":
            gain = np.ones_like(noise)
        else:
            xi = np.maximum(observed/noise-1, 0)
            raw = np.maximum(xi/(1+xi), 0.10)
            gain = 0.60*previous_gain + 0.40*raw
        previous_gain = gain
        output[:, k] = gain*spectrum[:, k]
    result = np.zeros(length)
    weights = np.zeros(length)
    for k, start in enumerate(starts):
        frame = np.fft.irfft(output[:, k], K)
        result[start:start+L] += frame[:L]*window
        weights[start:start+L] += window**2
    assert np.all(weights[L:L+len(x)] > 0)
    result = result[L:L+len(x)]/weights[L:L+len(x)]
    assert len(result) == len(x) and np.isfinite(result).all()
    return result, update.sum()/max(np.sum(complete & ~calibration), 1)


def metrics(reference, original, processed, interval):
    eps = np.finfo(float).eps
    # Match MATLAB conv(...,'same') alignment for the even-length kernel.
    full = np.convolve(reference**2, np.ones(L)/L, mode="full")
    local = full[L//2:L//2+len(reference)]
    relative = 10*np.log10((local+eps)/(local.max()+eps))
    t = np.arange(len(reference))/FS
    calibration = (t >= interval[0]) & (t < interval[1])
    noise = (relative <= -35) & ~calibration
    speech = (relative >= -25) & ~calibration
    assert noise.any() and speech.any()
    return dict(
        ReferenceSNR_dB=10*np.log10((np.var(reference)+eps)/(np.var(processed-reference)+eps)),
        NonSpeechAttenuation_dB=10*np.log10((np.mean(original[noise]**2)+eps)/(np.mean(processed[noise]**2)+eps)),
        SpeechLevelChange_dB=10*np.log10((np.mean(processed[speech]**2)+eps)/(np.mean(original[speech]**2)+eps)),
        NoiseEvaluation_s=noise.sum()/FS,
        SpeechEvaluation_s=speech.sum()/FS,
    )


rows = []
checks = []
manifest = []
for wav in sorted((ROOT/"audio").glob("*.wav")):
    raw = wav.read_bytes()
    manifest.append({"file":wav.name,"bytes":len(raw),"sha256":hashlib.sha256(raw).hexdigest()})
for utterance in UTTERANCES:
    raw_reference = read_wav(ROOT/"audio"/(utterance+"r1_16.wav"))
    for environment in ENVIRONMENTS:
        raw_noisy = read_wav(ROOT/"audio"/(utterance+"_"+environment+"r1_16.wav"))
        n = min(len(raw_noisy),len(raw_reference))
        x, r = raw_noisy[:n], raw_reference[:n]
        interval = INTERVALS[utterance]
        identity, _ = enhance(x,interval,"identity")
        identity_error = np.linalg.norm(identity-x)/np.linalg.norm(x)
        fixed, _ = enhance(x,interval,"fixed")
        vad, update_fraction = enhance(x,interval,"vad")
        frozen_vad, _ = enhance(x,interval,"vad",threshold=-np.inf)
        control_error = np.max(np.abs(frozen_vad-fixed))
        assert identity_error < 1e-10 and control_error < 1e-12
        correlations = correlate(x,r,mode="full",method="fft")
        lags = correlation_lags(n,n)
        region = abs(lags)<200
        peak_lag = int(lags[region][np.argmax(correlations[region])])
        assert peak_lag == 0, "Dataset alignment requires investigation."
        base = metrics(r,x,x,interval)["ReferenceSNR_dB"]
        for method, y in (("original",x),("fixed",fixed),("vad",vad)):
            m = metrics(r,x,y,interval)
            rows.append(dict(Utterance=utterance,Environment=environment,Method=method,
                             ReferenceSNRGain_dB=m["ReferenceSNR_dB"]-base,
                             NoiseUpdateFraction=update_fraction if method=="vad" else 0,
                             **m))
        checks.append(dict(case=utterance+"_"+environment,
                           identity_relative_error=identity_error,
                           frozen_vad_vs_fixed_max_error=control_error,
                           correlation_peak_lag_samples=peak_lag,
                           original_noisy_samples=len(raw_noisy),
                           original_reference_samples=len(raw_reference),evaluated_samples=n))
with (OUT/"python_reference_metrics.csv").open("w",newline="",encoding="utf-8") as f:
    writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
with (OUT/"validation.json").open("w",encoding="utf-8") as f:
    json.dump(dict(execution_engine="Python reference implementation; NOT MATLAB",
                   python=platform.python_version(),numpy=np.__version__,scipy=scipy.__version__,
                   checks=checks,input_manifest=manifest),f,indent=2)

fig, axes = plt.subplots(1,2,figsize=(10,4.5),layout="constrained")
case_names=[c["case"] for c in checks]
positions=np.arange(len(case_names)); width=0.25
for k,(method,label,colour) in enumerate((("original","Unprocessed","#7b8795"),
                                         ("fixed","Fixed Wiener","#3477b6"),
                                         ("vad","VAD-guided Wiener","#c16b32"))):
    values=[r for r in rows if r["Method"]==method]
    for ax,key in zip(axes,("ReferenceSNR_dB","NonSpeechAttenuation_dB")):
        ax.bar(positions+(k-1)*width,[r[key] for r in values],width,label=label,color=colour)
for ax,heading in zip(axes,("Reference SNR (dB)","Non-speech attenuation proxy (dB)")):
    ax.set_ylabel(heading);ax.set_xticks(positions)
    ax.set_xticklabels([n.replace("_","\n") for n in case_names]);ax.grid(axis="y",alpha=0.2)
    ax.set_axisbelow(True)
axes[0].legend(fontsize=8)
fig.suptitle("Preliminary numerical check - Python reference, not MATLAB output",fontsize=11)
fig.savefig(OUT/"python_reference_summary.png",dpi=170)
plt.close(fig)
print(json.dumps({"checks":checks,"measurements":rows},indent=2))
