from pathlib import Path
import json,datetime
import numpy as np
import pandas as pd
r=Path(__file__).resolve().parents[1];out=Path(__file__).resolve().parent
m=pd.read_csv(r/'metrics.csv')
cols=['SNR_dB','STOI','PostSNR_dB','LateBandError_dB','LateSpectralNRMSE','LateTrackingBias_dB','LateMedianAbsTrackingError_dB','MeanUpdateWeight','LateMeanUpdateWeight','SpeechProxyMeanWeight','LowEnergyProxyMeanWeight']
sets={'new_constant_benchmark':m.query("Cohort=='new_confirmation' and Profile=='constant'"),'new_controlled_10dB':m.query("Cohort=='new_confirmation' and NominalSNR_dB==10"),'old_diagnostic_10dB':m.query("Cohort=='old_diagnostic'")}
provided_sentence=pd.read_csv(r/'sentence_means.csv').set_index(['AnalysisSet','Utterance','Speaker','Profile','Method'])
provided_speaker=pd.read_csv(r/'speaker_means.csv').set_index(['AnalysisSet','Speaker','Profile','Method'])
provided_paired=pd.read_csv(r/'speaker_paired_contrasts.csv').set_index(['AnalysisSet','Speaker','Profile','Contrast'])
max_sent=max_sp=max_paired=0.;headline=[]
for name,data in sets.items():
 for (u,speaker,profile,method),g in data.groupby(['Utterance','Speaker','Profile','Method']):
  actual=g[cols].mean();saved=provided_sentence.loc[(name,u,speaker,profile,method),cols]
  max_sent=max(max_sent,float(np.nanmax(np.abs(actual.to_numpy()-saved.to_numpy(dtype=float)))))
 for (speaker,profile,method),g in data.groupby(['Speaker','Profile','Method']):
  actual=g.groupby('Utterance')[cols].mean().mean();saved=provided_speaker.loc[(name,speaker,profile,method),cols]
  max_sp=max(max_sp,float(np.nanmax(np.abs(actual.to_numpy()-saved.to_numpy(dtype=float)))))
 for a,b in [('spp_default','vad_selected'),('spp_default','fixed'),('spp_matched','vad_selected'),('spp_default','spp_matched')]:
  aa=data[data.Method.eq(a)].set_index(['CaseID','Utterance','Speaker','Profile']);bb=data[data.Method.eq(b)].set_index(['CaseID','Utterance','Speaker','Profile'])
  diff=aa[cols]-bb[cols]
  sentence=diff.groupby(['Utterance','Speaker','Profile']).mean()
  speaker=sentence.groupby(['Speaker','Profile']).mean()
  for (sp,profile),g in speaker.iterrows():
   saved=provided_paired.loc[(name,sp,profile,a+' minus '+b),cols]
   max_paired=max(max_paired,float(np.nanmax(np.abs(g.to_numpy()-saved.to_numpy(dtype=float)))))
  if name.startswith('new') and a=='spp_default' and b in ['vad_selected','fixed']:
   for profile,g in speaker.groupby('Profile'):
    sg=sentence[ sentence.index.get_level_values('Profile')==profile]
    cg=diff[diff.index.get_level_values('Profile')==profile]
    h={'set':name,'profile':profile,'contrast':a+' minus '+b,'means':g[['LateBandError_dB','SNR_dB','STOI','PostSNR_dB']].mean().to_dict(),'speaker_count':len(g),'sentence_count':len(sg),'case_count':len(cg)}
    for metric,direction in [('LateBandError_dB',-1),('SNR_dB',1),('STOI',1)]:h[metric+'_improved']={'speaker':int((direction*g[metric]>0).sum()),'sentence':int((direction*sg[metric]>0).sum()),'case':int((direction*cg[metric]>0).sum())}
    headline.append(h)
assert max(max_sent,max_sp,max_paired)<1e-11
result={'completed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'PASS','sentence_mean_max_abs_error':max_sent,'speaker_mean_max_abs_error':max_sp,'speaker_paired_contrast_max_abs_error':max_paired,'headlines':headline}
(out/'INDEPENDENT_AGGREGATE_AUDIT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
