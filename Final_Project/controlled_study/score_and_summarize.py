"""Score unquantized MATLAB outputs and summarize the preregistered contrasts."""
from pathlib import Path
import json, hashlib, warnings, platform, datetime
import numpy as np
import pandas as pd
import scipy
from scipy.io import loadmat
import pystoi
from pystoi import stoi
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parent
PROFILES=['constant','rise_6dB','fall_6dB']
METHODS=['unprocessed','fixed','vad_original','vad_selected']
LABELS={'unprocessed':'Unprocessed','fixed':'Fixed','vad_original':'Original VAD','vad_selected':'Selected VAD'}
COLORS={'fixed':'#4C566A','vad_original':'#C26B26','vad_selected':'#2176AE'}

def desc(values):
    a=np.asarray(values,dtype=float)
    return dict(n=int(len(a)),mean=float(a.mean()),sd=float(a.std(ddof=1)),minimum=float(a.min()),maximum=float(a.max()))

def main():
    manifest=json.loads((ROOT/'INPUT_AND_CORE_MANIFEST.json').read_text())
    for item in manifest:
        assert hashlib.sha256((ROOT/item['path']).read_bytes()).hexdigest()==item['sha256'],item['path']
    assert hashlib.sha256((ROOT/'PROTOCOL.json').read_bytes()).hexdigest()==(ROOT/'PROTOCOL_SHA256.txt').read_text().split()[0]
    data=loadmat(ROOT/'unquantized_signals.mat',simplify_cells=True)
    sigs=data['signals'];fs=int(data['fs']);assert fs==8000 and len(sigs)==36
    metrics=pd.read_csv(ROOT/'matlab_metrics.csv'); scores=[];recomputed=[]
    traces=pd.read_csv(ROOT/'frame_diagnostics.csv')
    tracking_errors=[];recurrence_errors=[]
    for i,s in enumerate(sigs,1):
        clean=np.asarray(s['clean']);outs=np.asarray(s['outputs']);ref=clean[800:]
        assert outs.shape==(len(clean),4) and np.isfinite(outs).all()
        assert np.array_equal(outs[:,0],s['input'])
        for mi,method in enumerate(METHODS):
            with warnings.catch_warnings(record=True) as ws:
                score=stoi(ref,outs[800:,mi],fs,extended=False)
            assert not ws, [str(w.message) for w in ws]
            assert np.isfinite(score)
            row=metrics[(metrics.CaseID==i)&(metrics.Method==method)].iloc[0]
            snr=10*np.log10(np.sum(ref**2)/np.sum((outs[800:,mi]-ref)**2))
            assert abs(snr-row.SNR_dB)<1e-11
            post=int(s['postStart'])-1
            post_snr=10*np.log10(np.sum(clean[post:]**2)/np.sum((outs[post:,mi]-clean[post:])**2))
            assert abs(post_snr-row.PostSNR_dB)<1e-11
            scores.append(float(score));recomputed.append(abs(snr-row.SNR_dB))
        # Independent NumPy FFT check of the actual injected-noise diagnostic.
        base=traces[(traces.CaseID==i)&(traces.Method=='fixed')]
        idx=base.FrameStartSample.to_numpy(dtype=int)[:,None]-1+np.arange(200)[None,:]
        win=.5-.5*np.cos(2*np.pi*np.arange(1,201)/201)
        p=np.sum(np.abs(np.fft.fft(np.asarray(s['injectedNoise'])[idx]*win,400,axis=1))**2,axis=1)
        rel=np.max(np.abs(p-base.InjectedFramePower.to_numpy())/np.maximum(p,1e-300))
        assert rel<1e-12;tracking_errors.append(float(rel))
        inputpower=np.sum(np.abs(np.fft.fft(np.asarray(s['input'])[idx]*win,400,axis=1))**2,axis=1)
        for method in METHODS[1:]:
            t=traces[(traces.CaseID==i)&(traces.Method==method)]
            estimate=t.EstimateBeforeUpdate.to_numpy()
            next_expected=np.where(t.Updated.to_numpy(dtype=bool),.95*estimate+.05*inputpower,estimate)
            rel=np.max(np.abs(estimate[1:]-next_expected[:-1])/np.maximum(estimate[1:],1e-300))
            assert rel<1e-12;recurrence_errors.append(float(rel))
    metrics['STOI']=scores
    metrics.to_csv(ROOT/'metrics.csv',index=False,float_format='%.15g')
    # Exactly reproduce the12constant10dB cases of the previously frozen study.
    prior=pd.read_csv(ROOT/'prior_test_metrics_reference.csv')
    matched=metrics[metrics.Profile=='constant'].merge(prior[prior.NominalSNR_dB==10],on=['Utterance','Noise','Method'],suffixes=('_new','_prior'))
    assert len(matched)==48
    constant_stoi=float(np.max(np.abs(matched.STOI_new-matched.STOI_prior)))
    constant_snr=float(np.max(np.abs(matched.SNR_dB_new-matched.SNR_dB_prior)))
    assert constant_stoi<1e-12 and constant_snr<1e-11,(constant_stoi,constant_snr)
    # Noise types are averaged within each of the six repeated sentence units.
    sentence=metrics.groupby(['Utterance','Profile','Method'],sort=False)[['SNR_dB','STOI','PostSNR_dB','LateTrackingBias_dB','LateMedianAbsTrackingError_dB','LateUpdateFraction']].mean().reset_index()
    sentence.to_csv(ROOT/'sentence_means.csv',index=False,float_format='%.15g')
    contrasts=[]
    for a,b in [('vad_selected','vad_original'),('vad_selected','fixed'),('vad_original','fixed')]:
        am=sentence[sentence.Method==a].set_index(['Utterance','Profile'])
        bm=sentence[sentence.Method==b].set_index(['Utterance','Profile'])
        for key in am.index:
            u,p=key
            r={'Utterance':u,'Profile':p,'Contrast':a+' minus '+b}
            for metric in ['SNR_dB','STOI','PostSNR_dB']:
                r[metric]=float(am.loc[key,metric]-bm.loc[key,metric])
            contrasts.append(r)
    contrast=pd.DataFrame(contrasts)
    contrast.to_csv(ROOT/'sentence_paired_contrasts.csv',index=False,float_format='%.15g')
    interactions=[]
    for c in contrast.Contrast.unique():
        sub=contrast[contrast.Contrast==c].set_index(['Utterance','Profile'])
        for u in sentence.Utterance.unique():
            for p in PROFILES[1:]:
                r={'Utterance':u,'ChangedProfile':p,'Contrast':c}
                for metric in ['SNR_dB','STOI','PostSNR_dB']:
                    r[metric]=float(sub.loc[(u,p),metric]-sub.loc[(u,'constant'),metric])
                interactions.append(r)
    interaction=pd.DataFrame(interactions)
    interaction.to_csv(ROOT/'sentence_profile_interactions.csv',index=False,float_format='%.15g')
    report={'design':{'mixtures':36,'method_rows':144,'sentence_units':6,'noise_types_averaged_within_sentence':2,'previously_used_sentences':True,'formal_inference':False},'profile_method_means':[], 'sentence_contrasts':[], 'sentence_profile_interactions':[]}
    for (p,m),g in sentence.groupby(['Profile','Method'],sort=False):
        report['profile_method_means'].append({'profile':p,'method':m,**{k:desc(g[k]) for k in ['SNR_dB','STOI','PostSNR_dB']}})
    for (p,c),g in contrast.groupby(['Profile','Contrast'],sort=False):
        report['sentence_contrasts'].append({'profile':p,'contrast':c,**{k:desc(g[k]) for k in ['SNR_dB','STOI','PostSNR_dB']}})
    for (p,c),g in interaction.groupby(['ChangedProfile','Contrast'],sort=False):
        report['sentence_profile_interactions'].append({'changed_profile':p,'contrast':c,**{k:desc(g[k]) for k in ['SNR_dB','STOI','PostSNR_dB']}})
    # Fixed estimator is profile invariant; late known power shifts by +/-6dB.
    for (u,n),g in metrics[metrics.Method=='fixed'].groupby(['Utterance','Noise']):
        d=g.set_index('Profile')
        assert abs(d.loc['rise_6dB','LateTrackingBias_dB']-d.loc['constant','LateTrackingBias_dB']+6)<1e-11
        assert abs(d.loc['fall_6dB','LateTrackingBias_dB']-d.loc['constant','LateTrackingBias_dB']-6)<1e-11
    report['tracking_diagnostics']=[]
    for (p,m),g in metrics[metrics.Method!='unprocessed'].groupby(['Profile','Method'],sort=False):
        report['tracking_diagnostics'].append({'profile':p,'method':m,'mean_late_bias_dB':float(g.LateTrackingBias_dB.mean()),'mean_late_median_abs_error_dB':float(g.LateMedianAbsTrackingError_dB.mean()),'mean_late_update_fraction':float(g.LateUpdateFraction.mean()),'speech_proxy_updates':int(g.SpeechProxyUpdates.sum()),'speech_proxy_frames':int(g.SpeechProxyFrames.sum()),'nonspeech_proxy_updates':int(g.NonSpeechProxyUpdates.sum()),'nonspeech_proxy_frames':int(g.NonSpeechProxyFrames.sum())})
    pd.DataFrame(report['tracking_diagnostics']).to_csv(ROOT/'tracking_summary.csv',index=False,float_format='%.15g')
    checks=pd.read_csv(ROOT/'verification_cases.csv')
    report['checks']={'input_and_core_sha256':'PASS','protocol_sha256':'PASS','constant_profile_vs_prior_max_abs_STOI':constant_stoi,'constant_profile_vs_prior_max_abs_SNR_dB':constant_snr,'independent_python_SNR_max_abs_difference':max(recomputed),'independent_windowed_noise_power_max_relative_error':max(tracking_errors),'independent_estimate_before_update_recurrence_max_relative_error':max(recurrence_errors),'fixed_late_tracking_ratio_changes_exactly_opposite_6dB_manipulation':'PASS','identity_max_abs_error':float(checks.IdentityMaxAbsError.max()),'mixture_prefix_initial_PSD_trace_output_invariance':'PASS in MATLAB for all36cases','initial_clean_to_noise_max_dB':float(checks.InitialCleanToInjectedNoise_dB.max()),'maximum_mixture_peak':float(checks.InputPeak.max()),'finite_outputs_scores_and_no_STOI_warnings':True,'scored_without_quantization':True}
    report['environment']={'Python':platform.python_version(),'numpy':np.__version__,'scipy':scipy.__version__,'pystoi':pystoi.__version__,'scored_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
    (ROOT/'ANALYSIS_SUMMARY.json').write_text(json.dumps(report,indent=2)+'\n')
    plot_contrasts(contrast)
    plot_trace(traces,sigs)
    # Every output remains auditable; manifest is written after plots/results.
    print(json.dumps({'checks':report['checks'],'profile_means':[{k:v for k,v in r.items() if k in ['profile','method','SNR_dB','STOI']} for r in report['profile_method_means']]},indent=2))

def style():
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9,'axes.titlesize':10,'axes.labelsize':9,'legend.fontsize':8,'axes.spines.top':False,'axes.spines.right':False,'savefig.facecolor':'white'})

def plot_contrasts(c):
    style();fig,axes=plt.subplots(2,3,figsize=(9.5,5.0),sharex=True,constrained_layout=True)
    types=['vad_original minus fixed','vad_selected minus fixed','vad_selected minus vad_original']
    names=['Original VAD − fixed','Selected VAD − fixed','Selected VAD − original']
    jitter=np.linspace(-.15,.15,6)
    for col,(typ,name) in enumerate(zip(types,names)):
        sub=c[c.Contrast==typ]
        for row,metric in enumerate(['SNR_dB','STOI']):
            ax=axes[row,col]
            for pi,p in enumerate(PROFILES):
                values=sub[sub.Profile==p].sort_values('Utterance')[metric].to_numpy()
                ax.scatter(pi+jitter,values,s=19,facecolors='none',edgecolors='#46657A',linewidths=.8,zorder=3)
                ax.plot([pi-.21,pi+.21],[values.mean()]*2,color='#B34A32',lw=2.6,zorder=4)
            ax.axhline(0,color='#737373',lw=.8,ls='--');ax.grid(axis='y',alpha=.18)
            ax.set_xticks([0,1,2],['Constant','Rise +6 dB','Fall −6 dB']);ax.set_xlim(-.48,2.48)
            if row==0:ax.set_title(name)
            if col==0:ax.set_ylabel('Δ reference SNR (dB)' if metric=='SNR_dB' else 'Δ standard STOI')
    fig.suptitle('Matched noise-level changes: six sentence-level paired effects',fontsize=12)
    fig.supxlabel('Open points: each sentence averaged over car + street; red bars: six-sentence mean',fontsize=8)
    fig.savefig(ROOT/'paired_effects.png',dpi=220);fig.savefig(ROOT/'paired_effects.pdf');plt.close(fig)

def plot_trace(traces,sigs):
    style();target=next(s for s in sigs if s['Utterance']=='sp02' and s['Noise']=='street' and s['Profile']=='rise_6dB')
    sub=traces[(traces.Utterance=='sp02')&(traces.Noise=='street')&(traces.Profile=='rise_6dB')]
    first=sub[sub.Method=='fixed'];time=first.Time_s.to_numpy();change=(int(target['changeStart'])-1)/8000;late=(int(target['postStart'])-1)/8000
    fig,axes=plt.subplots(3,1,figsize=(9.5,5.4),sharex=True,constrained_layout=True,gridspec_kw={'height_ratios':[2.3,1,1]})
    power=first.InjectedFramePower.to_numpy()
    axes[0].plot(time,10*np.log10(power),color='#6B7780',alpha=.7,lw=1,label='Injected noise: instantaneous windowed power')
    for m in ['fixed','vad_original','vad_selected']:
        d=sub[sub.Method==m]
        axes[0].plot(d.Time_s,10*np.log10(d.EstimateBeforeUpdate),label=LABELS[m]+' estimate',lw=1.6,color=COLORS[m])
    axes[0].set_ylabel('10 log₁₀ broadband power');axes[0].legend(loc='best',ncol=2);axes[0].grid(alpha=.15)
    axes[0].set_title('Preselected diagnostic: sp02, street noise, +6 dB level rise')
    for ax,m in zip(axes[1:],['vad_original','vad_selected']):
        d=sub[sub.Method==m]
        y1=np.full(len(d),np.nan);y2=y1.copy();y3=y1.copy()
        y1[d.SpeechDecision.astype(bool)]=2;y2[d.Updated.astype(bool)]=1;y3[d.SpeechProxy.astype(bool)]=0
        ax.plot(d.Time_s,y1,'|',color=COLORS[m],markersize=6,label='Speech gate (update blocked)')
        ax.plot(d.Time_s,y2,'|',color='#27846C',markersize=6,label='Noise update')
        ax.plot(d.Time_s,y3,'|',color='#8A679E',markersize=6,label='Clean-energy speech proxy')
        ax.set_ylim(-.6,2.6);ax.set_yticks([0,1,2],['Speech proxy','Update','Gate speech']);ax.set_ylabel(LABELS[m]);ax.grid(axis='x',alpha=.15)
    for ax in axes:
        ax.axvspan(change,change+.05,color='#D8AD4A',alpha=.25)
        ax.axvline(late,color='#777',ls=':',lw=.9)
    axes[-1].set_xlabel('Time (s); shaded: 50 ms ramp; dotted line: late diagnostic interval begins')
    fig.savefig(ROOT/'tracking_example.png',dpi=220);fig.savefig(ROOT/'tracking_example.pdf');plt.close(fig)

if __name__=='__main__':main()
