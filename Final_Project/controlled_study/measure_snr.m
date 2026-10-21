function value = measure_snr(reference, signal)
% Global reference SNR; no signal alignment or output gain fitting.
assert(isequal(size(reference),size(signal)), 'SNR dimensions differ.');
numerator = sum(reference.^2);
denominator = sum((signal-reference).^2);
assert(numerator>0, 'The reference has no energy.');
if denominator==0
    value = Inf;
else
    value = 10*log10(numerator/denominator);
end
end
