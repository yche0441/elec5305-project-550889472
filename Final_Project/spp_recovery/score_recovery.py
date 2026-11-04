"""Frozen soft-tracker study: independent scoring, diagnostics and complete summaries.

Run after MATLAB_RUN_STATUS.json exists. Uses all 252 inputs and all six methods.
STOI is standard pystoi 0.4.1 on unquantized samples 801:N. No selection or tuning.
"""
from pathlib import Path
import hashlib, json, platform, warnings, datetime
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
METHODS=['unprocessed','fixed','vad_original','vad_selected','spp_default','spp_matched']
PROFILES=['constant','rise_6dB','fall_6dB']
SPEAKERS=['CH','DE','JE','KI','SI','TI']
PAIRS=[('spp_default','vad_selected'),('spp_default','fixed'),('spp_matched','vad_selected'),('spp_default','spp_matched')]
SCORES=['SNR_dB','STOI','PostSNR_dB']
DIAGS=['LateBandError_dB','LateSpectralNRMSE','LateTrackingBias_dB','LateMedianAbsTrackingError_dB','MeanUpdateWeight','LateMeanUpdateWeight','SpeechProxyMeanWeight','LowEnergyProxyMeanWeight']
METRICS=SCORES+DIAGS
LOWER={'LateBandError_dB','LateSpectralNRMSE','LateMedianAbsTrackingError_dB'}
HIGHER=set(SCORES)
COLORS={'fixed':'#6B7280','vad_selected':'#B45C2A','spp_default':'#007C83','spp_matched':'#6A5ACD'}
LABELS={'fixed':'Fixed','vad_selected':'Selected gate','spp_default':'SPP 0.8','spp_matched':'SPP 0.95'}

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def records(x):return x if isinstance(x,list) else list(np.atleast_1d(x))
def relative(a,b):
    a=np.asarray(a);b=np.asarray(b)
    return float(np.max(np.abs(a-b)/np.maximum(np.abs(b),1e-300)))
def snr(clean,y):return float(10*np.log10(np.sum(clean**2)/np.sum((y-clean)**2)))
def check_manifests():
    for file in ['EXECUTION_MANIFEST.json','INPUT_MANIFEST.json']:
        for item in json.loads((ROOT/file).read_text()):
            assert sha(ROOT/item['path'])==item['sha256'],f'Hash mismatch: {item["path"]}'
    expected=(ROOT/'PROTOCOL_SHA256.txt').read_text().split()[0]
    assert sha(ROOT/'PROTOCOL.json')==expected,'Protocol hash changed'
    return expected

def geometry(noisy,injected,clean):
    N=len(noisy);L=200;nf=400;hop=80
    win=.5-.5*np.cos(2*np.pi*np.arange(1,L+1)/(L+1))
    initial=np.lib.stride_tricks.sliding_window_view(noisy[:800],L)
    initialPSD=np.mean(np.abs(np.fft.fft(initial*win,nf,axis=1))**2,axis=0)
    floor=max(np.finfo(float).tiny,1e-12*initialPSD.mean());initialPSD=np.maximum(initialPSD,floor)
    work=np.r_[np.zeros(L),noisy,np.zeros(2*L)]
    starts0=np.arange(0,len(work)-nf+1,hop)
    starts=starts0+1-L
    powers=np.abs(np.fft.fft(np.lib.stride_tricks.sliding_window_view(work,L)[starts0]*win,nf,axis=1))**2
    valid=(starts>800)&(starts+L-1<=N)
    ix=starts[valid]-1
    truth=np.abs(np.fft.fft(np.lib.stride_tricks.sliding_window_view(injected,L)[ix]*win,nf,axis=1))**2
    cleanPower=np.mean(np.lib.stride_tricks.sliding_window_view(clean,L)[ix]**2,axis=1)
    level=10*np.log10(np.maximum(cleanPower,np.finfo(float).tiny));level-=level.max()
    return dict(starts=starts,valid=valid,powers=powers,truth=truth,initialPSD=initialPSD,floor=floor,speech=level>=-30,low=level<=-40)

def independent_tracker(g,method):
    """Separate NumPy recurrence, including unchanged pre-calibration hangover."""
    D=g['initialPSD'].copy();m=np.full(400,.5);hold=0
    theta=1 if method=='vad_selected' else 3;H=10 if method=='vad_selected' else 5
    alpha=.95 if method=='spp_matched' else .8
    estimates=[];weights=[];caps=[]
    for P,valid in zip(g['powers'],g['valid']):
        ratio=10*np.log10(max(P.sum(),np.finfo(float).tiny)/max(D.sum(),np.finfo(float).tiny))
        if ratio>theta:speech=True;hold=H
        elif hold>0:speech=True;hold-=1
        else:speech=False
        if not valid:continue
        estimates.append(D.copy())
        if method in ['spp_default','spp_matched']:
            xi=10**1.5
            lr=np.exp(np.minimum(-np.log1p(xi)+xi/(1+xi)*(P/D),200))
            probability=lr/(1+lr)
            m=.9*m+.1*probability
            stuck=m>.99
            probability=np.where(stuck,np.minimum(probability,.99),probability)
            weight=(1-alpha)*(1-probability)
            # Deliberately use equivalent single-step recurrence, not MATLAB code.
            D=D+weight*(P-D)
            caps.append(stuck)
        elif method in ['vad_original','vad_selected'] and not speech:
            weight=np.full(400,.05);D=.95*D+.05*P;caps.append(np.zeros(400,dtype=bool))
        else:
            weight=np.zeros(400);caps.append(np.zeros(400,dtype=bool))
        D=np.maximum(D,g['floor']);weights.append(weight)
    return np.array(estimates),np.array(weights),np.array(caps)

def independent_diagnostics(g,D,W,post):
    late=g['starts'][g['valid']]>=post;truth=g['truth'];one=np.r_[1,np.full(199,2),1]
    freq=np.arange(201)*20;edges=[0,500,1000,2000,4001]
    band=[]
    for lo,hi in zip(edges[:-1],edges[1:]):
        b=(freq>=lo)&(freq<hi)
        band.append(10*np.log10(np.sum(D[late,:201][:,b]*one[b])/np.sum(truth[late,:201][:,b]*one[b])))
    means=W.mean(axis=1);power=D.sum(axis=1);truePower=truth.sum(axis=1)
    return dict(LateTrackingBias_dB=10*np.log10(power[late].sum()/truePower[late].sum()),LateMedianAbsTrackingError_dB=np.median(np.abs(10*np.log10(power[late]/truePower[late]))),LateBandError_dB=np.mean(np.abs(band)),LateSpectralNRMSE=np.linalg.norm(D[late,:201].mean(axis=0)-truth[late,:201].mean(axis=0))/np.linalg.norm(truth[late,:201].mean(axis=0)),MeanUpdateWeight=means.mean(),LateMeanUpdateWeight=means[late].mean(),SpeechProxyMeanWeight=means[g['speech']].mean() if g['speech'].any() else np.nan,LowEnergyProxyMeanWeight=means[g['low']].mean() if g['low'].any() else np.nan,**dict(zip(['Band0_500Bias_dB','Band500_1000Bias_dB','Band1000_2000Bias_dB','Band2000_4000Bias_dB'],band)))

def stats(values,metric=None):
    a=np.asarray(values,dtype=float);finite=a[np.isfinite(a)]
    if not len(finite):return dict(n=len(a),finite_n=0,mean=None,minimum=None,maximum=None)
    d=dict(n=len(a),finite_n=len(finite),mean=float(finite.mean()),minimum=float(finite.min()),maximum=float(finite.max()),positive=int((finite>0).sum()),negative=int((finite<0).sum()),zero=int((finite==0).sum()))
    if metric in LOWER:d['improvements']=int((finite<0).sum())
    if metric in HIGHER:d['improvements']=int((finite>0).sum())
    return d

def contrasts(df,keys):
    rows=[]
    for a,b in PAIRS:
        aa=df[df.Method==a].set_index(keys);bb=df[df.Method==b].set_index(keys)
        assert aa.index.equals(bb.index)
        diff=aa[METRICS]-bb[METRICS]
        diff['Contrast']=a+' minus '+b
        rows.append(diff.reset_index())
    return pd.concat(rows,ignore_index=True)

def summary_tables(metrics):
    sets={'new_constant_benchmark':metrics[(metrics.Cohort=='new_confirmation')&(metrics.Profile=='constant')],
          'new_controlled_10dB':metrics[(metrics.Cohort=='new_confirmation')&(metrics.NominalSNR_dB==10)],
          'old_diagnostic_10dB':metrics[metrics.Cohort=='old_diagnostic']}
    sentences=[];speakers=[];setcases=[]
    for name,m in sets.items():
        m=m.copy();m['AnalysisSet']=name;setcases.append(m)
        sentence=m.groupby(['AnalysisSet','Utterance','Speaker','Profile','Method'],sort=False,dropna=False)[METRICS].mean().reset_index()
        count=m.groupby(['AnalysisSet','Utterance','Speaker','Profile','Method'],sort=False).size().rename('CaseCount').reset_index()
        sentence=sentence.merge(count,validate='one_to_one');sentences.append(sentence)
        speaker=sentence.groupby(['AnalysisSet','Speaker','Profile','Method'],sort=False)[METRICS].mean().reset_index()
        count=sentence.groupby(['AnalysisSet','Speaker','Profile','Method'],sort=False).size().rename('SentenceCount').reset_index()
        speaker=speaker.merge(count,validate='one_to_one');speakers.append(speaker)
    sentence=pd.concat(sentences,ignore_index=True);speaker=pd.concat(speakers,ignore_index=True);allsetcases=pd.concat(setcases,ignore_index=True)
    casec=contrasts(allsetcases,['AnalysisSet','CaseID','Cohort','Utterance','Speaker','Noise','NominalSNR_dB','Profile'])
    sentc=contrasts(sentence,['AnalysisSet','Utterance','Speaker','Profile'])
    speakc=contrasts(speaker,['AnalysisSet','Speaker','Profile'])
    for filename,df in [('sentence_means.csv',sentence),('speaker_means.csv',speaker),('case_paired_contrasts.csv',casec),('sentence_paired_contrasts.csv',sentc),('speaker_paired_contrasts.csv',speakc)]:
        df.to_csv(ROOT/filename,index=False,float_format='%.15g')
    analyses={}
    for name,m in sets.items():
        sm=sentence[sentence.AnalysisSet==name];sp=speaker[speaker.AnalysisSet==name]
        cr=casec[casec.AnalysisSet==name];sc=sentc[sentc.AnalysisSet==name];pc=speakc[speakc.AnalysisSet==name]
        entry={'unique_inputs':int(m.CaseID.nunique()),'sentences':int(m.Utterance.nunique()),'known_speakers':int(m.Speaker.nunique()),'method_profile_means':[],'contrasts':[]}
        for (profile,method),g in sp.groupby(['Profile','Method'],sort=False):
            entry['method_profile_means'].append({'profile':profile,'method':method,**{metric:stats(g[metric]) for metric in METRICS}})
        for (profile,contrast),g in sc.groupby(['Profile','Contrast'],sort=False):
            pg=pc[(pc.Profile==profile)&(pc.Contrast==contrast)];cg=cr[(cr.Profile==profile)&(cr.Contrast==contrast)]
            entry['contrasts'].append({'profile':profile,'contrast':contrast,'case':{k:stats(cg[k],k) for k in METRICS},'sentence':{k:stats(g[k],k) for k in METRICS},'speaker':{k:stats(pg[k],k) for k in METRICS},'joint_SNR_and_STOI_improvements':{'case':int(((cg.SNR_dB>0)&(cg.STOI>0)).sum()),'sentence':int(((g.SNR_dB>0)&(g.STOI>0)).sum()),'speaker':int(((pg.SNR_dB>0)&(pg.STOI>0)).sum())}})
            for metric in SCORES+['LateBandError_dB','LateSpectralNRMSE']:
                assert abs(g[metric].mean()-pg[metric].mean())<1e-11
        analyses[name]=entry
    return analyses,speaker,speakc

def style():
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9,'axes.titlesize':10,'axes.labelsize':9,'legend.fontsize':8,'axes.spines.top':False,'axes.spines.right':False,'savefig.facecolor':'white','pdf.fonttype':42,'ps.fonttype':42})

def plot_trace(traces,sig):
    style();sub=traces[traces.CaseID==int(sig['CaseID'])]
    first=sub[sub.Method=='fixed'];t=first.Time_s.to_numpy();ref=first.EstimateBeforeUpdate.iloc[0]
    change=(int(sig['changeStart'])-1)/8000;late=(int(sig['postStart'])-1)/8000
    fig,ax=plt.subplots(2,1,figsize=(6.5,4.8),sharex=True,gridspec_kw={'height_ratios':[1.55,1]},layout='constrained')
    ax[0].plot(t,10*np.log10(first.InjectedFramePower/ref),color='#9CA3AF',lw=.75,label='Injected noise',alpha=.9)
    for m in COLORS:
        d=sub[sub.Method==m]
        ax[0].plot(d.Time_s,10*np.log10(d.EstimateBeforeUpdate/ref),color=COLORS[m],lw=1.65,label=LABELS[m],ls='--' if m=='spp_matched' else '-')
        ax[1].plot(d.Time_s,d.MeanUpdateWeight,color=COLORS[m],lw=1.2,label=LABELS[m],ls='--' if m=='spp_matched' else '-')
    ax[0].set_ylabel('Broadband power\nrelative to initial estimate (dB)')
    ax[0].set_title('Preselected new sentence sp03: street noise, +6 dB rise',fontsize=10)
    ax[0].legend(loc='upper left',bbox_to_anchor=(0,1.01),ncol=3,frameon=True,facecolor='white',framealpha=.92,columnspacing=.9,handlelength=1.8,fontsize=7.8)
    ax[1].set_ylabel('Mean effective\nupdate weight')
    ax[1].set_xlabel('Time (s)')
    for a in ax:
        a.axvspan(change,change+.05,color='#D8AD4A',alpha=.24,zorder=0)
        a.axvline(late,color='#374151',ls=':',lw=1)
        a.grid(axis='y',alpha=.2);a.set_xlim(t.min(),t.max())
    for ext in ['png','pdf']:fig.savefig(ROOT/'figures'/('recovery_tracking.'+ext),dpi=240)
    plt.close(fig)

def plot_effects(speakc):
    style();s=speakc[speakc.AnalysisSet=='new_controlled_10dB']
    fig,axes=plt.subplots(2,3,figsize=(6.5,5.55),sharey='col')
    fig.subplots_adjust(left=.12,right=.985,bottom=.17,top=.81,wspace=.38,hspace=.65)
    comparisons=['spp_default minus vad_selected','spp_matched minus vad_selected']
    titles=['Default SPP 0.8 minus selected gate','Matched SPP 0.95 minus selected gate']
    metrics=['LateBandError_dB','SNR_dB','STOI'];names=['Δ late band error (dB)\nLower is better','Δ reference SNR (dB)\nHigher is better','Δ STOI\nHigher is better']
    markers=['o','s','^','v','D','P'];offset=np.linspace(-.19,.19,6)
    for row,(comparison,title) in enumerate(zip(comparisons,titles)):
        for col,(metric,label) in enumerate(zip(metrics,names)):
            ax=axes[row,col]
            for j,profile in enumerate(PROFILES):
                group=s[(s.Profile==profile)&(s.Contrast==comparison)].set_index('Speaker').loc[SPEAKERS]
                vals=group[metric].to_numpy()
                for k,sp in enumerate(SPEAKERS):
                    ax.scatter(j+offset[k],vals[k],marker=markers[k],s=27,facecolor='none',edgecolor='#007C83' if row==0 else '#6A5ACD',linewidth=.9,zorder=3,label=sp if row==0 and col==0 and j==0 else None)
                ax.plot([j-.25,j+.25],[vals.mean()]*2,color='#B64032',lw=2.2,zorder=4)
            ax.axhline(0,color='#626873',ls='--',lw=.8);ax.grid(axis='y',alpha=.16)
            ax.set_xticks(range(3),['Const.','Rise','Fall']);ax.set_xlim(-.45,2.45)
            ax.set_title(label,fontsize=8.8);ax.tick_params(labelsize=8)
            if col==0:ax.set_ylabel('SPP 0.8 − gate' if row==0 else 'SPP 0.95 − gate',fontsize=8.5)
            if metric=='STOI':ax.ticklabel_format(style='plain',axis='y',useOffset=False)
    handles,labels=axes[0,0].get_legend_handles_labels()
    fig.legend(handles,labels,loc='lower center',bbox_to_anchor=(.53,.015),ncol=6,title='Six known speakers; each point averages 3 sentences × 2 noises',fontsize=7.4,title_fontsize=7.6,frameon=False,handletextpad=.3,columnspacing=1)
    fig.suptitle('Frozen tracker comparison on 18 additional sentences\nRed bars: mean of six speakers; zero line: no change',fontsize=9.6,y=.985)
    for ext in ['png','pdf']:fig.savefig(ROOT/'figures'/('recovery_paired_effects.'+ext),dpi=240)
    plt.close(fig)

def plot_trace_compact(traces,sig):
    style();plt.rcParams.update({'font.size':13,'axes.labelsize':13,'axes.titlesize':14,'xtick.labelsize':12,'ytick.labelsize':12})
    sub=traces[traces.CaseID==int(sig['CaseID'])];first=sub[sub.Method=='fixed'];t=first.Time_s.to_numpy();ref=first.EstimateBeforeUpdate.iloc[0]
    change=(int(sig['changeStart'])-1)/8000;late=(int(sig['postStart'])-1)/8000
    fig,ax=plt.subplots(2,1,figsize=(10,3.8),sharex=True,gridspec_kw={'height_ratios':[1.4,1]})
    fig.subplots_adjust(left=.125,right=.99,bottom=.155,top=.79,hspace=.18)
    ax[0].plot(t,10*np.log10(first.InjectedFramePower/ref),color='#9CA3AF',lw=.95,label='Injected noise')
    for method in COLORS:
        d=sub[sub.Method==method];ls='--' if method=='spp_matched' else '-'
        ax[0].plot(d.Time_s,10*np.log10(d.EstimateBeforeUpdate/ref),color=COLORS[method],lw=1.8,ls=ls,label=LABELS[method])
        ax[1].plot(d.Time_s,d.MeanUpdateWeight,color=COLORS[method],lw=1.4,ls=ls)
    for a in ax:
        a.axvspan(change,change+.05,color='#D8AD4A',alpha=.24,zorder=0);a.axvline(late,color='#374151',ls=':',lw=1)
        a.grid(axis='y',alpha=.2);a.set_xlim(t.min(),t.max())
    ax[0].set_ylabel('Relative noise\npower (dB)');ax[1].set_ylabel('Mean update\nweight');ax[1].set_xlabel('Time (s)')
    ax[0].set_yticks([-4,0,4,8]);ax[1].set_yticks([0,.08,.16])
    handles,labels=ax[0].get_legend_handles_labels()
    fig.legend(handles,labels,loc='upper center',bbox_to_anchor=(.56,.945),ncol=5,fontsize=11.5,frameon=False,columnspacing=.9,handlelength=1.8,handletextpad=.4)
    fig.suptitle('Preselected sp03 / street / +6 dB rise',fontsize=14,y=.995)
    for ext in ['png','pdf']:fig.savefig(ROOT/'figures'/('recovery_tracking_compact.'+ext),dpi=240)
    plt.close(fig)

def plot_effects_compact(speakc):
    style();plt.rcParams.update({'font.size':13,'axes.labelsize':12,'axes.titlesize':13,'xtick.labelsize':12,'ytick.labelsize':12})
    s=speakc[speakc.AnalysisSet=='new_controlled_10dB']
    fig,axes=plt.subplots(2,3,figsize=(10,5.5),sharey='col')
    fig.subplots_adjust(left=.1,right=.985,bottom=.165,top=.84,wspace=.38,hspace=.54)
    comparisons=['spp_default minus vad_selected','spp_matched minus vad_selected']
    metrics=['LateBandError_dB','SNR_dB','STOI'];names=['Δ late band error (dB)','Δ reference SNR (dB)','Δ STOI']
    markers=['o','s','^','v','D','P'];offset=np.linspace(-.19,.19,6)
    for row,comparison in enumerate(comparisons):
        for col,(metric,label) in enumerate(zip(metrics,names)):
            ax=axes[row,col]
            for j,profile in enumerate(PROFILES):
                group=s[(s.Profile==profile)&(s.Contrast==comparison)].set_index('Speaker').loc[SPEAKERS];vals=group[metric].to_numpy()
                for k,sp in enumerate(SPEAKERS):
                    ax.scatter(j+offset[k],vals[k],marker=markers[k],s=38,facecolor='none',edgecolor='#007C83' if row==0 else '#6A5ACD',linewidth=1.1,zorder=3,label=sp if row==0 and col==0 and j==0 else None)
                ax.plot([j-.25,j+.25],[vals.mean()]*2,color='#B64032',lw=2.6,zorder=4)
            ax.axhline(0,color='#626873',ls='--',lw=.9);ax.grid(axis='y',alpha=.16);ax.set_xticks(range(3),['Const.','Rise','Fall']);ax.set_xlim(-.45,2.45)
            if row==0:ax.set_title(label+'\n'+('Lower is better' if col==0 else 'Higher is better'),fontsize=12.5)
            if col==0:ax.set_ylabel('SPP 0.8 − gate' if row==0 else 'SPP 0.95 − gate',fontsize=12)
            if metric=='STOI':ax.ticklabel_format(style='plain',axis='y',useOffset=False)
    handles,labels=axes[0,0].get_legend_handles_labels()
    fig.legend(handles,labels,loc='lower center',bbox_to_anchor=(.54,.005),ncol=6,title='Six known speakers; each point averages 3 sentences × 2 noises',fontsize=11.5,title_fontsize=11.5,frameon=False,handletextpad=.3,columnspacing=1)
    fig.suptitle('18 additional sentences: paired effects against the selected gate',fontsize=14,y=.99)
    for ext in ['png','pdf']:fig.savefig(ROOT/'figures'/('recovery_paired_effects_compact.'+ext),dpi=240)
    plt.close(fig)

def findings(report):
    lines=['SOFT-TRACKER RECOVERY STUDY','All outcomes retained; no test-set tuning or inferential confidence claims.','18 additional sentences, same six known speakers; old six sentences reported separately.','']
    for setname in ['new_controlled_10dB','new_constant_benchmark','old_diagnostic_10dB']:
        data=report['analysis_sets'][setname];lines.append(setname)
        for c in data['contrasts']:
            if c['contrast'] not in ['spp_default minus vad_selected','spp_default minus fixed','spp_matched minus vad_selected','spp_default minus spp_matched']:continue
            lines.append(f"  {c['profile']}: {c['contrast']}")
            for metric in ['LateBandError_dB','LateSpectralNRMSE','SNR_dB','STOI','PostSNR_dB','LateTrackingBias_dB','SpeechProxyMeanWeight']:
                d=c['sentence'][metric];sp=c['speaker'][metric]
                if d['mean'] is None:continue
                suffix=f"; improved {d['improvements']}/{d['finite_n']} sentences, {sp['improvements']}/{sp['finite_n']} speakers" if 'improvements' in d else ''
                lines.append(f"    {metric}: {d['mean']:+.8f}{suffix}")
            lines.append(f"    Both SNR and STOI improve: {c['joint_SNR_and_STOI_improvements']}")
        lines.append('')
    lines+=['Primary endpoint is late four-band absolute log-power error on new rise cases. It compares finite-window realized noise power, not expected PSD or listening quality.','Default SPP retains source coefficients on the project 10 ms hop; .95 is a predeclared PSD-smoothing ablation.','Metrics use means within sentence and then within the six speakers. No new-speaker generalisation or subjective listening claim.','Checks: '+json.dumps(report['checks'],ensure_ascii=False)]
    (ROOT/'FINDINGS.txt').write_text('\n'.join(lines)+'\n')

def main():
    assert (ROOT/'MATLAB_RUN_STATUS.json').exists(),'Wait for complete MATLAB execution.'
    protocolhash=check_manifests()
    metrics=pd.read_csv(ROOT/'matlab_metrics.csv');frames=pd.read_csv(ROOT/'frame_diagnostics.csv');checks=pd.read_csv(ROOT/'verification_cases.csv')
    assert len(metrics)==1512 and metrics.CaseID.nunique()==252 and len(checks)==252
    assert metrics.groupby('CaseID').size().eq(6).all() and set(metrics.Method)==set(METHODS)
    indexed=metrics.set_index(['CaseID','Method']);fg={key:g for key,g in frames.groupby(['CaseID','Method'],sort=False)}
    prior=loadmat(ROOT/'regression_reference.mat',simplify_cells=True)
    previous={(s['Utterance'],s['Noise'],s['Profile']):s for s in records(prior['signals'])}
    maxSNR=maxPost=maxPower=maxRecurrence=maxWeight=maxDiag=maxOld=0.;scoreRows=[];selected=None;counter=0;independentRows=[]
    allsignals=sorted((ROOT/'signals').glob('*.mat'));assert len(allsignals)==24
    for file in allsignals:
        data=loadmat(file,simplify_cells=True);assert int(data['fs'])==8000
        for s in records(data['signals']):
            case=int(s['CaseID']);counter+=1;clean=np.asarray(s['clean'],dtype=float);out=np.asarray(s['outputs'],dtype=float);post=int(s['postStart'])
            assert out.shape==(len(clean),6) and np.isfinite(out).all();assert np.array_equal(out[:,0],s['input'])
            if s['Cohort']=='old_diagnostic':
                old=np.asarray(previous[(s['Utterance'],s['Noise'],s['Profile'])]['outputs'])
                assert np.array_equal(out[:,:4],old),'Old baseline waveforms changed'
                maxOld=max(maxOld,float(np.max(np.abs(out[:,:4]-old))))
            for mi,method in enumerate(METHODS):
                row=indexed.loc[(case,method)]
                with warnings.catch_warnings(record=True) as ws:
                    score=float(stoi(clean[800:],out[800:,mi],8000,extended=False))
                assert not ws,[str(w.message) for w in ws];assert np.isfinite(score)
                ns=snr(clean[800:],out[800:,mi]);ps=snr(clean[post-1:],out[post-1:,mi])
                maxSNR=max(maxSNR,abs(ns-row.SNR_dB));maxPost=max(maxPost,abs(ps-row.PostSNR_dB))
                assert abs(ns-row.SNR_dB)<1e-10 and abs(ps-row.PostSNR_dB)<1e-10
                scoreRows.append(dict(CaseID=case,Method=method,STOI=score))
            g=geometry(np.asarray(s['input']),np.asarray(s['injectedNoise']),clean)
            for method in METHODS[1:]:
                d=fg[(case,method)];D,W,C=independent_tracker(g,method)
                assert np.array_equal(d.FrameStartSample.to_numpy(),g['starts'][g['valid']])
                maxPower=max(maxPower,relative(d.InjectedFramePower,g['truth'].sum(axis=1)))
                maxRecurrence=max(maxRecurrence,relative(d.EstimateBeforeUpdate,D.sum(axis=1)))
                maxWeight=max(maxWeight,float(np.max(np.abs(d.MeanUpdateWeight.to_numpy()-W.mean(axis=1)))))
                assert np.array_equal(d.SpeechProxy.astype(bool),g['speech']);assert np.array_equal(d.LowEnergyProxy.astype(bool),g['low'])
                diag=independent_diagnostics(g,D,W,post);row=indexed.loc[(case,method)]
                errs=[]
                for metric,value in diag.items():
                    if np.isnan(value):assert pd.isna(row[metric]);continue
                    error=abs(value-row[metric]);maxDiag=max(maxDiag,error);errs.append(error)
                    assert error<1e-8,(case,method,metric,value,row[metric])
                independentRows.append(dict(CaseID=case,Method=method,MaxAbsoluteDiagnosticDifference=max(errs),SPPCappedBins=int(C.sum())))
            if s['Cohort']=='new_confirmation' and s['Utterance']=='sp03' and s['Noise']=='street' and int(s['NominalSNR_dB'])==10 and s['Profile']=='rise_6dB':selected=s
        print(f'Scored and independently checked {counter}/252 inputs ({file.name})',flush=True)
    assert counter==252 and selected is not None
    assert maxPower<1e-10 and maxRecurrence<1e-9 and maxWeight<1e-10
    metrics=metrics.merge(pd.DataFrame(scoreRows),on=['CaseID','Method'],validate='one_to_one').sort_values(['CaseID','Method'])
    assert np.isfinite(metrics[SCORES].to_numpy()).all()
    metrics.to_csv(ROOT/'metrics.csv',index=False,float_format='%.15g')
    pd.DataFrame(independentRows).to_csv(ROOT/'INDEPENDENT_DIAGNOSTIC_CHECKS.csv',index=False,float_format='%.15g')
    oldmetric=pd.read_csv(ROOT/'regression_metrics.csv')
    matched=metrics[(metrics.Cohort=='old_diagnostic')&metrics.Method.isin(METHODS[:4])].merge(oldmetric,on=['Utterance','Noise','Profile','Method'],suffixes=('_new','_old'),validate='one_to_one');assert len(matched)==144
    regression={k:float(np.max(np.abs(matched[k+'_new']-matched[k+'_old']))) for k in SCORES}
    assert regression['STOI']<1e-12 and regression['SNR_dB']<1e-10 and regression['PostSNR_dB']<1e-10
    for key,g in metrics[(metrics.Method=='fixed')&(metrics.NominalSNR_dB==10)].groupby(['Cohort','Utterance','Noise']):
        t=g.set_index('Profile');assert abs(t.loc['rise_6dB','LateTrackingBias_dB']-t.loc['constant','LateTrackingBias_dB']+6)<1e-10;assert abs(t.loc['fall_6dB','LateTrackingBias_dB']-t.loc['constant','LateTrackingBias_dB']-6)<1e-10
    analyses,speaker,speakc=summary_tables(metrics)
    report={'design':{'inputs':252,'method_rows':1512,'new_unique_inputs':216,'new_sentences':18,'known_speakers':6,'old_diagnostic_inputs':36,'old_diagnostic_sentences':6,'inferential_statistics':False,'no_retuning':True},'protocol_sha256':protocolhash,'analysis_sets':analyses,'checks':{'execution_and_input_manifests':'PASS','protocol_hash':'PASS','unquantized_outputs':True,'no_STOI_warnings':True,'independent_SNR_max_abs_dB':maxSNR,'independent_PostSNR_max_abs_dB':maxPost,'independent_noise_power_max_relative':maxPower,'independent_noise_recurrence_max_relative':maxRecurrence,'independent_effective_weight_max_abs':maxWeight,'independent_diagnostic_max_abs':maxDiag,'old_144_row_metric_regression':regression,'old_baseline_waveforms_max_abs':maxOld,'identity_max_abs':float(checks.IdentityMaxAbsError.max()),'fixed_late_bias_exact_opposite_profile_change':'PASS','all_cases_retained':True},'environment':{'Python':platform.python_version(),'numpy':np.__version__,'scipy':scipy.__version__,'pandas':pd.__version__,'pystoi':pystoi.__version__,'matplotlib':matplotlib.__version__,'scored_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()},'preselected_case':int(selected['CaseID']),'no_subjective_listening_claim':True}
    (ROOT/'ANALYSIS_SUMMARY.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
    findings(report);plot_trace(frames,selected);plot_effects(speakc);plot_trace_compact(frames,selected);plot_effects_compact(speakc)
    (ROOT/'figures'/'CAPTIONS.txt').write_text('Figure recovery_tracking. Preselected sp03/street/+6 dB case, new sentence from a known speaker. Curves show causal estimates before each frame update, normalised by the same initial broadband estimate; grey is the realised windowed injected-noise power. Shading denotes the 50 ms ramp; the dotted line starts the late interval. Effective weights average the actual binwise observation coefficient; no binary update-coverage comparison is made.\n\nFigure recovery_paired_effects. All six known-speaker paired effects for default SPP and the matched-smoother ablation against selected hard-gate updating. Each speaker averages three additional sentences and two noises per profile; red bars are means of the six speakers. Error differences below zero favour SPP; SNR and STOI differences above zero favour SPP. No confidence intervals or unseen-speaker claims are implied.\n')
    print(json.dumps(report['checks'],indent=2),flush=True)
    print('SCORING COMPLETE',flush=True)

if __name__=='__main__':main()
