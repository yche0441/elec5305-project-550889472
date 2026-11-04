"""Independent post-execution check; does not call or alter MATLAB implementation."""
from pathlib import Path
import json, hashlib, datetime, warnings
import numpy as np
import pandas as pd
from scipy.io import loadmat, wavfile
from pystoi import stoi

ROOT=Path(__file__).resolve().parents[1]
OUT=Path(__file__).resolve().parent
methods=['unprocessed','fixed','vad_original','vad_selected','spp_default','spp_matched']
rows=pd.read_csv(ROOT/'matlab_metrics.csv')
assert len(rows)==1512 and rows.CaseID.nunique()==252
assert not rows.duplicated(['CaseID','Method']).any()
assert set(rows.Method)==set(methods)
assert rows.groupby('CaseID').size().eq(6).all()
assert rows.groupby('Cohort').CaseID.nunique().to_dict()=={'new_confirmation':216,'old_diagnostic':36}
assert rows[rows.Cohort.eq('new_confirmation')].Utterance.nunique()==18
assert rows[rows.Cohort.eq('new_confirmation')].groupby('Speaker').Utterance.nunique().eq(3).all()
assert np.isfinite(rows[['SNR_dB','PostSNR_dB']].to_numpy()).all()
trackcols=['LateTrackingBias_dB','LateMedianAbsTrackingError_dB','LateBandError_dB','LateSpectralNRMSE']
assert np.isfinite(rows[rows.Method.ne('unprocessed')][trackcols].to_numpy()).all()
lookup=rows.set_index(['CaseID','Method'])
manifest_counts={}
for f in ['INPUT_MANIFEST.json','EXECUTION_MANIFEST.json']:
 entries=json.loads((ROOT/f).read_text())
 for e in entries:
  assert hashlib.sha256((ROOT/e['path']).read_bytes()).hexdigest()==e['sha256'],e['path']
 manifest_counts[f]=len(entries)
ref=loadmat(ROOT/'regression_reference.mat',simplify_cells=True)['signals']
old={(s['Utterance'],s['Noise'],s['Profile']):s for s in ref}
max_snr=0.;max_late=0.;old_wave_error=0.;all_signals=[]
for p in sorted((ROOT/'signals').glob('*.mat')):
 blob=loadmat(p,simplify_cells=True)
 assert list(blob['methods'])==methods and blob['fs']==8000
 for s in blob['signals']:
  clean=s['clean'];inp=s['input'];noise=s['injectedNoise'];ys=s['outputs'];n=len(clean)
  assert ys.shape==(n,6) and np.isfinite(ys).all()
  assert np.array_equal(inp,ys[:,0]);assert np.allclose(clean+noise,inp,rtol=0,atol=0)
  change=800+(n-800)//2;post=change+400+800
  assert change+1==s['changeStart'] and post+1==s['postStart']
  source_path=ROOT/'data'/s['Noise']/f"{s['NominalSNR_dB']}dB"/f"{s['Utterance']}_{s['Noise']}_sn{s['NominalSNR_dB']}.wav"
  rate,raw=wavfile.read(source_path);source=raw.astype(float)/32768
  assert rate==8000 and len(source)==n
  if s['Profile']=='constant':assert np.array_equal(source,inp)
  gain=np.ones(n)
  if s['Profile']!='constant':
   db=6 if s['Profile']=='rise_6dB' else -6
   gain[change:change+400]=10**(np.linspace(0,db,400)/20)
   gain[change+400:]=10**(db/20)
  assert np.max(np.abs(noise-(source-clean)*gain))<2e-15
  assert np.array_equal(inp[:change],source[:change])
  score=10*np.log10(np.sum(clean[800:]**2)/np.sum((ys[800:]-clean[800:,None])**2,axis=0))
  late=10*np.log10(np.sum(clean[post:]**2)/np.sum((ys[post:]-clean[post:,None])**2,axis=0))
  for j,m in enumerate(methods):
   r=lookup.loc[(s['CaseID'],m)]
   assert r.Utterance==s['Utterance'] and r.Profile==s['Profile']
   max_snr=max(max_snr,abs(score[j]-r.SNR_dB));max_late=max(max_late,abs(late[j]-r.PostSNR_dB))
  if s['Cohort']=='old_diagnostic':
   prior=old[(s['Utterance'],s['Noise'],s['Profile'])]
   old_wave_error=max(old_wave_error,float(np.max(np.abs(ys[:,:4]-prior['outputs']))))
  all_signals.append(s)
assert len(all_signals)==252 and max_snr<1e-11 and max_late<1e-11 and old_wave_error==0

# Independently reconstruct known-noise periodograms, coarse-band sums and SPP states.
tr=loadmat(ROOT/'preselected_trace.mat',simplify_cells=True)
s=tr['traceSignal'];assert s['Utterance']=='sp03' and s['Noise']=='street' and s['Profile']=='rise_6dB'
win=.5-.5*np.cos(2*np.pi*np.arange(1,201)/201)
freq=np.fft.rfftfreq(400,1/8000)
weights=np.r_[1,np.full(199,2),1]
band_edges=[0,500,1000,2000,4001]
trace_results={};recurrence={}
for k,t in enumerate(tr['traceExample']):
 m=methods[k+1];starts=t['frameStartSample'].astype(int)-1;valid=t['valid'].astype(bool)
 late=valid&(starts>=s['postStart']-1)
 assert np.array_equal(valid,(starts>=800)&(starts+200<=len(s['clean'])))
 periods=np.stack([np.abs(np.fft.fft(s['injectedNoise'][b:b+200]*win,400))**2 for b in starts[valid]],axis=1)
 psd=t['noisePSDBefore'][:,valid];times=late[valid]
 bias=10*np.log10(psd[:,times].sum()/periods[:,times].sum())
 med=np.median(np.abs(10*np.log10(psd[:,times].sum(axis=0)/periods[:,times].sum(axis=0))))
 bands=[]
 for a,b in zip(band_edges[:-1],band_edges[1:]):
  mask=(freq>=a)&(freq<b)
  est=(psd[:201,times][mask,:]*weights[mask,None]).sum()
  target=(periods[:201,times][mask,:]*weights[mask,None]).sum()
  bands.append(10*np.log10(est/target))
 nrmse=np.linalg.norm(psd[:201,times].mean(axis=1)-periods[:201,times].mean(axis=1))/np.linalg.norm(periods[:201,times].mean(axis=1))
 r=lookup.loc[(s['CaseID'],m)]
 vals=[bias,med,np.mean(np.abs(bands)),*bands,nrmse]
 cols=['LateTrackingBias_dB','LateMedianAbsTrackingError_dB','LateBandError_dB','Band0_500Bias_dB','Band500_1000Bias_dB','Band1000_2000Bias_dB','Band2000_4000Bias_dB','LateSpectralNRMSE']
 errs={c:abs(float(v)-r[c]) for c,v in zip(cols,vals)}
 assert max(errs.values())<1e-11
 trace_results[m]={'band_bias_dB':bands,'band_error_dB':float(np.mean(np.abs(bands))),'max_csv_disagreement':max(errs.values()),'late_frames':int(late.sum())}
 assert np.all(t['meanUpdateWeight'][~valid]==0)
 assert np.array_equal(t['noisePSDBefore'][:,~valid],t['noisePSDAfter'][:,~valid])
 if m.startswith('spp'):
  D=t['initialPSD'].copy();pbar=np.full(400,.5);alpha=.8 if m=='spp_default' else .95
  xi=10**1.5;floor=max(np.finfo(float).tiny,1e-12*D.mean())
  padded=np.r_[np.zeros(200),s['input'],np.zeros(400)]
  errs={'psd_relative_l2':0.,'probability_abs':0.,'weight_abs':0.,'mean_state_abs':0.,'periodogram_relative_l2':0.}
  cap_equal=True
  for j,b in enumerate(starts):
   assert np.array_equal(t['sppStateBefore'][:,j],t['sppStateAfter'][:,j]) if not valid[j] else True
   before_err=np.linalg.norm(D-t['noisePSDBefore'][:,j])/np.linalg.norm(t['noisePSDBefore'][:,j]);errs['psd_relative_l2']=max(errs['psd_relative_l2'],before_err)
   if valid[j]:
    power=np.abs(np.fft.fft(s['input'][b:b+200]*win,400))**2
    errs['periodogram_relative_l2']=max(errs['periodogram_relative_l2'],np.linalg.norm(power-t['noisyPeriodogram'][:,j])/np.linalg.norm(power))
    log_odds=np.minimum(-np.log1p(xi)+(xi/(1+xi))*power/D,200.)
    p=1/(1+np.exp(-log_odds))
    pbar=.9*pbar+.1*p
    cap=pbar>.99
    pc=np.where(cap,np.minimum(p,.99),p)
    w=(1-alpha)*(1-pc)
    D=np.maximum(D+w*(power-D),floor)
    errs['probability_abs']=max(errs['probability_abs'],float(np.max(np.abs(pc-t['sppAfterCap'][:,j]))))
    errs['weight_abs']=max(errs['weight_abs'],float(np.max(np.abs(w-t['updateWeight'][:,j]))))
    errs['mean_state_abs']=max(errs['mean_state_abs'],float(np.max(np.abs(pbar-t['sppStateAfter'][:,j]))))
    cap_equal=cap_equal and np.array_equal(cap,t['sppCapActive'][:,j])
   errs['psd_relative_l2']=max(errs['psd_relative_l2'],np.linalg.norm(D-t['noisePSDAfter'][:,j])/np.linalg.norm(t['noisePSDAfter'][:,j]))
  assert max(errs.values())<1e-10 and cap_equal
  recurrence[m]={**{k:float(v) for k,v in errs.items()},'cap_decisions_exact':bool(cap_equal),'frames':len(starts),'valid_frames':int(valid.sum())}

# Original archived SNR cross-check without relying on the runner's assertions.
reg=pd.read_csv(ROOT/'regression_metrics.csv')
oldrows=rows[rows.Cohort.eq('old_diagnostic')&rows.Method.isin(methods[:4])]
keys=['Utterance','Noise','Profile','Method']
joined=oldrows.merge(reg,on=keys,suffixes=('_new','_prior'),validate='one_to_one')
assert len(joined)==144
regdiff=float(np.max(np.abs(joined['SNR_dB_new']-joined['SNR_dB_prior'])))
assert regdiff<1e-11

stoi_results=[]
metrics_path=ROOT/'metrics.csv'
if metrics_path.exists():
 scored=pd.read_csv(metrics_path).set_index(['CaseID','Method'])
 chosen=[s for s in all_signals if (s['Utterance']=='sp03' and s['Noise']=='street' and s['Profile']=='rise_6dB') or (s['Utterance']=='sp02' and s['Noise']=='street' and s['Profile']=='fall_6dB')]
 assert len(chosen)==2
 for s in chosen:
  for j,m in enumerate(methods):
   with warnings.catch_warnings(record=True) as caught:
    warnings.simplefilter('always');v=stoi(s['clean'][800:],s['outputs'][800:,j],8000,extended=False)
   expected=float(scored.loc[(s['CaseID'],m),'STOI']);err=abs(v-expected)
   assert err<1e-12 and not caught
   stoi_results.append({'case':int(s['CaseID']),'utterance':s['Utterance'],'profile':s['Profile'],'method':m,'value':v,'abs_difference':err,'warnings':len(caught)})

result={'completed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'PASS','input_cases':252,'methods_per_case':6,'metric_rows':1512,'cohort_input_counts':rows.groupby('Cohort').CaseID.nunique().to_dict(),'unseen_sentences':18,'known_speakers':6,'all_output_arrays_finite':True,'all_primary_scores_and_defined_tracking_metrics_finite':True,'manifest_checks':manifest_counts,'all_snr_max_abs_difference_dB':max_snr,'all_post_snr_max_abs_difference_dB':max_late,'old36_baseline_waveforms_max_abs_difference':old_wave_error,'old144_method_snr_max_abs_difference_dB':regdiff,'preselected_band_checks':trace_results,'independent_spp_recurrence_checks':recurrence,'stoi_sample_checks':stoi_results,'stoi_pending':not metrics_path.exists(),'limits':['New sentences share previously observed speakers.','Late band-power error uses coarse sums against finite-window realized noise; not expected PSD truth.','Adaptation or tracking improvement does not alone establish perceptual or intelligibility gain.','Old diagnostic rows are not included in new confirmation inference.']}
(OUT/'INDEPENDENT_RESULT_AUDIT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
