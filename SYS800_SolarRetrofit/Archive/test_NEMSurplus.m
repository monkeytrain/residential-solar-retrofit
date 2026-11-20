
%% Test NEM Annual Surplus and True-Up Logic

clearvars;
clc;

n = 8760;

timestamps = (datetime(2025,1,1):hours(1): ...
    datetime(2025,12,31,23,0,0))';

calendar = table(timestamps, ...
    'VariableNames',{'Timestamp'});

% Synthetic assumptions, NOT actual SCE rates
nbcRate = 0.02;
nscRate = 0.05;
fixedCharge = 288.35;

%% Test 1: Annual generation surplus

% Household exports more electricity than it imports.
imports = ones(n,1);
exports = 1.5 * ones(n,1);
rates = 0.30 * ones(n,1);

nem1 = econ.calculateNEMBill( ...
    imports,exports,rates,calendar,1, ...
    nbcRate_perkWh=nbcRate, ...
    nscRate_perkWh=nscRate, ...
    fixedAnnualCharge=fixedCharge);

nem2 = econ.calculateNEMBill( ...
    imports,exports,rates,calendar,2, ...
    nbcRate_perkWh=nbcRate, ...
    nscRate_perkWh=nscRate, ...
    fixedAnnualCharge=fixedCharge);

% Expected annual electricity quantities
assert(nem1.annualImports_kWh == 8760);
assert(nem1.annualExports_kWh == 13140);
assert(nem1.annualSurplus_kWh == 4380);

% Retail credit balance: -$1,314
assert(abs(nem1.annualRetailBalance + 1314) < 1e-8);

% Surplus compensated at $0.05/kWh, not $0.30/kWh
assert(abs(nem1.netSurplusCompensation - 219) < 1e-8);
assert(abs(nem2.netSurplusCompensation - 219) < 1e-8);

% NEM 1: zero net annual consumption
assert(abs(nem1.nonBypassableCharges) < 1e-8);

% NEM 2: non-bypassable charges on imports
assert(abs(nem2.nonBypassableCharges - 175.20) < 1e-8);

fprintf('Test 1 - Annual generation surplus: PASS\n');

%% Test 2: Positive net kWh consumption but negative dollar balance

% Household imports 1.2 kWh/hour at a low rate
% and exports 1.0 kWh/hour at a high rate.
%
% This is a synthetic mathematical edge case, not
% a realistic hourly PV dispatch profile.

imports = 1.2 * ones(n,1);
exports = ones(n,1);

% Construct separate hours with low and high TOU rates.
rates = 0.20 * ones(n,1);
rates(2:2:end) = 0.50;

% Imports occur primarily at low-rate hours;
% exports occur primarily at high-rate hours.
imports(2:2:end) = 0;
exports(1:2:end) = 0;

nemEdge = econ.calculateNEMBill( ...
    imports,exports,rates,calendar,2, ...
    nbcRate_perkWh=nbcRate, ...
    nscRate_perkWh=nscRate, ...
    fixedAnnualCharge=fixedCharge);

% More imports than exports in kWh
assert(nemEdge.annualNetConsumption_kWh > 0);

% But exported electricity is worth more in dollars
assert(nemEdge.annualRetailBalance < 0);
assert(abs(nemEdge.annualRetailBalance + 1138.80) < 1e-8);

% No net surplus compensation without annual kWh surplus
assert(nemEdge.annualSurplus_kWh == 0);
assert(nemEdge.netSurplusCompensation == 0);

fprintf('Test 2 - Negative dollar balance without kWh surplus: PASS\n');

%% Display Results

fprintf('\nAnnual surplus test:\n');
fprintf('NEM 1.0 annual cost: $%.2f\n',nem1.annualCost);
fprintf('NEM 2.0 annual cost: $%.2f\n',nem2.annualCost);

fprintf('\nTOU edge case:\n');
fprintf('Annual net consumption: %.1f kWh\n', ...
    nemEdge.annualNetConsumption_kWh);
fprintf('Annual retail balance: $%.2f\n', ...
    nemEdge.annualRetailBalance);
fprintf('Net surplus compensation: $%.2f\n', ...
    nemEdge.netSurplusCompensation);
