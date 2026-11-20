
function bill = calculateEPICGenerationBill( ...
    netEnergy_kWh, generationRates, surcharge)
% CALCULATEEPICGENERATIONBILL
% Calculate itemized EPIC generation charges.
%
% Inputs:
%   netEnergy_kWh   Net energy for each TOU billing category
%   generationRates Corresponding generation rates ($/kWh)
%   surcharge       Additional billed surcharge ($)
%
% NOTE:
% This function reproduces itemized billing arithmetic.
% It does not yet model EPIC's annual NEM settlement rules.

    netEnergy_kWh = netEnergy_kWh(:);
    generationRates = generationRates(:);

    assert(numel(netEnergy_kWh) == ...
        numel(generationRates), ...
        'Energy and rate arrays must match.');

    assert(all(isfinite(netEnergy_kWh)) && ...
        all(isfinite(generationRates)) && ...
        all(generationRates >= 0) && ...
        isscalar(surcharge) && isfinite(surcharge), ...
        'Invalid generation billing inputs.');

    roundCents = @(x) round(x * 100) / 100;

    lineCharges = roundCents( ...
        netEnergy_kWh .* generationRates);

    bill.energyCharges = sum(lineCharges);
    bill.surcharge = surcharge;

    bill.totalCharge = ...
        bill.energyCharges + bill.surcharge;

    bill.lineCharges = lineCharges;
end
