
%% 1. Load reference tariffs
sceReference = econ.loadSCEDeliveryReferenceTariff();
epicReference = econ.loadEPICReferenceTariff();

assert(isequal(sceReference.periods, epicReference.periods));

%% 2. Calculate all 15 reference energy balances
referenceEnergy = econ.calculateReferenceEnergyBalances( ...
    hourlyRetrofitImports_kWh, ...
    hourlyRetrofitExports_kWh, ...
    economicCalendar);

%% 3. Combine with retrofit configuration information
referenceComparison = [ ...
    retrofitComparison(:,1:2), referenceEnergy];

%% 4. Calculate savings relative to the baseline
baseIdx = referenceComparison.AddedPV_kW == 0 & ...
          referenceComparison.BatteryCapacity_kWh == 0;

assert(nnz(baseIdx) == 1);

baselineReferenceValue = ...
    referenceComparison.CombinedNetValue(baseIdx);

referenceComparison.EnergyValueSavings = ...
    baselineReferenceValue - ...
    referenceComparison.CombinedNetValue;

%% 5. Verification
assert(height(referenceComparison) == 15);

assert(abs( ...
    referenceComparison.EnergyValueSavings(baseIdx)) < 1e-8);

assert(all(isfinite( ...
    referenceComparison.CombinedNetValue)));

%% 6. Display results
fprintf('\n=== SCE + EPIC REFERENCE ENERGY COMPARISON ===\n');

disp(referenceComparison(:, { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    'SCE_NetValue', ...
    'EPIC_NetValue', ...
    'CombinedNetValue', ...
    'EnergyValueSavings'}));

fprintf('All 15 reference scenarios verified.\n');
fprintf('Reference tariff energy valuation only; ');
fprintf('annual utility billing adjustments not yet applied.\n');

%% 8. Preliminary annual SCE + EPIC settlement
% Calculate settlement for all 15 retrofit configurations.
% These are incomplete annual costs, not verified bills.

nScenarios = height(referenceComparison);

settlementCost = zeros(nScenarios,1);
sceDeliveryDue = zeros(nScenarios,1);
epicGenerationDue = zeros(nScenarios,1);
epicSurplusCredit = zeros(nScenarios,1);
netSurplus_kWh = zeros(nScenarios,1);

for s = 1:nScenarios

    bill = econ.calculateAnnualSCEEPICBill( ...
        hourlyRetrofitImports_kWh(:,s), ...
        hourlyRetrofitExports_kWh(:,s), ...
        economicCalendar);

    settlementCost(s) = bill.preliminaryCost;
    sceDeliveryDue(s) = bill.sceDeliveryDue;
    epicGenerationDue(s) = bill.epicGenerationDue;
    epicSurplusCredit(s) = bill.epicNSC;
    netSurplus_kWh(s) = bill.netSurplus_kWh;

    assert(~bill.isComplete, ...
        'Settlement model unexpectedly marked complete.');
end

% Append settlement results to the comparison table
referenceComparison.PreliminaryAnnualCost = settlementCost;
referenceComparison.SCEDeliveryDue = sceDeliveryDue;
referenceComparison.EPICGenerationDue = epicGenerationDue;
referenceComparison.EPICSurplusCredit = epicSurplusCredit;
referenceComparison.NetSurplus_kWh = netSurplus_kWh;

% Savings relative to the homeowner's existing PV system
baseIdx = referenceComparison.AddedPV_kW == 0 & ...
          referenceComparison.BatteryCapacity_kWh == 0;

baselineCost = settlementCost(baseIdx);

referenceComparison.PreliminaryAnnualSavings = ...
    baselineCost - settlementCost;

% Verification
assert(height(referenceComparison) == 15);

assert(all(isfinite(settlementCost)));
assert(all(sceDeliveryDue >= 0));
assert(all(epicGenerationDue >= 0));
assert(all(epicSurplusCredit >= 0));

assert(abs( ...
    referenceComparison.PreliminaryAnnualSavings(baseIdx)) < 1e-8);

% Display results
fprintf('\n=== PRELIMINARY ANNUAL SCE + EPIC SETTLEMENT ===\n');

disp(referenceComparison(:, { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    'PreliminaryAnnualCost', ...
    'PreliminaryAnnualSavings', ...
    'NetSurplus_kWh'}));

fprintf('All 15 preliminary annual settlements PASSED.\n');
fprintf('NOTE: Excludes baseline credits, NBC, CCA-CRS, ');
fprintf('taxes, climate credits, and other adjustments.\n');

%% 9. Net surplus compensation sensitivity
% Illustrative policy scenarios, not verified tariffs.

surplusRates = [0, 0.06, 0.10];
nRates = numel(surplusRates);

sensitivityCosts = zeros(nScenarios,nRates);
sensitivitySavings = zeros(nScenarios,nRates);

% Annual charges before net surplus compensation
costBeforeSurplus = ...
    referenceComparison.SCEDeliveryDue + ...
    referenceComparison.EPICGenerationDue + ...
    0.794 * 365;

for r = 1:nRates

    sensitivityCosts(:,r) = ...
        costBeforeSurplus - ...
        referenceComparison.NetSurplus_kWh ...
        * surplusRates(r);

    sensitivitySavings(:,r) = ...
        sensitivityCosts(baseIdx,r) - ...
        sensitivityCosts(:,r);
end

%% Display sensitivity comparison

sensitivityTable = table( ...
    referenceComparison.AddedPV_kW, ...
    referenceComparison.BatteryCapacity_kWh, ...
    sensitivitySavings(:,1), ...
    sensitivitySavings(:,2), ...
    sensitivitySavings(:,3), ...
    'VariableNames', { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    'Savings_NoSurplus', ...
    'Savings_6Cents', ...
    'Savings_10Cents'});

disp('=== NET SURPLUS COMPENSATION SENSITIVITY ===');
disp(sensitivityTable);

%% Verification
assert(all(abs( ...
    sensitivitySavings(baseIdx,:)) < 1e-8));

assert(all(abs( ...
    sensitivityCosts(:,2) - ...
    referenceComparison.PreliminaryAnnualCost) < 1e-6));

fprintf('Surplus compensation sensitivity PASSED.\n');

%% 10. Grandfathered NEM eligibility screening
% Planning assumption: approved capacity equals current installed capacity.
% If a prior expansion changed installed capacity, verify this separately.
% This is a planning screen, not interconnection approval.

originalApprovedPV_kW = pv.capacity_kW;
allowedExpansion_kW = max( ...
    1, 0.10 * originalApprovedPV_kW);

addedPV = referenceComparison.AddedPV_kW;

% Assumes conventional exporting PV expansion.
% Storage-only additions are treated as potentially
% eligible to preserve existing NEM status.
preservesNEM = addedPV <= allowedExpansion_kW;

referenceComparison.PreservesExistingNEM = preservesNEM;

referenceComparison.ExpectedTariff = ...
    repmat("NBT",height(referenceComparison),1);

referenceComparison.ExpectedTariff(preservesNEM) = ...
    "Existing NEM";

fprintf('\n=== RETROFIT TARIFF ELIGIBILITY SCREEN ===\n');

disp(referenceComparison(:, { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    'PreservesExistingNEM', ...
    'ExpectedTariff'}));

assert(all(preservesNEM(addedPV == 0)));
assert(all(preservesNEM == (addedPV <= allowedExpansion_kW)));

fprintf('Tariff eligibility screening PASSED.\n');

%% 11. Tariff-transition-adjusted economic comparison
% Existing NEM is retained for battery-only retrofits.
% Exporting PV expansions are evaluated under NBT.
%
% Uses the existing simplified NEM/NBT economic model.
% These are modeled annual costs, not verified bills.

%% 11.1 Verify scenario alignment

assert(height(economicComparison) == ...
       height(referenceComparison));

assert(isequal( ...
    economicComparison.AddedPV_kW, ...
    referenceComparison.AddedPV_kW));

assert(isequal( ...
    economicComparison.BatteryCapacity_kWh, ...
    referenceComparison.BatteryCapacity_kWh));

%% 11.2 Identify baseline

baseIdx = ...
    economicComparison.AddedPV_kW == 0 & ...
    economicComparison.BatteryCapacity_kWh == 0;

assert(nnz(baseIdx) == 1);

baselineNEM1Cost = ...
    economicComparison.NEM1_AnnualCost(baseIdx);

baselineNEM2Cost = ...
    economicComparison.NEM2_AnnualCost(baseIdx);

%% 11.3 Calculate tariff-adjusted costs

preservesNEM = ...
    referenceComparison.PreservesExistingNEM;

transitionCostNEM1 = ...
    economicComparison.NBT_AnnualCost;

transitionCostNEM2 = ...
    economicComparison.NBT_AnnualCost;

% Preserve the existing NEM tariff for eligible retrofits
transitionCostNEM1(preservesNEM) = ...
    economicComparison.NEM1_AnnualCost(preservesNEM);

transitionCostNEM2(preservesNEM) = ...
    economicComparison.NEM2_AnnualCost(preservesNEM);

%% 11.4 Calculate annual savings relative to original tariff

transitionSavingsNEM1 = ...
    baselineNEM1Cost - transitionCostNEM1;

transitionSavingsNEM2 = ...
    baselineNEM2Cost - transitionCostNEM2;

%% 11.5 Store results

referenceComparison.TransitionCost_NEM1 = ...
    transitionCostNEM1;

referenceComparison.TransitionSavings_NEM1 = ...
    transitionSavingsNEM1;

referenceComparison.TransitionCost_NEM2 = ...
    transitionCostNEM2;

referenceComparison.TransitionSavings_NEM2 = ...
    transitionSavingsNEM2;

%% 11.6 Verification

assert(all(isfinite(transitionCostNEM1)));
assert(all(isfinite(transitionCostNEM2)));

assert(abs(transitionSavingsNEM1(baseIdx)) < 1e-8);
assert(abs(transitionSavingsNEM2(baseIdx)) < 1e-8);

assert(all(abs( ...
    transitionCostNEM1(~preservesNEM) - ...
    economicComparison.NBT_AnnualCost(~preservesNEM)) < 1e-8));

assert(all(abs( ...
    transitionCostNEM2(~preservesNEM) - ...
    economicComparison.NBT_AnnualCost(~preservesNEM)) < 1e-8));

fprintf('\n=== TARIFF-TRANSITION-ADJUSTED ECONOMICS ===\n');

disp(referenceComparison(:, { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    'ExpectedTariff', ...
    'TransitionCost_NEM1', ...
    'TransitionSavings_NEM1', ...
    'TransitionCost_NEM2', ...
    'TransitionSavings_NEM2'}));

fprintf('Tariff-transition economic verification PASSED.\n');

%% 12. Lifecycle economic assumptions and initial costs
% Constant-dollar analysis; preliminary assumptions.

lifecycle.horizonYears = 20;
lifecycle.realDiscountRate = 0.05;

lifecycle.pvCostPerW = 2.95;
lifecycle.batteryCostPerKWh = 1000;

% No battery replacement is modeled within the analysis horizon.
% Capacity degradation is retained; replacement decisions and costs are out of scope.

lifecycle.pvOMPerKWYear = 34;
lifecycle.realUtilityEscalation = 0;

%% 12.1 Calculate incremental retrofit capital costs

addedPV_kW = referenceComparison.AddedPV_kW;
battery_kWh = referenceComparison.BatteryCapacity_kWh;

pvInitialCost = ...
    addedPV_kW * 1000 * lifecycle.pvCostPerW;

batteryInitialCost = ...
    battery_kWh * lifecycle.batteryCostPerKWh;

initialInvestment = pvInitialCost + batteryInitialCost;

referenceComparison.PVInitialCost = pvInitialCost;
referenceComparison.BatteryInitialCost = batteryInitialCost;
referenceComparison.InitialInvestment = initialInvestment;

%% 12.2 Verify capital cost model

assert(all(initialInvestment >= 0));
assert(all(isfinite(initialInvestment)));

assert(initialInvestment(baseIdx) == 0);

assert(all(pvInitialCost(addedPV_kW == 0) == 0));
assert(all(batteryInitialCost(battery_kWh == 0) == 0));

fprintf('\n=== INITIAL RETROFIT INVESTMENT ===\n');

disp(referenceComparison(:, { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    'PVInitialCost', ...
    'BatteryInitialCost', ...
    'InitialInvestment'}));

fprintf('Initial investment verification PASSED.\n');


%% 13. Lifecycle net present value and discounted payback
% Constant-dollar, 20-year economic analysis.
% No incentives, utility escalation, or salvage value.

nScenarios = height(referenceComparison);
T = lifecycle.horizonYears;
r = lifecycle.realDiscountRate;

years = 1:T;
discountFactors = (1 + r) .^ years;

% Annual incremental maintenance for added PV only
annualPVOM = addedPV_kW * lifecycle.pvOMPerKWYear;

% Battery replacement expenditures are outside the model scope.

% Preallocate annual cash-flow matrices
cashFlowsNEM1 = zeros(nScenarios,T);
cashFlowsNEM2 = zeros(nScenarios,T);

for t = 1:T

    % Annual net savings without replacement
    cashFlowsNEM1(:,t) = ...
        referenceComparison.TransitionSavings_NEM1 ...
        - annualPVOM;

    cashFlowsNEM2(:,t) = ...
        referenceComparison.TransitionSavings_NEM2 ...
        - annualPVOM;
end

%% 13.1 Calculate net present value

npvNEM1 = -initialInvestment + ...
    sum(cashFlowsNEM1 ./ discountFactors,2);

npvNEM2 = -initialInvestment + ...
    sum(cashFlowsNEM2 ./ discountFactors,2);

referenceComparison.NPV_NEM1 = npvNEM1;
referenceComparison.NPV_NEM2 = npvNEM2;

%% 13.2 Calculate discounted payback

discountedPaybackNEM1 = NaN(nScenarios,1);
discountedPaybackNEM2 = NaN(nScenarios,1);

for i = 1:nScenarios

    % No-action baseline has no meaningful payback period.
    if baseIdx(i)
        continue;
    end

    % Include initial investment at year zero
    cumulativeNEM1 = -initialInvestment(i);
    cumulativeNEM2 = -initialInvestment(i);

    for t = 1:T

        cumulativeNEM1 = cumulativeNEM1 + ...
            cashFlowsNEM1(i,t) / discountFactors(t);

        cumulativeNEM2 = cumulativeNEM2 + ...
            cashFlowsNEM2(i,t) / discountFactors(t);

        if isnan(discountedPaybackNEM1(i)) && ...
                cumulativeNEM1 >= 0

            discountedPaybackNEM1(i) = t;
        end

        if isnan(discountedPaybackNEM2(i)) && ...
                cumulativeNEM2 >= 0

            discountedPaybackNEM2(i) = t;
        end
    end
end

referenceComparison.DiscountedPayback_NEM1 = ...
    discountedPaybackNEM1;

referenceComparison.DiscountedPayback_NEM2 = ...
    discountedPaybackNEM2;

%% 13.3 Verification

assert(all(isfinite(npvNEM1)));
assert(all(isfinite(npvNEM2)));

assert(abs(npvNEM1(baseIdx)) < 1e-8);
assert(abs(npvNEM2(baseIdx)) < 1e-8);

assert(all(isnan(discountedPaybackNEM1) | ...
    (discountedPaybackNEM1 >= 1 & ...
     discountedPaybackNEM1 <= T)));

assert(all(isnan(discountedPaybackNEM2) | ...
    (discountedPaybackNEM2 >= 1 & ...
     discountedPaybackNEM2 <= T)));

fprintf('\n=== LIFECYCLE ECONOMIC COMPARISON ===\n');

disp(referenceComparison(:, { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    'InitialInvestment', ...
    'TransitionSavings_NEM1', ...
    'NPV_NEM1', ...
    'DiscountedPayback_NEM1'}));

fprintf('Lifecycle economic verification PASSED.\n');

%% 14. Battery cost break-even analysis
% Determine the maximum installed battery cost per kWh
% that produces NPV >= 0 for battery-only scenarios.

batteryOnly = ...
    referenceComparison.AddedPV_kW == 0 & ...
    referenceComparison.BatteryCapacity_kWh > 0;

batterySizes = ...
    referenceComparison.BatteryCapacity_kWh(batteryOnly);

annualSavings = ...
    referenceComparison.TransitionSavings_NEM1(batteryOnly);

T = lifecycle.horizonYears;
r = lifecycle.realDiscountRate;

% Present value factor for constant annual savings
annuityFactor = sum(1 ./ (1+r).^(1:T));
% Battery replacement is excluded.
breakEvenBatteryCostPerKWh = (annualSavings * annuityFactor) ./ batterySizes;

batteryCostThresholds = table( ...
    batterySizes, ...
    annualSavings, ...
    breakEvenBatteryCostPerKWh, ...
    'VariableNames', { ...
    'BatteryCapacity_kWh', ...
    'AnnualSavings', ...
    'BreakEvenInstalledCostPerKWh'});

%% 14.1 Verify thresholds

assert(all(isfinite(breakEvenBatteryCostPerKWh)));
assert(all(breakEvenBatteryCostPerKWh > 0));

% Recalculate NPV at the threshold
thresholdInitialCost = ...
    batterySizes .* breakEvenBatteryCostPerKWh;

thresholdNPV = ...
    annualSavings * annuityFactor ...
    - thresholdInitialCost ...
   ;

assert(all(abs(thresholdNPV) < 1e-6));

fprintf('\n=== BATTERY COST BREAK-EVEN ANALYSIS ===\n');

disp(batteryCostThresholds);

fprintf('Battery cost break-even verification PASSED.\n');

%% 15. Lifecycle NPV sensitivity analysis
% Evaluate the battery-only 5 kWh configuration.

targetIdx = ...
    referenceComparison.AddedPV_kW == 0 & ...
    referenceComparison.BatteryCapacity_kWh == 5;

assert(nnz(targetIdx) == 1);

targetCapacity = 5;
baseAnnualSavings = ...
    referenceComparison.TransitionSavings_NEM1(targetIdx);

T = lifecycle.horizonYears;

%% 15.1 Battery cost sensitivity

batteryCostCases = [300; 450; 600; 800; 1000; 1200];

npvBatteryCost = zeros(size(batteryCostCases));

for i = 1:numel(batteryCostCases)

    initialCost = targetCapacity * batteryCostCases(i);

    pvSavings = baseAnnualSavings * ...
        sum(1 ./ (1+lifecycle.realDiscountRate).^(1:T));

    npvBatteryCost(i) = ...
        pvSavings - initialCost;
end

batteryCostSensitivity = table( ...
    batteryCostCases, npvBatteryCost, ...
    'VariableNames', {'BatteryCostPerKWh','NPV'});

%% 15.2 Discount rate sensitivity

discountRateCases = [0.02; 0.03; 0.05; 0.07; 0.10];

npvDiscountRate = zeros(size(discountRateCases));

baseInitialCost = ...
    referenceComparison.InitialInvestment(targetIdx);

for i = 1:numel(discountRateCases)

    rCase = discountRateCases(i);

    pvSavings = baseAnnualSavings * ...
        sum(1 ./ (1+rCase).^(1:T));

    npvDiscountRate(i) = ...
        pvSavings - baseInitialCost;
end

discountRateSensitivity = table( ...
    discountRateCases, npvDiscountRate, ...
    'VariableNames', {'RealDiscountRate','NPV'});

%% 15.3 Annual savings sensitivity

savingsMultiplierCases = [0.5; 0.75; 1; 1.25; 1.5; 2];

npvSavings = zeros(size(savingsMultiplierCases));

for i = 1:numel(savingsMultiplierCases)

    adjustedSavings = ...
        baseAnnualSavings * savingsMultiplierCases(i);

    pvSavings = adjustedSavings * ...
        sum(1 ./ (1+lifecycle.realDiscountRate).^(1:T));

    npvSavings(i) = ...
        pvSavings - baseInitialCost;
end

savingsSensitivity = table( ...
    savingsMultiplierCases, npvSavings, ...
    'VariableNames', {'SavingsMultiplier','NPV'});

%% 15.4 Verification

baseNPV = referenceComparison.NPV_NEM1(targetIdx);

assert(abs( ...
    npvBatteryCost(batteryCostCases == 1000) ...
    - baseNPV) < 1e-6);

assert(abs( ...
    npvDiscountRate(discountRateCases == 0.05) ...
    - baseNPV) < 1e-6);

assert(abs( ...
    npvSavings(savingsMultiplierCases == 1) ...
    - baseNPV) < 1e-6);

fprintf('\n=== BATTERY COST SENSITIVITY ===\n');
disp(batteryCostSensitivity);

fprintf('\n=== DISCOUNT RATE SENSITIVITY ===\n');
disp(discountRateSensitivity);

fprintf('\n=== ANNUAL SAVINGS SENSITIVITY ===\n');
disp(savingsSensitivity);

fprintf('Lifecycle sensitivity verification PASSED.\n');

%% 16. Final base-case economic ranking
% Rank all configurations by lifecycle NPV.
% No-action payback is not applicable.

%% 16.1 Correct baseline payback
referenceComparison.DiscountedPayback_NEM1(baseIdx) = NaN;
referenceComparison.DiscountedPayback_NEM2(baseIdx) = NaN;

%% 16.2 Rank all scenarios
[~, rankOrder] = sort( ...
    referenceComparison.NPV_NEM1, 'descend');

rankedEconomicComparison = ...
    referenceComparison(rankOrder, { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    'ExpectedTariff', ...
    'InitialInvestment', ...
    'TransitionSavings_NEM1', ...
    'NPV_NEM1', ...
    'DiscountedPayback_NEM1'});

rankedEconomicComparison.Rank = ...
    (1:height(rankedEconomicComparison))';

rankedEconomicComparison = movevars( ...
    rankedEconomicComparison, 'Rank', 'Before', 1);

%% 16.3 Identify preferred alternative
[bestNPV, bestIdx] = max(referenceComparison.NPV_NEM1);

bestPV = referenceComparison.AddedPV_kW(bestIdx);
bestBattery = referenceComparison.BatteryCapacity_kWh(bestIdx);

%% 16.4 Verification
assert(bestNPV >= 0);
assert(abs(bestNPV - max(referenceComparison.NPV_NEM1)) < 1e-8);
assert(bestPV == rankedEconomicComparison.AddedPV_kW(1));
assert(bestBattery == rankedEconomicComparison.BatteryCapacity_kWh(1));

assert(isnan( ...
    referenceComparison.DiscountedPayback_NEM1(baseIdx)));

assert(all(diff(rankedEconomicComparison.NPV_NEM1) <= 0));

fprintf('\n=== RANKED BASE-CASE ECONOMIC RESULTS ===\n');
disp(rankedEconomicComparison);

fprintf('\nPreferred configuration: +%.0f kW PV, %.0f kWh battery\n', ...
    bestPV, bestBattery);

fprintf('Preferred configuration NPV: $%.2f\n', bestNPV);

fprintf('Base-case economic ranking verification PASSED.\n');

%% 17. Time-dependent NEM expiration analysis
% NEM eligibility is based on original interconnection, which defaults
% to PV installation year in technical_model.m. A separate interconnection
% year may be supplied for panel replacements or other exceptions.
% Eligibility and the 20-year term are simplified planning assumptions.
analysisStartYear = 2027;
assert(exist('homeownerInputs','var') == 1 && ...
    isfield(homeownerInputs,'pvInstallationYear') && ...
    isfield(homeownerInputs,'originalInterconnectionYear'), ...
    'Run technical_model.m before lifecycle_analysis.m.');
originalInterconnectionYear = homeownerInputs.originalInterconnectionYear;
assert(isnumeric(originalInterconnectionYear) && ...
    isscalar(originalInterconnectionYear) && ...
    isfinite(originalInterconnectionYear) && ...
    originalInterconnectionYear == floor(originalInterconnectionYear) && ...
    originalInterconnectionYear >= 1900 && ...
    originalInterconnectionYear <= analysisStartYear, ...
    'Original interconnection year must be an integer between 1900 and 2027.');
nemTermYears = 20;
nemExpirationYear = originalInterconnectionYear + nemTermYears;

T = lifecycle.horizonYears;
r = lifecycle.realDiscountRate;

calendarYears = analysisStartYear + (0:T-1);
discountFactors = (1+r).^(1:T);

nScenarios = height(referenceComparison);

%% 17.1 Annual electricity costs under tariff transition

annualTransitionCost = zeros(nScenarios,T);
annualBaselineCost = zeros(1,T);

for t = 1:T

    if calendarYears(t) < nemExpirationYear

        % Baseline retains existing NEM before expiration
        annualBaselineCost(t) = ...
            economicComparison.NEM1_AnnualCost(baseIdx);

        % Eligible configurations retain existing NEM
        annualTransitionCost(:,t) = ...
            economicComparison.NBT_AnnualCost;

        annualTransitionCost( ...
            referenceComparison.PreservesExistingNEM,t) = ...
            economicComparison.NEM1_AnnualCost( ...
            referenceComparison.PreservesExistingNEM);

    else

        % All configurations use NBT after expiration
        annualBaselineCost(t) = ...
            economicComparison.NBT_AnnualCost(baseIdx);

        annualTransitionCost(:,t) = ...
            economicComparison.NBT_AnnualCost;
    end
end

%% 17.2 Calculate annual savings relative to no retrofit

annualTransitionSavings = ...
    annualBaselineCost - annualTransitionCost;

%% 17.3 Calculate lifecycle NPV with tariff expiration

annualPVOM = ...
    referenceComparison.AddedPV_kW * ...
    lifecycle.pvOMPerKWYear;

cashFlowsTransition = ...
    annualTransitionSavings - annualPVOM;

npvWithExpiration = ...
    -referenceComparison.InitialInvestment + ...
    sum(cashFlowsTransition ./ discountFactors,2);

referenceComparison.NPV_WithNEMExpiration = ...
    npvWithExpiration;

%% 17.4 Verification

assert(all(isfinite(npvWithExpiration)));
assert(abs(npvWithExpiration(baseIdx)) < 1e-8);

assert(all(abs( ...
    annualTransitionSavings(baseIdx,:)) < 1e-8));

assert(all(abs( ...
    annualTransitionSavings(:,calendarYears >= nemExpirationYear) ...
    - (economicComparison.NBT_AnnualCost(baseIdx) ...
    - economicComparison.NBT_AnnualCost)) < 1e-8, ...
    'all'));

fprintf('\n=== NEM EXPIRATION LIFECYCLE COMPARISON ===\n');

disp(referenceComparison(:, { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    'NPV_NEM1', ...
    'NPV_WithNEMExpiration'}));

fprintf('NEM expiration verification PASSED.\n');

%% 18. Equipment degradation trajectories
% Preliminary engineering assumptions.
% PV output declines 0.5% annually.
% Battery usable capacity declines 2% annually.
% No replacement is modeled during the 20-year horizon.

pvAnnualDegradation = 0.005;
batteryAnnualFade = 0.02;

T = lifecycle.horizonYears;
yearsInService = 0:T-1;

%% 18.1 PV production retention
% The existing PV system is already aged in main_v3.
% These factors represent additional degradation
% during the economic analysis period.

pvRetention = ...
    (1-pvAnnualDegradation).^yearsInService;

%% 18.2 Battery capacity retention
% No replacement: battery capacity declines throughout the horizon.
batteryAge = yearsInService;
batteryRetention = (1-batteryAnnualFade).^batteryAge;

%% 18.3 Create degradation table

degradationTable = table( ...
    calendarYears(:), ...
    pvRetention(:), ...
    batteryAge(:), ...
    batteryRetention(:), ...
    'VariableNames', { ...
    'CalendarYear', ...
    'PVRetention', ...
    'BatteryAgeYears', ...
    'BatteryCapacityRetention'});

%% 18.4 Verification

assert(abs(pvRetention(1)-1) < 1e-10);
assert(all(diff(pvRetention) < 0));

assert(abs(batteryRetention(1)-1) < 1e-10);
assert(all(diff(batteryRetention) < 0));

assert(all(pvRetention > 0));
assert(all(batteryRetention > 0));

fprintf('\n=== EQUIPMENT DEGRADATION TRAJECTORIES ===\n');

disp(degradationTable);

fprintf('Equipment degradation verification PASSED.\n');


%% 19. Verify degraded hourly energy simulation
% Test the 5 kWh battery-only configuration
% in the first and final years of the analysis.

testBattery_kWh = 5;
testYears = [1, lifecycle.horizonYears];

testResults = zeros(numel(testYears),5);

for k = 1:numel(testYears)

    t = testYears(k);

    %% 19.1 Degrade PV production

    degradedPV_kWh = ...
        solarAged_kWh * pvRetention(t);

    %% 19.2 Configure degraded battery

    batteryTest.capacity_kWh = ...
        testBattery_kWh * batteryRetention(t);

    batteryTest.maxChargePower_kW = 5;
    batteryTest.maxDischargePower_kW = 5;
    batteryTest.roundTripEfficiency = 0.90;

    % Start each simulated year with an empty battery
    batteryTest.initialSOC_kWh = 0;

    %% 19.3 Run existing battery dispatch model

    testSimulation = sim.calculateBatteryDispatch( ...
        demandHourly_kWh, ...
        degradedPV_kWh, ...
        batteryTest);

    %% 19.4 Store annual results

    testResults(k,:) = [ ...
        calendarYears(t), ...
        sum(degradedPV_kWh), ...
        batteryTest.capacity_kWh, ...
        sum(testSimulation.gridImport_kWh), ...
        sum(testSimulation.gridExport_kWh)];

end

%% 19.5 Create results table

degradedSimulationTest = array2table( ...
    testResults, ...
    'VariableNames', { ...
    'CalendarYear', ...
    'AnnualPV_kWh', ...
    'BatteryCapacity_kWh', ...
    'AnnualImports_kWh', ...
    'AnnualExports_kWh'});

%% 19.6 Verify degraded simulation

assert(all(isfinite(testResults),'all'));

% PV production must decline over time
assert(testResults(2,2) < testResults(1,2));

% Battery capacity must be lower in the final year
assert(testResults(2,3) < testResults(1,3));

% Grid energy flows must remain nonnegative
assert(all(testResults(:,4) >= 0));
assert(all(testResults(:,5) >= 0));

% Battery SOC must remain within physical limits
assert(all(testSimulation.stateOfCharge_kWh >= -1e-8));

assert(all( ...
    testSimulation.stateOfCharge_kWh <= ...
    batteryTest.capacity_kWh + 1e-8));

fprintf('\n=== DEGRADED HOURLY SIMULATION TEST ===\n');

disp(degradedSimulationTest);

fprintf('Degraded hourly simulation verification PASSED.\n');

%% 20. Full 20-year degraded energy simulation
% Simulate all 15 configurations over 20 years.
% Existing and added PV degrade at 0.5% annually.
% Battery usable capacity fades at 2% annually,
% with no modeled replacement.

nScenarios = height(referenceComparison);
T = lifecycle.horizonYears;

annualImports = zeros(nScenarios,T);
annualExports = zeros(nScenarios,T);
hourlyImports20Year = zeros(8760,nScenarios,T);
hourlyExports20Year = zeros(8760,nScenarios,T);
annualPVGeneration = zeros(nScenarios,T);
annualBatteryCapacity = zeros(nScenarios,T);

% New panels use the undegraded PVWatts reference profile.
% Existing panels retain their accumulated pre-2027 degradation.
referencePVPerKW = solarReference_kWh / pv.referenceCapacity_kW;

for t = 1:T

    for i = 1:nScenarios

        addedPV = referenceComparison.AddedPV_kW(i);
        nominalBattery = ...
            referenceComparison.BatteryCapacity_kWh(i);

        %% 20.1 Calculate degraded PV generation

        % Existing and added PV begin at different degradation states.
        % Both experience the same future annual degradation rate.

        existingPVYear_kWh = solarAged_kWh * pvRetention(t);
    
        addedPVYear_kWh = ...
            referencePVPerKW * addedPV * pvRetention(t);

        totalPV_kWh = existingPVYear_kWh + addedPVYear_kWh;

        %% 20.2 Calculate degraded battery capacity

        usableBatteryCapacity = ...
            nominalBattery * batteryRetention(t);

        %% 20.3 Simulate hourly energy flows

        if nominalBattery == 0

            annualSimulation = sim.calculateEnergyFlows( ...
                demandHourly_kWh, totalPV_kWh);

        else

            batteryYear.capacity_kWh = ...
                usableBatteryCapacity;

            batteryYear.maxChargePower_kW = 5;
            batteryYear.maxDischargePower_kW = 5;
            batteryYear.roundTripEfficiency = 0.90;
            batteryYear.initialSOC_kWh = 0;

            annualSimulation = sim.calculateBatteryDispatch( ...
                demandHourly_kWh, ...
                totalPV_kWh, ...
                batteryYear);

            % Verify battery physical limits
            assert(all( ...
                annualSimulation.stateOfCharge_kWh >= -1e-8));

            assert(all( ...
                annualSimulation.stateOfCharge_kWh <= ...
                usableBatteryCapacity + 1e-8));

        end

        %% 20.4 Store annual results

        hourlyImports20Year(:,i,t) = ...
            annualSimulation.gridImport_kWh;

        hourlyExports20Year(:,i,t) = ...
            annualSimulation.gridExport_kWh;
        
        annualImports(i,t) = ...
            sum(annualSimulation.gridImport_kWh);

        annualExports(i,t) = ...
            sum(annualSimulation.gridExport_kWh);

        annualPVGeneration(i,t) = ...
            sum(totalPV_kWh);

        annualBatteryCapacity(i,t) = ...
            usableBatteryCapacity;

    end
end

%% 20.5 Verification

assert(all(isfinite(annualImports),'all'));
assert(all(isfinite(annualExports),'all'));

assert(all(annualImports >= 0,'all'));
assert(all(annualExports >= 0,'all'));

% Baseline 2027 must reproduce original PV-only results
assert(abs(annualImports(baseIdx,1) - ...
    sum(baseline.gridImport_kWh)) < 1e-6);

assert(abs(annualExports(baseIdx,1) - ...
    sum(baseline.gridExport_kWh)) < 1e-6);

% PV generation must decline for every scenario
assert(all(diff(annualPVGeneration,1,2) < 0,'all'));

% Battery capacity must decline continuously for battery scenarios.
batteryCases = referenceComparison.BatteryCapacity_kWh > 0;
assert(all(diff(annualBatteryCapacity(batteryCases,:),1,2) < 0,'all'));

fprintf('\n=== FULL 20-YEAR ENERGY SIMULATION ===\n');

fprintf('Scenario-year simulations completed: %d\n', ...
    nScenarios*T);

fprintf('Baseline imports, 2027: %.1f kWh\n', ...
    annualImports(baseIdx,1));

fprintf('Baseline imports, 2046: %.1f kWh\n', ...
    annualImports(baseIdx,end));

fprintf('Baseline exports, 2027: %.1f kWh\n', ...
    annualExports(baseIdx,1));

fprintf('Baseline exports, 2046: %.1f kWh\n', ...
    annualExports(baseIdx,end));

fprintf('Full 20-year energy simulation verification PASSED.\n');


%% 20.6 Verify PV expansion against original model

% In 2027, degraded lifecycle simulations should match
% the original technical model before future degradation.

firstYearPV = annualPVGeneration(:,1);

originalPV = retrofitComparison.Generation_kWh;

maxPVError = max(abs(firstYearPV - originalPV));

assert(maxPVError < 1e-6, ...
    'First-year PV generation does not match original model.');

% First-year imports and exports should also match.
maxImportError = max(abs( ...
    annualImports(:,1) - retrofitComparison.GridImports_kWh));

maxExportError = max(abs( ...
    annualExports(:,1) - retrofitComparison.GridExports_kWh));

assert(maxImportError < 1e-6, ...
    'First-year imports do not match original model.');

assert(maxExportError < 1e-6, ...
    'First-year exports do not match original model.');

fprintf('\n=== PV EXPANSION CONSISTENCY CHECK ===\n');

fprintf('Maximum PV generation difference: %.10f kWh\n', ...
    maxPVError);

fprintf('Maximum grid import difference: %.10f kWh\n', ...
    maxImportError);

fprintf('Maximum grid export difference: %.10f kWh\n', ...
    maxExportError);

fprintf('PV expansion consistency verification PASSED.\n');


%% 21. Verify hourly data for lifecycle economics

% Check dimensions
assert(isequal(size(hourlyImports20Year), ...
    [8760,nScenarios,T]));

assert(isequal(size(hourlyExports20Year), ...
    [8760,nScenarios,T]));

% Verify hourly sums reproduce annual totals
importsFromHourly = ...
    reshape(sum(hourlyImports20Year,1),nScenarios,T);

exportsFromHourly = ...
    reshape(sum(hourlyExports20Year,1),nScenarios,T);

assert(max(abs( ...
    importsFromHourly(:)-annualImports(:))) < 1e-6);

assert(max(abs( ...
    exportsFromHourly(:)-annualExports(:))) < 1e-6);

% Verify all flows are physically valid
assert(all(isfinite(hourlyImports20Year(:))));
assert(all(isfinite(hourlyExports20Year(:))));

assert(all(hourlyImports20Year(:) >= 0));
assert(all(hourlyExports20Year(:) >= 0));

% Compare baseline and 5 kWh battery in selected years
battery5Idx = find( ...
    referenceComparison.AddedPV_kW == 0 & ...
    referenceComparison.BatteryCapacity_kWh == 5);

assert(isscalar(battery5Idx));

selectedYears = unique([1, ceil(T/2), T]);

fprintf('\n=== LIFECYCLE HOURLY DATA VERIFICATION ===\n');

for t = selectedYears

    fprintf('\nYear %d:\n',calendarYears(t));

    fprintf('Baseline imports: %.1f kWh\n', ...
        annualImports(baseIdx,t));

    fprintf('5 kWh battery imports: %.1f kWh\n', ...
        annualImports(battery5Idx,t));

    fprintf('Baseline exports: %.1f kWh\n', ...
        annualExports(baseIdx,t));

    fprintf('5 kWh battery exports: %.1f kWh\n', ...
        annualExports(battery5Idx,t));

end

fprintf('\nLifecycle hourly data verification PASSED.\n');

%% 22. Calculate 20-year NEM and NBT operating costs
% Uses the existing simplified billing functions.
% Holds the reference hourly tariff schedules constant
% in real dollars across the 20-year analysis.
%
% These are scenario estimates, not verified utility bills.

nScenarios = height(referenceComparison);
T = lifecycle.horizonYears;

annualNEM1Cost = zeros(nScenarios,T);
annualNEM2Cost = zeros(nScenarios,T);
annualNBTCost = zeros(nScenarios,T);

for t = 1:T

    for i = 1:nScenarios

        % Retrieve degraded hourly energy exchanges
        imports = hourlyImports20Year(:,i,t);
        exports = hourlyExports20Year(:,i,t);

        % NEM 1.0
        nem1Result = econ.calculateNEMBill( ...
            imports, exports, ...
            nemImportRates, economicCalendar, 1, ...
            nbcRate_perkWh=nem1NBC_perkWh, ...
            nscRate_perkWh=nscRate_perkWh, ...
            fixedAnnualCharge=fixedAnnualCharge);

        % NEM 2.0
        nem2Result = econ.calculateNEMBill( ...
            imports, exports, ...
            nemImportRates, economicCalendar, 2, ...
            nbcRate_perkWh=nem2NBC_perkWh, ...
            nscRate_perkWh=nscRate_perkWh, ...
            fixedAnnualCharge=fixedAnnualCharge);

        % Net Billing Tariff (NBT)
        nbtResult = econ.calculateNBTBill( ...
            imports, exports, ...
            nbtImportRates, nbtExportRates, nbtCalendar, ...
            nbcRate_perkWh=nbtNBC_perkWh, ...
            fixedAnnualCharge=fixedAnnualCharge);

        % Store annual costs
        annualNEM1Cost(i,t) = nem1Result.annualCost;
        annualNEM2Cost(i,t) = nem2Result.annualCost;
        annualNBTCost(i,t) = nbtResult.annualCost;

    end
end

%% 22.1 Verify billing results

assert(all(isfinite(annualNEM1Cost(:))));
assert(all(isfinite(annualNEM2Cost(:))));
assert(all(isfinite(annualNBTCost(:))));

assert(all(annualNEM1Cost(:) >= 0));
assert(all(annualNEM2Cost(:) >= 0));
assert(all(annualNBTCost(:) >= 0));

% First-year costs must reproduce original billing model
tolBill = 1e-6;

assert(max(abs(annualNEM1Cost(:,1) - ...
    economicComparison.NEM1_AnnualCost)) < tolBill);

assert(max(abs(annualNEM2Cost(:,1) - ...
    economicComparison.NEM2_AnnualCost)) < tolBill);

assert(max(abs(annualNBTCost(:,1) - ...
    economicComparison.NBT_AnnualCost)) < tolBill);

%% 22.2 Display selected results

battery5Idx = find( ...
    referenceComparison.AddedPV_kW == 0 & ...
    referenceComparison.BatteryCapacity_kWh == 5);

selectedYears = unique([1, ceil(T/2), T]);

fprintf('\n=== 20-YEAR UTILITY COST VERIFICATION ===\n');

fprintf('Scenario-year billing calculations: %d\n', ...
    nScenarios*T*3);

for t = selectedYears

    fprintf('\nYear %d:\n',calendarYears(t));

    fprintf('Baseline NEM1: $%.2f\n', ...
        annualNEM1Cost(baseIdx,t));

    fprintf('5 kWh battery NEM1: $%.2f\n', ...
        annualNEM1Cost(battery5Idx,t));

    fprintf('Baseline NBT: $%.2f\n', ...
        annualNBTCost(baseIdx,t));

    fprintf('5 kWh battery NBT: $%.2f\n', ...
        annualNBTCost(battery5Idx,t));

end

fprintf('\n20-year utility cost verification PASSED.\n');

%% 23. Degradation- and tariff-adjusted lifecycle NPV
% 2027-2046 analysis.
% Existing NEM expiration uses the configured interconnection year.
% NEM eligibility is determined by the existing screening assumption.
%
% Uses year-specific hourly simulation and billing results.

nScenarios = height(referenceComparison);
T = lifecycle.horizonYears;

annualLifecycleCost = zeros(nScenarios,T);
annualLifecycleBaselineCost = zeros(1,T);
annualLifecycleSavings = zeros(nScenarios,T);

cashFlowsDegraded = zeros(nScenarios,T);
npvDegraded = zeros(nScenarios,1);

% Confirm calendar dimensions
assert(numel(calendarYears) == T);

% Identify baseline
baselineIdx = find( ...
    referenceComparison.AddedPV_kW == 0 & ...
    referenceComparison.BatteryCapacity_kWh == 0);

assert(isscalar(baselineIdx));

%% 23.1 Select tariff program for each scenario-year

for t = 1:T

    year = calendarYears(t);

    % No-retrofit baseline retains NEM until expiration.
    if year < nemExpirationYear
        baselineCost = annualNEM1Cost(baselineIdx,t);
    else
        baselineCost = annualNBTCost(baselineIdx,t);
    end

    annualLifecycleBaselineCost(t) = baselineCost;

    for i = 1:nScenarios

        if year < nemExpirationYear && ...
                referenceComparison.PreservesExistingNEM(i)
            % Eligible retrofit retains existing NEM until expiration.
            scenarioCost = annualNEM1Cost(i,t);
        else
            scenarioCost = annualNBTCost(i,t);
        end

        annualLifecycleCost(i,t) = scenarioCost;

        annualLifecycleSavings(i,t) = ...
            baselineCost - scenarioCost;

    end
end

%% 23.2 Calculate discounted lifecycle cash flows

discountRate = lifecycle.realDiscountRate;

for i = 1:nScenarios

    addedPV = referenceComparison.AddedPV_kW(i);
    batteryCapacity = ...
        referenceComparison.BatteryCapacity_kWh(i);

    % Initial investment at the start of 2027
    initialCost = ...
        addedPV * 1000 * lifecycle.pvCostPerW + ...
        batteryCapacity * lifecycle.batteryCostPerKWh;

    % Annual maintenance of added PV capacity
    annualOM = addedPV * lifecycle.pvOMPerKWYear;

    npv = -initialCost;

    
for t = 1:T

    % Annual operating savings and PV maintenance occur
    % at the end of each year.
    annualCashFlow = ...
        annualLifecycleSavings(i,t) - annualOM;
    cashFlowsDegraded(i,t) = annualCashFlow;

    npv = npv + annualCashFlow / ...
        (1 + discountRate)^t;

end


    npvDegraded(i) = npv;

end

%% 23.3 Store results

referenceComparison.NPV_Degraded = npvDegraded;

referenceComparison.Total20YearSavings = ...
    sum(annualLifecycleSavings,2);

%% 23.4 Verification

assert(all(isfinite(npvDegraded)));

% No retrofit must have zero incremental NPV
assert(abs(npvDegraded(baselineIdx)) < 1e-8);

% No retrofit must have zero annual savings
assert(all(abs( ...
    annualLifecycleSavings(baselineIdx,:)) < 1e-8));

% Verify first-year battery-only savings against the tariff actually
% applicable in the first analysis year. An expired NEM term means NBT.
battery5Idx = find( ...
    referenceComparison.AddedPV_kW == 0 & ...
    referenceComparison.BatteryCapacity_kWh == 5);

assert(isscalar(battery5Idx));

if calendarYears(1) < nemExpirationYear && ...
        referenceComparison.PreservesExistingNEM(battery5Idx)
    expectedFirstYearSavings = ...
        economicComparison.NEM1_AnnualSavings(battery5Idx);
else
    expectedFirstYearSavings = ...
        economicComparison.NBT_AnnualCost(baselineIdx) - ...
        economicComparison.NBT_AnnualCost(battery5Idx);
end

assert(abs( ...
    annualLifecycleSavings(battery5Idx,1) - ...
    expectedFirstYearSavings) < 1e-6, ...
    'First-year battery savings do not match the applicable tariff.');

%% 23.5 Rank retrofit strategies

[sortedNPV,sortIdx] = sort(npvDegraded,'descend');

fprintf('\n=== DEGRADATION-ADJUSTED LIFECYCLE NPV ===\n');

fprintf('Analysis period: %d-%d\n', ...
    calendarYears(1),calendarYears(end));

fprintf('Assumed NEM expiration: %d\n',nemExpirationYear);

fprintf('Real discount rate: %.1f%%\n', ...
    100*discountRate);

fprintf('\n');

rankedResults = table( ...
    referenceComparison.AddedPV_kW(sortIdx), ...
    referenceComparison.BatteryCapacity_kWh(sortIdx), ...
    sortedNPV, ...
    'VariableNames', { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    'NPV_Degraded'});

disp(rankedResults);

fprintf('Baseline NPV: $%.2f\n', ...
    npvDegraded(baselineIdx));

fprintf('5 kWh battery NPV: $%.2f\n', ...
    npvDegraded(battery5Idx));

fprintf('\nDegradation-adjusted lifecycle NPV verification PASSED.\n');

%% 24. Battery installed-cost break-even analysis
% Find the installed battery cost ($/kWh) that produces
% zero lifecycle NPV for each battery-only retrofit.
%
% No replacement costs are included (out of scope).

batteryOnlyIdx = find( ...
    referenceComparison.AddedPV_kW == 0 & ...
    referenceComparison.BatteryCapacity_kWh > 0);

nBatteryCases = numel(batteryOnlyIdx);

batteryBreakEvenCost = zeros(nBatteryCases,1);
batteryCurrentNPV = zeros(nBatteryCases,1);

discountRate = lifecycle.realDiscountRate;

for k = 1:nBatteryCases

    i = batteryOnlyIdx(k);

    batteryCapacity = ...
        referenceComparison.BatteryCapacity_kWh(i);

    % Present value of operating savings
    pvSavings = 0;

    for t = 1:lifecycle.horizonYears

        pvSavings = pvSavings + ...
            annualLifecycleSavings(i,t) / ...
            (1 + discountRate)^t;

    end

    % Initial installed battery cost only.
    totalCostFactor = batteryCapacity;

    batteryBreakEvenCost(k) = ...
        pvSavings / totalCostFactor;

    batteryCurrentNPV(k) = ...
        referenceComparison.NPV_Degraded(i);

end

batteryBreakEvenTable = table( ...
    referenceComparison.BatteryCapacity_kWh(batteryOnlyIdx), ...
    batteryCurrentNPV, ...
    batteryBreakEvenCost, ...
    'VariableNames', { ...
    'BatteryCapacity_kWh', ...
    'CurrentNPV', ...
    'BreakEvenInstalledCost_perkWh'});

%% 24.1 Verify break-even calculation

assert(all(isfinite(batteryBreakEvenCost)));
assert(all(batteryBreakEvenCost >= 0));

% Recalculate NPV at the calculated break-even cost.
for k = 1:nBatteryCases

    i = batteryOnlyIdx(k);

    capacity = ...
        referenceComparison.BatteryCapacity_kWh(i);

    testCost = batteryBreakEvenCost(k);
    pvSavings = sum( ...
        annualLifecycleSavings(i,:) ./ ...
        (1 + discountRate).^(1:lifecycle.horizonYears));

    testNPV = pvSavings - ...
        capacity * testCost;

    assert(abs(testNPV) < 1e-6);

end

fprintf('\n=== DEGRADATION-ADJUSTED BATTERY BREAK-EVEN ===\n');

disp(batteryBreakEvenTable);

fprintf('Battery break-even verification PASSED.\n');

%% 25. Sensitivity to existing NEM expiration year
% Compare lifecycle NPV under different transition years.
% Retrofit scenarios use the same NEM eligibility screen as the base case.
% Eligible configurations retain NEM1
% until the specified expiration year.

% Keep sensitivity years distinct even when the original term expired
% before the analysis start year. Pre-2027 years are valid: NBT applies
% throughout the modeled horizon for those cases.
expirationYears = nemExpirationYear + [-4 0 4 13];

nExpirationCases = numel(expirationYears);
nScenarios = height(referenceComparison);
T = lifecycle.horizonYears;

npvByExpiration = zeros(nScenarios,nExpirationCases);

discountRate = lifecycle.realDiscountRate;

for e = 1:nExpirationCases

    expirationYear = expirationYears(e);

    for i = 1:nScenarios

        addedPV = referenceComparison.AddedPV_kW(i);
        batteryCapacity = ...
            referenceComparison.BatteryCapacity_kWh(i);

        initialCost = ...
            addedPV * 1000 * lifecycle.pvCostPerW + ...
            batteryCapacity * lifecycle.batteryCostPerKWh;

        annualOM = addedPV * lifecycle.pvOMPerKWYear;

        npv = -initialCost;

        for t = 1:T

            year = calendarYears(t);

            % Baseline tariff
            if year < expirationYear
                baselineCost = annualNEM1Cost(baselineIdx,t);
            else
                baselineCost = annualNBTCost(baselineIdx,t);
            end

            % Retrofit tariff
            if year < expirationYear && ...
                    referenceComparison.PreservesExistingNEM(i)
                scenarioCost = annualNEM1Cost(i,t);
            else
                scenarioCost = annualNBTCost(i,t);
            end

            annualSavings = baselineCost - scenarioCost;

            annualCashFlow = annualSavings - annualOM;

            npv = npv + annualCashFlow / ...
                (1 + discountRate)^t;

        end

        npvByExpiration(i,e) = npv;

    end
end

%% 25.1 Verify sensitivity results

assert(all(isfinite(npvByExpiration(:))));

% Baseline must always have zero incremental NPV
assert(all(abs(npvByExpiration(baselineIdx,:)) < 1e-8));

% The configured expiration case must reproduce base-case results
currentCase = find(expirationYears == nemExpirationYear);

assert(isscalar(currentCase));

assert(max(abs( ...
    npvByExpiration(:,currentCase) - ...
    referenceComparison.NPV_Degraded)) < 1e-6);

%% 25.2 Display selected configurations

battery5Idx = find( ...
    referenceComparison.AddedPV_kW == 0 & ...
    referenceComparison.BatteryCapacity_kWh == 5);

battery10Idx = find( ...
    referenceComparison.AddedPV_kW == 0 & ...
    referenceComparison.BatteryCapacity_kWh == 10);

pv2Battery5Idx = find( ...
    referenceComparison.AddedPV_kW == 2 & ...
    referenceComparison.BatteryCapacity_kWh == 5);

selectedIdx = [baselineIdx; ...
    battery5Idx; battery10Idx; pv2Battery5Idx];

expirationSensitivityTable = table( ...
    referenceComparison.AddedPV_kW(selectedIdx), ...
    referenceComparison.BatteryCapacity_kWh(selectedIdx), ...
    npvByExpiration(selectedIdx,1), ...
    npvByExpiration(selectedIdx,2), ...
    npvByExpiration(selectedIdx,3), ...
    npvByExpiration(selectedIdx,4), ...
    'VariableNames', { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    sprintf('NPV_Expire%d',expirationYears(1)), ...
    sprintf('NPV_Expire%d',expirationYears(2)), ...
    sprintf('NPV_Expire%d',expirationYears(3)), ...
    sprintf('NPV_Expire%d',expirationYears(4))});

fprintf('\n=== NEM EXPIRATION SENSITIVITY ===\n');

disp(expirationSensitivityTable);

fprintf('NEM expiration sensitivity verification PASSED.\n');

%% 26. Electricity rate escalation sensitivity
% Evaluate real electricity rate escalation from -1% to +3%.
%
% Uses existing 20-year degradation-adjusted energy
% simulations and the configured NEM-to-NBT transition.
%
% Assumption: all variable utility costs and associated
% energy savings scale with the same escalation factor.
% Capital costs,  PV maintenance
% remain in constant real dollars.

rateEscalationCases = [-0.01 0 0.01 0.02 0.03];

nRateCases = numel(rateEscalationCases);
nScenarios = height(referenceComparison);
T = lifecycle.horizonYears;

npvByRateEscalation = zeros(nScenarios,nRateCases);

discountRate = lifecycle.realDiscountRate;

for r = 1:nRateCases

    escalationRate = rateEscalationCases(r);

    for i = 1:nScenarios

        addedPV = referenceComparison.AddedPV_kW(i);

        batteryCapacity = ...
            referenceComparison.BatteryCapacity_kWh(i);

        initialCost = ...
            addedPV * 1000 * lifecycle.pvCostPerW + ...
            batteryCapacity * lifecycle.batteryCostPerKWh;

        annualOM = addedPV * lifecycle.pvOMPerKWYear;

        npv = -initialCost;

        for t = 1:T

            % Escalation relative to first analysis year
            escalationFactor = ...
                (1 + escalationRate)^(t-1);

            % Scale incremental utility savings
            escalatedSavings = ...
                annualLifecycleSavings(i,t) * ...
                escalationFactor;

            annualCashFlow = ...
                escalatedSavings - annualOM;

            % Discount end-of-year operating cash flow
            npv = npv + annualCashFlow / ...
                (1 + discountRate)^t;

        end

        npvByRateEscalation(i,r) = npv;

    end
end

%% 26.1 Verification

assert(all(isfinite(npvByRateEscalation(:))));

% Baseline NPV should always be zero
assert(all(abs( ...
    npvByRateEscalation(baselineIdx,:)) < 1e-8));

% Zero escalation must reproduce Step 41 exactly
zeroEscalationIdx = find(rateEscalationCases == 0);

assert(isscalar(zeroEscalationIdx));

assert(max(abs( ...
    npvByRateEscalation(:,zeroEscalationIdx) - ...
    referenceComparison.NPV_Degraded)) < 1e-6);

%% 26.2 Selected scenario comparison

battery5Idx = find( ...
    referenceComparison.AddedPV_kW == 0 & ...
    referenceComparison.BatteryCapacity_kWh == 5);

battery10Idx = find( ...
    referenceComparison.AddedPV_kW == 0 & ...
    referenceComparison.BatteryCapacity_kWh == 10);

pv2Battery5Idx = find( ...
    referenceComparison.AddedPV_kW == 2 & ...
    referenceComparison.BatteryCapacity_kWh == 5);

selectedIdx = [baselineIdx; ...
    battery5Idx; battery10Idx; pv2Battery5Idx];

rateSensitivityTable = table( ...
    referenceComparison.AddedPV_kW(selectedIdx), ...
    referenceComparison.BatteryCapacity_kWh(selectedIdx), ...
    npvByRateEscalation(selectedIdx,1), ...
    npvByRateEscalation(selectedIdx,2), ...
    npvByRateEscalation(selectedIdx,3), ...
    npvByRateEscalation(selectedIdx,4), ...
    npvByRateEscalation(selectedIdx,5), ...
    'VariableNames', { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    'NPV_Minus1pct', ...
    'NPV_ZeroPct', ...
    'NPV_Plus1pct', ...
    'NPV_Plus2pct', ...
    'NPV_Plus3pct'});

fprintf('\n=== ELECTRICITY RATE ESCALATION SENSITIVITY ===\n');

disp(rateSensitivityTable);

fprintf('Rate escalation sensitivity verification PASSED.\n');

%% 27. Combined battery cost and electricity rate sensitivity
% Evaluate the 5 kWh battery under different installed
% costs and real electricity rate escalation assumptions.
%
% The battery's hourly operation and degradation remain
% unchanged. Battery replacement is excluded from this model.

batteryCostCases = 500:100:1200;
rateEscalationCases2D = [-0.01 0 0.01 0.02 0.03];

nCostCases = numel(batteryCostCases);
nRateCases = numel(rateEscalationCases2D);

battery5Idx = find( ...
    referenceComparison.AddedPV_kW == 0 & ...
    referenceComparison.BatteryCapacity_kWh == 5);

assert(isscalar(battery5Idx));

batteryCapacity = ...
    referenceComparison.BatteryCapacity_kWh(battery5Idx);

discountRate = lifecycle.realDiscountRate;
T = lifecycle.horizonYears;

npvCostRateMatrix = zeros(nCostCases,nRateCases);

for c = 1:nCostCases

    installedCostPerKWh = batteryCostCases(c);

    initialCost = ...
        batteryCapacity * installedCostPerKWh;

    for r = 1:nRateCases

        escalationRate = rateEscalationCases2D(r);

        npv = -initialCost;

        for t = 1:T

            escalationFactor = ...
                (1 + escalationRate)^(t-1);

            annualSavings = ...
                annualLifecycleSavings(battery5Idx,t) * ...
                escalationFactor;

            npv = npv + annualSavings / ...
                (1 + discountRate)^t;

        end

        npvCostRateMatrix(c,r) = npv;

    end
end

%% 27.1 Verification

assert(all(isfinite(npvCostRateMatrix(:))));

% The $1000/kWh, 0% case must match the base NPV
baseCostIdx = find(batteryCostCases == ...
    lifecycle.batteryCostPerKWh);

baseRateIdx = find(rateEscalationCases2D == 0);

assert(isscalar(baseCostIdx));
assert(isscalar(baseRateIdx));

assert(abs( ...
    npvCostRateMatrix(baseCostIdx,baseRateIdx) - ...
    referenceComparison.NPV_Degraded(battery5Idx)) < 1e-6);

% $1000/kWh cases must match Step 44
assert(max(abs( ...
    npvCostRateMatrix(baseCostIdx,:) - ...
    npvByRateEscalation(battery5Idx,:))) < 1e-6);

%% 27.2 Display NPV matrix

combinedSensitivityTable = array2table( ...
    npvCostRateMatrix, ...
    'VariableNames', { ...
    'RateMinus1pct', ...
    'RateZeroPct', ...
    'RatePlus1pct', ...
    'RatePlus2pct', ...
    'RatePlus3pct'});

combinedSensitivityTable = addvars( ...
    combinedSensitivityTable, ...
    batteryCostCases(:), ...
    'Before',1, ...
    'NewVariableNames','BatteryCost_perkWh');

fprintf('\n=== COMBINED BATTERY COST AND RATE SENSITIVITY ===\n');

disp(combinedSensitivityTable);

fprintf('Combined sensitivity verification PASSED.\n');

%% 28. Household energy-efficiency sensitivity
% Evaluate uniform reductions in hourly household demand.
% Reductions of 5%, 10%, and 15% are hypothetical.
%
% The existing aged PV system remains unchanged.
% No battery or additional PV is installed.
%
% Results represent gross present value of utility
% savings, before efficiency retrofit investment costs.

efficiencyReductionCases = [0.05 0.10 0.15];

nEfficiencyCases = numel(efficiencyReductionCases);
T = lifecycle.horizonYears;

efficiencyAnnualSavings = zeros(nEfficiencyCases,T);
efficiencyPresentValue = zeros(nEfficiencyCases,1);

efficiencyAnnualImports = zeros(nEfficiencyCases,T);
efficiencyAnnualExports = zeros(nEfficiencyCases,T);

discountRate = lifecycle.realDiscountRate;

referencePVPerKW = solarReference_kWh / pv.referenceCapacity_kW;

for e = 1:nEfficiencyCases

    reductionFraction = efficiencyReductionCases(e);

    % Uniform reduction in every hourly demand value
    efficientDemand_kWh = ...
        demandHourly_kWh * (1 - reductionFraction);

    for t = 1:T

        year = calendarYears(t);

        % Existing PV degradation
        existingPVYear_kWh = ...
            solarAged_kWh * pvRetention(t);

        % Recalculate hourly energy flows
        efficiencyFlows = sim.calculateEnergyFlows( ...
            efficientDemand_kWh, ...
            existingPVYear_kWh);

        imports = efficiencyFlows.gridImport_kWh;
        exports = efficiencyFlows.gridExport_kWh;

        efficiencyAnnualImports(e,t) = sum(imports);
        efficiencyAnnualExports(e,t) = sum(exports);

        % Calculate bill using applicable tariff
        if year < nemExpirationYear

            bill = econ.calculateNEMBill( ...
                imports, exports, ...
                nemImportRates, economicCalendar, 1, ...
                nbcRate_perkWh=nem1NBC_perkWh, ...
                nscRate_perkWh=nscRate_perkWh, ...
                fixedAnnualCharge=fixedAnnualCharge);

            baselineCost = annualNEM1Cost(baselineIdx,t);

        else

            bill = econ.calculateNBTBill( ...
                imports, exports, ...
                nbtImportRates, nbtExportRates, ...
                nbtCalendar, ...
                nbcRate_perkWh=nbtNBC_perkWh, ...
                fixedAnnualCharge=fixedAnnualCharge);

            baselineCost = annualNBTCost(baselineIdx,t);

        end

        efficiencyAnnualSavings(e,t) = ...
            baselineCost - bill.annualCost;

    end

    % Present value of gross utility savings
    efficiencyPresentValue(e) = sum( ...
        efficiencyAnnualSavings(e,:) ./ ...
        (1 + discountRate).^(1:T));

end

%% 28.1 Verification

assert(all(isfinite(efficiencyPresentValue)));

assert(all(efficiencyAnnualImports(:) >= 0));
assert(all(efficiencyAnnualExports(:) >= 0));

% Efficiency reductions must not increase grid imports
for e = 1:nEfficiencyCases

    assert(all( ...
        efficiencyAnnualImports(e,:) <= ...
        annualImports(baselineIdx,:) + 1e-6));

end

% Larger uniform reductions should not increase imports
assert(all(diff(efficiencyAnnualImports,1,1) <= 1e-6,'all'));

%% 28.2 Results table

efficiencyResults = table( ...
    efficiencyReductionCases(:)*100, ...
    efficiencyAnnualSavings(:,1), ...
    efficiencyPresentValue, ...
    efficiencyPresentValue, ...
    'VariableNames', { ...
    'DemandReduction_pct', ...
    'FirstYearSavings', ...
    'PV_Gross20YearSavings', ...
    'BreakEvenUpfrontCost'});

fprintf('\n=== HOUSEHOLD EFFICIENCY SENSITIVITY ===\n');

disp(efficiencyResults);

fprintf('Efficiency sensitivity verification PASSED.\n');

%% 29. Household load-shifting sensitivity
% Shift electricity demand from 5-9 PM to 10 AM-2 PM.
%
% Daily total energy consumption is conserved.
% No additional PV or battery is installed.
%
% The results represent gross utility savings before
% implementation costs.

dailyShiftCases_kWh = [1 2 3];

nShiftCases = numel(dailyShiftCases_kWh);
T = lifecycle.horizonYears;

nHours = numel(demandHourly_kWh);

assert(nHours == 8760);

% Hour indices for a standard 365-day year
% Assumes demandHourly_kWh is chronological, starting
% at midnight January 1, with 24 values per day.
%
% MATLAB indices:
% 10 AM-2 PM corresponds to hours 11:14.
% 5 PM-9 PM corresponds to hours 18:21.

daytimeHours = 11:14;
eveningHours = 18:21;

nDays = 365;

shiftedDemandProfiles = zeros(nHours,nShiftCases);

actualShiftedEnergy_kWh = zeros(nShiftCases,1);

for s = 1:nShiftCases

    requestedDailyShift = dailyShiftCases_kWh(s);

    shiftedDemand = demandHourly_kWh;

    totalShiftedEnergy = 0;

    for d = 1:nDays

        dayStart = (d-1)*24;

        eveningIdx = dayStart + eveningHours;
        daytimeIdx = dayStart + daytimeHours;

        eveningDemand = shiftedDemand(eveningIdx);

        availableEveningEnergy = sum(eveningDemand);

        % Cannot shift more energy than exists
        actualDailyShift = min( ...
            requestedDailyShift, ...
            availableEveningEnergy);

        if availableEveningEnergy > 0

            % Remove energy proportionally from evening
            removalFraction = ...
                actualDailyShift / availableEveningEnergy;

            shiftedDemand(eveningIdx) = ...
                eveningDemand * (1-removalFraction);

        end

        % Add the same amount to daytime hours
        shiftedDemand(daytimeIdx) = ...
            shiftedDemand(daytimeIdx) + ...
            actualDailyShift/numel(daytimeHours);

        totalShiftedEnergy = ...
            totalShiftedEnergy + actualDailyShift;

    end

    shiftedDemandProfiles(:,s) = shiftedDemand;

    actualShiftedEnergy_kWh(s) = totalShiftedEnergy;

end

%% 29.1 Verify energy conservation

for s = 1:nShiftCases

    assert(all(shiftedDemandProfiles(:,s) >= -1e-10));

    assert(abs( ...
        sum(shiftedDemandProfiles(:,s)) - ...
        sum(demandHourly_kWh)) < 1e-6);

    % Verify conservation separately for each day
    originalDaily = sum(reshape( ...
        demandHourly_kWh,24,365),1);

    shiftedDaily = sum(reshape( ...
        shiftedDemandProfiles(:,s),24,365),1);

    assert(max(abs( ...
        originalDaily-shiftedDaily)) < 1e-8);

end

%% 29.2 Calculate 20-year utility savings

loadShiftAnnualSavings = zeros(nShiftCases,T);

loadShiftAnnualImports = zeros(nShiftCases,T);
loadShiftAnnualExports = zeros(nShiftCases,T);

loadShiftPresentValue = zeros(nShiftCases,1);

discountRate = lifecycle.realDiscountRate;

for s = 1:nShiftCases

    shiftedDemand = shiftedDemandProfiles(:,s);

    for t = 1:T

        year = calendarYears(t);

        existingPVYear_kWh = ...
            solarAged_kWh * pvRetention(t);

        shiftedFlows = sim.calculateEnergyFlows( ...
            shiftedDemand, ...
            existingPVYear_kWh);

        imports = shiftedFlows.gridImport_kWh;
        exports = shiftedFlows.gridExport_kWh;

        loadShiftAnnualImports(s,t) = sum(imports);
        loadShiftAnnualExports(s,t) = sum(exports);

        if year < nemExpirationYear

            bill = econ.calculateNEMBill( ...
                imports,exports, ...
                nemImportRates,economicCalendar,1, ...
                nbcRate_perkWh=nem1NBC_perkWh, ...
                nscRate_perkWh=nscRate_perkWh, ...
                fixedAnnualCharge=fixedAnnualCharge);

            baselineCost = annualNEM1Cost(baselineIdx,t);

        else

            bill = econ.calculateNBTBill( ...
                imports,exports, ...
                nbtImportRates,nbtExportRates, ...
                nbtCalendar, ...
                nbcRate_perkWh=nbtNBC_perkWh, ...
                fixedAnnualCharge=fixedAnnualCharge);

            baselineCost = annualNBTCost(baselineIdx,t);

        end

        loadShiftAnnualSavings(s,t) = ...
            baselineCost - bill.annualCost;

    end

    loadShiftPresentValue(s) = sum( ...
        loadShiftAnnualSavings(s,:) ./ ...
        (1+discountRate).^(1:T));

end

%% 29.3 Verify results

assert(all(isfinite(loadShiftPresentValue)));

assert(all(isfinite(loadShiftAnnualSavings(:))));

%% 29.4 Display results

loadShiftResults = table( ...
    dailyShiftCases_kWh(:), ...
    actualShiftedEnergy_kWh, ...
    loadShiftAnnualSavings(:,1), ...
    loadShiftPresentValue, ...
    'VariableNames', { ...
    'RequestedShift_kWhPerDay', ...
    'ActualShift_kWhPerYear', ...
    'FirstYearSavings', ...
    'PV_Gross20YearSavings'});

fprintf('\n=== HOUSEHOLD LOAD-SHIFTING SENSITIVITY ===\n');

disp(loadShiftResults);

fprintf('Load-shifting energy conservation verification PASSED.\n');

%% 30. Consolidated decision framework summary
% Summarize the modeled alternatives.
%
% PV and battery cases have full incremental lifecycle NPV.
% Efficiency and load-shifting cases have gross discounted
% savings only because implementation costs are unknown.

%% 30.1 PV and battery retrofit comparison

retrofitDecisionTable = table( ...
    referenceComparison.AddedPV_kW, ...
    referenceComparison.BatteryCapacity_kWh, ...
    referenceComparison.NPV_Degraded, ...
    'VariableNames', { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    'LifecycleNPV'});

retrofitDecisionTable = sortrows( ...
    retrofitDecisionTable, ...
    'LifecycleNPV','descend');

%% 30.2 Efficiency comparison

efficiencyDecisionTable = table( ...
    efficiencyReductionCases(:)*100, ...
    efficiencyPresentValue, ...
    'VariableNames', { ...
    'DemandReduction_pct', ...
    'MaximumBreakEvenUpfrontCost'});

%% 30.3 Load-shifting comparison

loadShiftDecisionTable = table( ...
    dailyShiftCases_kWh(:), ...
    actualShiftedEnergy_kWh, ...
    loadShiftPresentValue, ...
    'VariableNames', { ...
    'RequestedShift_kWhPerDay', ...
    'ActualShift_kWhPerYear', ...
    'MaximumBreakEvenUpfrontCost'});

%% 30.4 Identify preferred PV/battery configuration

[bestNPV,bestIdx] = max( ...
    referenceComparison.NPV_Degraded);

bestAddedPV = ...
    referenceComparison.AddedPV_kW(bestIdx);

bestBattery = ...
    referenceComparison.BatteryCapacity_kWh(bestIdx);

%% 30.5 Verification

assert(bestNPV >= -1e-8);

assert(all(isfinite( ...
    retrofitDecisionTable.LifecycleNPV)));

assert(all(isfinite( ...
    efficiencyDecisionTable.MaximumBreakEvenUpfrontCost)));

assert(all(isfinite( ...
    loadShiftDecisionTable.MaximumBreakEvenUpfrontCost)));

%% 30.6 Display consolidated results

fprintf('\n=== FINAL RETROFIT DECISION SUMMARY ===\n');

fprintf('\nPV AND BATTERY STRATEGIES:\n');
disp(retrofitDecisionTable);

fprintf('\nENERGY EFFICIENCY STRATEGIES:\n');
disp(efficiencyDecisionTable);

fprintf('\nLOAD-SHIFTING STRATEGIES:\n');
disp(loadShiftDecisionTable);

fprintf('\nBEST PV/BATTERY DECISION:\n');

fprintf('Added PV: %.1f kW\n',bestAddedPV);
fprintf('Battery: %.1f kWh\n',bestBattery);
fprintf('20-year NPV: $%.2f\n',bestNPV);

fprintf('\nFinal decision summary verification PASSED.\n');

%% 31. Final integrated model verification
% Verify consistency across technical simulations,
% lifecycle economics, and sensitivity analyses.

fprintf('\n=== FINAL INTEGRATED MODEL VERIFICATION ===\n');

verificationNames = strings(0,1);
verificationPassed = false(0,1);

%% 31.1 Simulation dimensions

testName = "20-year simulation dimensions";

passed = ...
    size(annualImports,1) == height(referenceComparison) && ...
    size(annualImports,2) == lifecycle.horizonYears && ...
    isequal(size(annualImports),size(annualExports)) && ...
    isequal(size(annualImports),size(annualPVGeneration));

verificationNames(end+1,1) = testName;
verificationPassed(end+1,1) = passed;

%% 31.2 Nonnegative technical results

testName = "Nonnegative energy flows";

passed = ...
    all(annualImports(:) >= -1e-9) && ...
    all(annualExports(:) >= -1e-9) && ...
    all(annualPVGeneration(:) >= -1e-9);

verificationNames(end+1,1) = testName;
verificationPassed(end+1,1) = passed;

%% 31.3 First-year technical consistency

testName = "First-year technical consistency";

passed = ...
    max(abs( ...
        annualImports(:,1) - ...
        retrofitComparison.GridImports_kWh)) < 1e-6 && ...
    max(abs( ...
        annualExports(:,1) - ...
        retrofitComparison.GridExports_kWh)) < 1e-6;

verificationNames(end+1,1) = testName;
verificationPassed(end+1,1) = passed;

%% 31.4 First-year economic consistency

testName = "First-year economic consistency";

passed = ...
    max(abs( ...
        annualNEM1Cost(:,1) - ...
        economicComparison.NEM1_AnnualCost)) < 1e-6 && ...
    max(abs( ...
        annualNBTCost(:,1) - ...
        economicComparison.NBT_AnnualCost)) < 1e-6;

verificationNames(end+1,1) = testName;
verificationPassed(end+1,1) = passed;

%% 31.5 Baseline lifecycle NPV

testName = "Zero baseline incremental NPV";

passed = ...
    abs(referenceComparison.NPV_Degraded(baselineIdx)) < 1e-8;

verificationNames(end+1,1) = testName;
verificationPassed(end+1,1) = passed;

%% 31.6 Tariff transition sensitivity

testName = "Configured NEM expiration reproduces base NPV";

currentCase = find(expirationYears == nemExpirationYear);

passed = ...
    max(abs( ...
        npvByExpiration(:,currentCase) - ...
        referenceComparison.NPV_Degraded)) < 1e-6;

verificationNames(end+1,1) = testName;
verificationPassed(end+1,1) = passed;

%% 31.7 Rate escalation sensitivity

testName = "Zero escalation reproduces base NPV";

zeroRateIdx = find(rateEscalationCases == 0);

passed = ...
    max(abs( ...
        npvByRateEscalation(:,zeroRateIdx) - ...
        referenceComparison.NPV_Degraded)) < 1e-6;

verificationNames(end+1,1) = testName;
verificationPassed(end+1,1) = passed;

%% 31.8 Combined sensitivity consistency

testName = "Combined sensitivity reproduces base NPV";

baseCostIdx = find( ...
    batteryCostCases == lifecycle.batteryCostPerKWh);

baseRateIdx = find(rateEscalationCases2D == 0);

passed = ...
    abs( ...
        npvCostRateMatrix(baseCostIdx,baseRateIdx) - ...
        referenceComparison.NPV_Degraded(battery5Idx)) < 1e-6;

verificationNames(end+1,1) = testName;
verificationPassed(end+1,1) = passed;

%% 31.9 Load-shifting energy conservation

testName = "Load-shifting annual energy conservation";

passed = true;

for s = 1:numel(dailyShiftCases_kWh)

    passed = passed && ...
        abs( ...
            sum(shiftedDemandProfiles(:,s)) - ...
            sum(demandHourly_kWh)) < 1e-6;

end

verificationNames(end+1,1) = testName;
verificationPassed(end+1,1) = passed;

%% 31.10 Efficiency reduces annual grid imports

testName = "Efficiency does not increase grid imports";

passed = all( ...
    efficiencyAnnualImports <= ...
    repmat(annualImports(baselineIdx,:), ...
    numel(efficiencyReductionCases),1) + 1e-6, ...
    'all');

verificationNames(end+1,1) = testName;
verificationPassed(end+1,1) = passed;

%% 31.11 Display verification report

verificationReport = table( ...
    verificationNames, ...
    verificationPassed, ...
    'VariableNames', {'VerificationTest','Passed'});

disp(verificationReport);

nPassed = sum(verificationPassed);
nTotal = numel(verificationPassed);

fprintf('Verification tests passed: %d of %d\n', ...
    nPassed,nTotal);

assert(all(verificationPassed), ...
    'Final integrated model verification FAILED.');

fprintf('Final integrated model verification PASSED.\n');
