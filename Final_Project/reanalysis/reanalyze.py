#!/usr/bin/env python3
"""Reproduce report tables from unchanged waveform evidence and frozen CSVs.

Requires numpy, scipy, pystoi==0.4.1. This does not rerun enhancement or tune
parameters. It reads the original ZIP directly without extracting/altering it.
Default layout: this script in PACKAGE/reanalysis/reanalyze.py, with sibling
Project_Feedback_Two_NOIZEUS/ and Final_Project_Study/ in PACKAGE.
"""
from pathlib import Path
import argparse
import csv
import hashlib
import io
import json
import platform
import zipfile
from datetime import datetime, timezone
from importlib.metadata import version
import numpy as np
from scipy.io import loadmat
from pystoi import stoi


def read_csv(path):
    with Path(path).open(newline='', encoding='utf-8-sig') as f:
        return list(csv.DictReader(f))


def write_csv(path, rows):
    assert rows, f'No rows for {path}'
    with Path(path).open('w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def mean(rows, key):
    return float(np.mean([float(r[key]) for r in rows]))


def sha256(raw):
    return hashlib.sha256(raw).hexdigest()


def display_path(path, root):
    try:
        return str(path.resolve().relative_to(root.resolve()))
    except ValueError:
        return str(path.resolve())


def aggregate(rows):
    return dict(Cases=len(rows), SNR_dB=mean(rows, 'SNR_dB'), STOI=mean(rows, 'STOI'),
                ProxyOverlap=sum(int(r['SpeechProxyUpdates']) for r in rows) /
                sum(int(r['SpeechProxyFrames']) for r in rows),
                UpdateFraction=mean(rows, 'UpdateFraction'))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--package-root', type=Path, default=Path(__file__).resolve().parent.parent)
    ap.add_argument('--original-project', type=Path)
    ap.add_argument('--study-root', type=Path)
    ap.add_argument('--output', type=Path)
    args = ap.parse_args()
    root = args.package_root.resolve()
    original = (args.original_project or root/'Project_Feedback_Two_NOIZEUS').resolve()
    study = (args.study_root or root/'Final_Project_Study').resolve()
    out = (args.output or Path(__file__).resolve().parent/'results_recomputed').resolve()
    out.mkdir(parents=True, exist_ok=True)
    evidence = original/'evidence/NOIZEUS_Results_20260913_120452.zip'
    raw = evidence.read_bytes()
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        assert z.testzip() is None, 'Original ZIP CRC check failed'
        mat_names = [n for n in z.namelist() if n.endswith('/experiment_results.mat')]
        csv_names = [n for n in z.namelist() if n.endswith('/metrics.csv')]
        assert len(mat_names) == len(csv_names) == 1, 'Ambiguous original evidence'
        mat_bytes = z.read(mat_names[0])
        archived = list(csv.DictReader(io.StringIO(z.read(csv_names[0]).decode('utf-8-sig'))))
    saved = loadmat(io.BytesIO(mat_bytes), simplify_cells=True)
    source = {(r['CaseID'], r['Method']): r for r in archived}
    assert len(saved['signals']) == 48 and len(source) == 144
    assert version('pystoi') == '0.4.1', 'Use the report-pinned pystoi 0.4.1'
    rescored, validation, paired = [], [], []
    for i, signal in enumerate(saved['signals']):
        fs = int(signal['fs'])
        assert fs == 8000, 'The frozen protocol uses 8 kHz'
        ref = np.asarray(signal['clean'], dtype=np.float64).reshape(-1)[800:]
        assert np.all(np.isfinite(ref)) and len(ref) > 0
        for method, field in [('unprocessed', 'noisy'), ('fixed', 'fixed'), ('vad', 'vad')]:
            y = np.asarray(signal[field], dtype=np.float64).reshape(-1)[800:]
            assert y.shape == ref.shape and np.all(np.isfinite(y))
            r = dict(source[(signal['CaseID'], method)])
            score = float(stoi(ref, y, fs, extended=False))
            snr = float(10*np.log10(np.dot(ref, ref)/np.dot(y-ref, y-ref)))
            assert np.isfinite(score) and np.isfinite(snr)
            assert abs(snr-float(r['OutputSNR_dB'])) < 1e-10, 'Archived SNR does not match waveform'
            baseline = float(r['STOI'])
            validation.append(dict(CaseID=signal['CaseID'], Method=method,
                                   NativeMATLABSTOI=baseline, PySTOI=score,
                                   Difference=score-baseline, AbsoluteDifference=abs(score-baseline)))
            r.update(STOI=score, OutputSNR_dB=snr, NativeMATLABSTOI=baseline,
                     STOIImplementation='pystoi 0.4.1 extended=False')
            rescored.append(r)
        if (i+1) % 12 == 0:
            print(f'Rescored {i+1}/48 cases ({3*(i+1)} method scores)', flush=True)
    fresh = {(r['CaseID'], r['Method']): r for r in rescored}
    for case_id in sorted({r['CaseID'] for r in rescored}):
        v, f = fresh[(case_id, 'vad')], fresh[(case_id, 'fixed')]
        pd = v['STOI']-f['STOI']
        nd = v['NativeMATLABSTOI']-f['NativeMATLABSTOI']
        paired.append(dict(CaseID=case_id, Split=v['Split'], Noise=v['Noise'],
                           VADminusFixedSNR_dB=v['OutputSNR_dB']-f['OutputSNR_dB'],
                           VADminusFixedSTOI=pd, NativeVADminusFixedSTOI=nd,
                           PairedImplementationDifference=pd-nd))
    evaluation = [r for r in rescored if r['Split'] == 'evaluation']
    summary = []
    for noise in ['car', 'street']:
        for method in ['unprocessed', 'fixed', 'vad']:
            rows = [r for r in evaluation if r['Noise'] == noise and r['Method'] == method]
            summary.append(dict(Noise=noise, Method=method, Cases=len(rows),
                                SNR_dB=mean(rows, 'OutputSNR_dB'), STOI=mean(rows, 'STOI')))
    ep = [r for r in paired if r['Split'] == 'evaluation']
    evaluation_counts = dict(Cases=len(ep), SNRBetter=sum(r['VADminusFixedSNR_dB'] > 0 for r in ep),
                             STOIBetter=sum(r['VADminusFixedSTOI'] > 0 for r in ep),
                             BothBetter=sum(r['VADminusFixedSNR_dB'] > 0 and r['VADminusFixedSTOI'] > 0 for r in ep))
    dev = read_csv(study/'development_metrics.csv')
    new = read_csv(study/'new_test_metrics.csv')
    assert len(dev) == 144 and len(new) == 192
    grid = []
    for th in [1, 3, 5]:
        for hang in [0, 5, 10]:
            rr = [r for r in dev if int(r['Threshold_dB']) == th and int(r['HangoverFrames']) == hang]
            assert len(rr) == 16
            grid.append(dict(Threshold_dB=th, HangoverFrames=hang, **aggregate(rr)))
    new_summary = [dict(Method=m, **aggregate([r for r in new if r['Method'] == m]))
                   for m in ['unprocessed', 'fixed', 'vad_original', 'vad_selected']]
    lut = {(r['Utterance'], r['Noise'], r['NominalSNR_dB'], r['Method']): r for r in new}
    assert len(lut) == 192
    case_deltas = []
    for r in new:
        if r['Method'] != 'vad_selected':
            continue
        for base in ['fixed', 'vad_original']:
            b = lut[(r['Utterance'], r['Noise'], r['NominalSNR_dB'], base)]
            case_deltas.append(dict(Comparison='selected_minus_'+base, Utterance=r['Utterance'],
                                    Noise=r['Noise'], NominalSNR_dB=int(r['NominalSNR_dB']),
                                    SNR_dB=float(r['SNR_dB'])-float(b['SNR_dB']),
                                    STOI=float(r['STOI'])-float(b['STOI'])))
    sentences, sensitivity, conditions = [], [], []
    for base in ['fixed', 'vad_original']:
        comparison = 'selected_minus_'+base
        rr = [r for r in case_deltas if r['Comparison'] == comparison]
        for u in sorted({r['Utterance'] for r in rr}):
            ur = [r for r in rr if r['Utterance'] == u]
            assert len(ur) == 8
            sentences.append(dict(Comparison=comparison, Utterance=u, Conditions=len(ur),
                                  SNR_dB=mean(ur, 'SNR_dB'), STOI=mean(ur, 'STOI')))
        sr = [r for r in sentences if r['Comparison'] == comparison]
        for k in ['STOI', 'SNR_dB']:
            a = np.array([r[k] for r in sr])
            loo = [float(np.mean(np.delete(a, i))) for i in range(len(a))]
            sensitivity.append(dict(Comparison=comparison, Metric=k, Sentences=len(a), Mean=float(a.mean()),
                                    SentenceMin=float(a.min()), SentenceMax=float(a.max()),
                                    PositiveSentences=int(np.sum(a > 0)),
                                    LeaveOneSentenceOutMin=min(loo), LeaveOneSentenceOutMax=max(loo)))
        for noise in ['car', 'street']:
            for snr in [0, 5, 10, 15]:
                cr = [r for r in rr if r['Noise'] == noise and r['NominalSNR_dB'] == snr]
                assert len(cr) == 6
                conditions.append(dict(Comparison=comparison, Noise=noise, NominalSNR_dB=snr,
                                       Sentences=len(cr), SNR_dB=mean(cr, 'SNR_dB'), STOI=mean(cr, 'STOI'),
                                       BothBetter=sum(r['SNR_dB'] > 0 and r['STOI'] > 0 for r in cr)))
    reference = study/'validation/pystoi_vs_native_rows.csv'
    reference_check = dict(status='not_available')
    if reference.exists():
        prior = {(r['CaseID'], r['Method']): r for r in read_csv(reference)}
        assert set(prior) == set(fresh)
        maxdiff = max(abs(r['PySTOI']-float(prior[(r['CaseID'], r['Method'])]['PySTOI'])) for r in validation)
        assert maxdiff < 1e-10, 'Fresh STOI differs from saved validation'
        reference_check = dict(status='PASS', MaxAbsoluteDifference=maxdiff, Rows=len(prior),
                               SHA256=sha256(reference.read_bytes()))
    for name, rows in [('v1_rescored_metrics.csv', rescored), ('pystoi_vs_native_rows.csv', validation),
                       ('v1_paired_comparisons.csv', paired), ('v1_evaluation_summary.csv', summary),
                       ('development_summary_recomputed.csv', grid), ('new_test_summary.csv', new_summary),
                       ('new_test_case_deltas.csv', case_deltas), ('new_test_sentence_deltas.csv', sentences),
                       ('new_test_sentence_sensitivity.csv', sensitivity), ('new_test_condition_deltas.csv', conditions)]:
        write_csv(out/name, rows)
    record = dict(Status='PASS', CreatedUTC=datetime.now(timezone.utc).isoformat(),
                  Scope='Fresh scoring of archived unquantized v1 waveforms; arithmetic reanalysis of frozen extension CSVs; no enhancement rerun or parameter retuning',
                  Dependencies={k: version(k) for k in ['numpy', 'scipy', 'pystoi']}, Python=platform.python_version(),
                  ScoreInterval='MATLAB samples 801:end; Python [800:]', STOICall='stoi(clean, processed, 8000, extended=False)',
                  EvidenceArchive=display_path(evidence, root), EvidenceSHA256=sha256(raw),
                  EvidenceMATMember=mat_names[0], EvidenceMATSHA256=sha256(mat_bytes),
                  FrozenInputSHA256={name: sha256((study/name).read_bytes()) for name in ['development_metrics.csv', 'new_test_metrics.csv']},
                  RescoredMethodCases=len(rescored), V1EvaluationCounts=evaluation_counts,
                  V1EvaluationSummary=summary, ExistingSTOIValidation=reference_check,
                  NativeImplementationSensitivity=dict(MeanAbsoluteScoreDifference=mean(validation, 'AbsoluteDifference'),
                  MaxAbsoluteScoreDifference=max(r['AbsoluteDifference'] for r in validation),
                  MaxAbsolutePairedDifference=max(abs(r['PairedImplementationDifference']) for r in paired),
                  PairedDirectionChanges=sum(np.sign(r['VADminusFixedSTOI']) != np.sign(r['NativeVADminusFixedSTOI']) for r in paired)),
                  SentenceSensitivity=sensitivity,
                  SensitivityInterpretation='Descriptive leave-one-sentence-out sensitivity; not a confidence interval or significance test. Same six sentences recur across eight conditions.')
    # Convert any numpy scalar counters before serialising.
    record['NativeImplementationSensitivity']['PairedDirectionChanges'] = int(record['NativeImplementationSensitivity']['PairedDirectionChanges'])
    (out/'REANALYSIS.json').write_text(json.dumps(record, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(dict(Status='PASS', RescoredMethodCases=len(rescored),
                         ExistingSTOIValidation=reference_check, V1EvaluationCounts=evaluation_counts), indent=2))


if __name__ == '__main__':
    main()
