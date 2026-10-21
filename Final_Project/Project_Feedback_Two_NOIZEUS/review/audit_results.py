from pathlib import Path
import hashlib,json,zipfile
from io import BytesIO
import numpy as np
import pandas as pd
from scipy.io import loadmat,wavfile

BASE=Path(__file__).resolve().parents[1]
R=BASE/'results/run_20260913_120452'
P=BASE
archive=zipfile.ZipFile(BASE/'evidence/NOIZEUS_Results_20260913_120452.zip')
mat=loadmat(BytesIO(archive.read('results/run_20260913_120452/experiment_results.mat')),variable_names=['cfg','metadata','verification','signals'],simplify_cells=True)
metrics=pd.read_csv(R/'metrics.csv')
cases=pd.read_csv(R/'dataset_diagnostics.csv')
paired=pd.read_csv(R/'paired_comparisons.csv')
summary=pd.read_csv(R/'condition_summary.csv')
assert len(metrics)==144 and len(cases)==48 and len(paired)==48 and len(mat['signals'])==48
assert not metrics.duplicated(['CaseID','Method']).any()
assert np.isfinite(metrics.STOI).all() and metrics.STOI.between(-1,1).all()
assert mat['metadata']['ImplementationRevision']=='2026-09-13-r1'
assert mat['metadata']['FullMetricsComplete']==1 and mat['verification']['Passed']==1
assert archive.read('results/run_20260913_120452/experiment_config.m')==(P/'experiment_config.m').read_bytes()
lookup=metrics.set_index(['CaseID','Method'])
max_snr_error=0.; max_proxy_error=0.; max_noise_spread_error=0.; max_psd_error=0.
max_wave_error=0.; activity_counts={k:[0,0] for k in ['car','street']}
examples=[]
for entry in mat['signals']:
    key=entry['CaseID'];uid,noise,snr=key.split('_');nominal=int(snr[:-2])
    clean=entry['clean']; noisy=entry['noisy']
    fs,c=wavfile.read(P/f'data/clean/{uid}.wav')
    fs2,y=wavfile.read(P/f'data/{noise}/{snr}/{uid}_{noise}_sn{nominal}.wav')
    assert fs==fs2==entry['fs']==8000
    assert np.array_equal(clean,c.astype(float)/32768) and np.array_equal(noisy,y.astype(float)/32768)
    ix=slice(800,None)
    def snr_db(z):return 10*np.log10(np.sum(clean[ix]**2)/np.sum((z[ix]-clean[ix])**2))
    measured_input=snr_db(noisy)
    for method,signal in [('unprocessed',noisy),('fixed',entry['fixed']),('vad',entry['vad'])]:
        assert signal.shape==clean.shape and np.isfinite(signal).all()
        row=lookup.loc[(key,method)]
        calculated=snr_db(signal)
        max_snr_error=max(max_snr_error,abs(calculated-row.OutputSNR_dB),abs(measured_input-row.InputSNR_dB),abs(calculated-measured_input-row.SNRImprovement_dB))
    fixed=entry['fixedTrace'];vad=entry['vadTrace']
    assert np.array_equal(fixed['initialPSD'],vad['initialPSD'])
    assert np.array_equal(fixed['initialPSD'],fixed['finalPSD']) and not np.any(fixed['noiseUpdated'])
    start=vad['frameStartSample'].astype(int)-1
    valid=(start>=800)&(start+200<=len(clean))
    assert np.array_equal(valid,vad['valid'].astype(bool))
    updates=vad['noiseUpdated'].astype(bool)
    speech=vad['speechDecision'].astype(bool)
    assert np.array_equal(updates,valid & ~speech)
    clean_db=np.full(len(start),np.nan);residual_db=np.full(len(start),np.nan)
    for k in np.flatnonzero(valid):
        sl=slice(start[k],start[k]+200)
        clean_db[k]=10*np.log10(max(np.mean(clean[sl]**2),np.finfo(float).tiny))
        residual_db[k]=10*np.log10(max(np.mean((noisy[sl]-clean[sl])**2),np.finfo(float).tiny))
    rel=clean_db-np.nanmax(clean_db)
    speech_proxy=valid & (rel>=-30); silence_proxy=valid & (rel<=-40)
    def fraction(a,b):return float(np.sum(a&b)/np.sum(b)) if np.any(b) else np.nan
    for trace,method in [(fixed,'fixed'),(vad,'vad')]:
        row=lookup.loc[(key,method)]
        decisions=trace['speechDecision'].astype(bool);changed=trace['noiseUpdated'].astype(bool)
        for col,value in {
            'ProxySpeechMissFraction':fraction(~decisions,speech_proxy),
            'ProxyNonSpeechFalseAlarmFraction':fraction(decisions,silence_proxy),
            'UpdateOnSpeechProxyFraction':fraction(changed,speech_proxy),
            'NoiseUpdateFraction':fraction(changed,valid)}.items():
            if np.isfinite(value):max_proxy_error=max(max_proxy_error,abs(row[col]-value))
    spread=float(np.percentile(residual_db[valid],90)-np.percentile(residual_db[valid],10))
    row=cases[cases.CaseID==key].iloc[0]
    max_noise_spread_error=max(max_noise_spread_error,abs(spread-row.NoiseVariation_dB))
    # Independently replay only the stored noise-update sequence, not enhancement.
    d=vad['initialPSD'].copy();window=.5-.5*np.cos(2*np.pi*np.arange(1,201)/201)
    floor=max(np.finfo(float).tiny,1e-12*np.mean(d))
    for k in np.flatnonzero(updates):
        power=np.abs(np.fft.fft(noisy[start[k]:start[k]+200]*window,400))**2
        d=np.maximum(.95*d+.05*power,floor)
    max_psd_error=max(max_psd_error,float(np.linalg.norm(d-vad['finalPSD'])/np.linalg.norm(d)))
    if row.Split=='evaluation':
        activity_counts[noise][0]+=int(np.sum(updates&speech_proxy))
        activity_counts[noise][1]+=int(np.sum(speech_proxy))
    if uid=='sp06' and nominal==5:
        example={'case':key,'updated_speech_proxy_frames':int(np.sum(updates&speech_proxy)),
                 'speech_proxy_frames':int(np.sum(speech_proxy)),
                 'times_s':vad['time_s'][updates&speech_proxy].tolist()}
        examples.append(example)
        for tag,signal in [('clean',clean),('unprocessed',noisy),('fixed',entry['fixed']),('vad',entry['vad'])]:
            wav_fs,w=wavfile.read(R/f'listening/{key}_{tag}.wav')
            assert wav_fs==8000 and w.dtype==np.int32
            max_wave_error=max(max_wave_error,float(np.max(np.abs(w.astype(float)/2**31-signal))))

assert max_snr_error<1e-9 and max_proxy_error<1e-12 and max_noise_spread_error<1e-9 and max_psd_error<1e-12
assert max_wave_error<2**-23
wide=metrics.pivot(index='CaseID',columns='Method',values=['OutputSNR_dB','STOI'])
pp=paired.set_index('CaseID')
for column,source in [('VADminusFixedSNR_dB','OutputSNR_dB'),('VADminusFixedSTOI','STOI')]:
    expected=wide[(source,'vad')]-wide[(source,'fixed')]
    assert np.max(np.abs(pp[column]-expected))<1e-9
grouped=metrics.groupby(['Split','Noise','NominalSNR_dB','Method'])
for _,r in summary.iterrows():
    group=grouped.get_group((r.Split,r.Noise,r.NominalSNR_dB,r.Method))
    assert r.N==len(group)
    for col,source in [('MeanInputSNR_dB','InputSNR_dB'),('MeanOutputSNR_dB','OutputSNR_dB'),('MeanSNRImprovement_dB','SNRImprovement_dB'),('MeanSTOI','STOI')]:
        assert abs(r[col]-group[source].mean())<1e-9

ev=metrics[metrics.Split=='evaluation']
means=ev.groupby(['Noise','Method'])[['InputSNR_dB','OutputSNR_dB','SNRImprovement_dB','STOI','ProxySpeechMissFraction','UpdateOnSpeechProxyFraction']].mean().reset_index()
effects=paired[paired.Split=='evaluation']
rows=[]
for noise in ['car','street']:
    g=effects[effects.Noise==noise]
    rows.append({'noise':noise,'n':len(g),'mean_SNR_VAD_minus_fixed_dB':float(g.VADminusFixedSNR_dB.mean()),
                 'mean_STOI_VAD_minus_fixed':float(g.VADminusFixedSTOI.mean()),
                 'SNR_wins':int(np.sum(g.VADminusFixedSNR_dB>0)),
                 'STOI_wins':int(np.sum(g.VADminusFixedSTOI>0)),
                 'both_wins':int(np.sum((g.VADminusFixedSNR_dB>0)&(g.VADminusFixedSTOI>0))),
                 'updated_speech_proxy_frames':activity_counts[noise][0],
                 'speech_proxy_frames':activity_counts[noise][1]})
report={'status':'PASS','source_archive':'NOIZEUS_Results_20260913_120452.zip',
        'source_sha256':hashlib.sha256((BASE/'evidence/NOIZEUS_Results_20260913_120452.zip').read_bytes()).hexdigest(),
        'runtime':'Independent Python review of saved native MATLAB results',
        'native_MATLAB_version':mat['metadata']['MATLABVersion'],
        'implementation_revision':mat['metadata']['ImplementationRevision'],
        'input_cases':48,'metric_rows':144,'finite_native_STOI_rows':144,
        'max_recomputed_SNR_difference_dB':max_snr_error,
        'max_recomputed_proxy_fraction_difference':max_proxy_error,
        'max_recomputed_noise_spread_difference_dB':max_noise_spread_error,
        'max_noise_update_replay_relative_error':max_psd_error,
        'max_listening_PCM24_error':max_wave_error,
        'native_verification':mat['verification'],
        'STOI_independently_recomputed':False,
        'STOI_check_scope':'Native completion, range, same-pair call signature and aggregate consistency',
        'listening_review_performed':False,
        'evaluation_effects':rows,'preselected_examples':examples}
(Path(__file__).resolve().parent/'CHECKED_RESULTS_RECOMPUTED.json').write_text(json.dumps(report,indent=2)+'\n')
means.to_json(Path(__file__).resolve().parent/'evaluation_means_recomputed.json',orient='records',indent=2)
print(json.dumps({k:v for k,v in report.items() if k not in ['preselected_examples','native_verification']},indent=2))
print('Preselected example error-frame counts:',[(r['case'],r['updated_speech_proxy_frames'],r['speech_proxy_frames']) for r in examples])
