
function bill = calculateSCEDeliveryBill( ...
    touNet_kWh, touRates, baseline_kWh, ...
    baselineRates, cca_kWh, ccaRates, ...
    recovery_kWh, recoveryRates)
% calculateSCEDeliveryBill
% Calculates itemized SCE delivery and CRS charges.
%
% Inputs:
%   touNet_kWh      - Net kWh for each TOU billing period
%   touRates        - Corresponding delivery rates ($/kWh)
%   baseline_kWh    - kWh receiving baseline credits
%   baselineRates   - Baseline credit rates ($/kWh)
%   cca_kWh         - Billing quantities for CCA/CRS charges
%   ccaRates        - Corresponding CCA/CRS rates
%   recovery_kWh    - Billing quantities for recovery charges
%   recoveryRates   - Corresponding recovery rates
%
% All input arrays must be matching pairs.

    roundCents = @(x) round(x * 100) / 100;

    % Calculate each line item and round to cents
    energy = roundCents(touNet_kWh(:) .* touRates(:));

    baseline = roundCents( ...
        baseline_kWh(:) .* baselineRates(:));

    cca = roundCents(cca_kWh(:) .* ccaRates(:));

    recovery = roundCents( ...
        recovery_kWh(:) .* recoveryRates(:));

    % Return detailed billing components
    bill.energyCharges = sum(energy);
    bill.baselineCredits = sum(baseline);
    bill.ccaCharges = sum(cca);
    bill.recoveryCharges = sum(recovery);

    bill.trackedCharge = ...
        bill.energyCharges + ...
        bill.baselineCredits + ...
        bill.ccaCharges + ...
        bill.recoveryCharges;
end
