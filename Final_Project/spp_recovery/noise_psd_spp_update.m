function [noisePSD, probabilityMean, diagnostic] = noise_psd_spp_update(periodogram, previousPSD, previousMean, cfg)
% NOISE_PSD_SPP_UPDATE One causal frame of fixed-prior soft-SPP noise tracking.
% Adapted from noisePowProposed, v1.0, October 2011, Gerkmann and Hendriks.
% Official source: https://fiona.uni-hamburg.de/11888f86/noisepowproposed.m
% Paper: Gerkmann & Hendriks (2012), doi:10.1109/TASL.2011.2180896,
% equations 8, 18, 22, 23 and 24.
% This integration retains the author recurrence and defaults, with an
% explicit optional alphaPSD=.95 ablation. It does not introduce a new SPP.
% Call only on valid post-calibration frames, AFTER the current enhancement.
% All vectors are full FFT bins. State starts at .5 per bin. The project's
% 10 ms hop and common initial PSD differ from the author's standalone driver.
%%%%%%%%%%%%%%%%%%%%%% Copyright (c) 2011, Timo Gerkmann
%%%%%%%%%%%%%%%%%%%%%% Author: Timo Gerkmann and Richard Hendriks
%%%%%%%%%%%%%%%%%%%%%% Universitaet Oldenburg
%%%%%%%%%%%%%%%%%%%%%% KTH Royal Institute of Technology
%%%%%%%%%%%%%%%%%%%%%% Delft university of Technology
%%%%%%%%%%%%%%%%%%%%%% Contact: timo.gerkmann@uni-oldenburg.de
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
%
%     * Redistributions of source code must retain the above copyright
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in
%       the documentation and/or other materials provided with the distribution
%     * Neither the name of the Universitaet Oldenburg, Delft university, KTH 
%	Royal Institute of Technology nor the names of its contributors may be 
% 	used to endorse or promote products derived from this software without 
% 	specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
%

if nargin<4, cfg=struct(); end
alphaPSD = option(cfg,'sppNoiseSmoothing',0.8);
alphaProbability = option(cfg,'sppProbabilitySmoothing',0.9);
q = option(cfg,'sppSpeechPrior',0.5);
xiDb = option(cfg,'sppPriorSNR_dB',15);
stagnationThreshold = option(cfg,'sppStagnationThreshold',0.99);
stagnationCap = option(cfg,'sppStagnationCap',0.99);
assert(alphaPSD>=0 && alphaPSD<1 && alphaProbability>=0 && alphaProbability<1);
assert(q>0 && q<1 && isfinite(xiDb));
assert(stagnationThreshold>0 && stagnationThreshold<1 && stagnationCap>0 && stagnationCap<1);
assert(isequal(size(periodogram),size(previousPSD),size(previousMean)));
assert(all(isfinite(periodogram)) && all(periodogram>=0));
assert(all(isfinite(previousPSD)) && all(previousPSD>0));
assert(all(isfinite(previousMean)) && all(previousMean>=0 & previousMean<=1));

xi = 10^(xiDb/10);
priorFactor = q/(1-q);
logGLRFactor = log(1/(1+xi));
GLRexponent = xi/(1+xi);
posteriorSNR = periodogram./previousPSD;
% Keep author clipping placement; not a hard speech decision.
GLR = priorFactor .* exp(min(logGLRFactor + GLRexponent.*posteriorSNR,200));
probabilityBeforeCap = GLR./(1+GLR);
% The history uses the UNCAPPED probability, as in the author source.
probabilityMean = alphaProbability*previousMean + ...
    (1-alphaProbability)*probabilityBeforeCap;
capActive = probabilityMean>stagnationThreshold;
probabilityAfterCap = probabilityBeforeCap;
probabilityAfterCap(capActive) = min(probabilityAfterCap(capActive),stagnationCap);
noisePeriodogram = probabilityAfterCap.*previousPSD + ...
    (1-probabilityAfterCap).*periodogram;
noisePSD = alphaPSD*previousPSD + (1-alphaPSD)*noisePeriodogram;

diagnostic.probabilityBeforeCap = probabilityBeforeCap;
diagnostic.probabilityAfterCap = probabilityAfterCap;
diagnostic.updateWeight = (1-alphaPSD)*(1-probabilityAfterCap);
diagnostic.capActive = capActive;
diagnostic.noisePeriodogram = noisePeriodogram;
end

function value = option(cfg,name,fallback)
if isfield(cfg,name)
    value=cfg.(name);
else
    value=fallback;
end
end
