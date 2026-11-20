
function assumptions = loadSCEBillingAssumptions()
% LOADSCEBILLINGASSUMPTIONS
% Centralized SCE economic assumptions for the SYS 800 model.
%
% Source 1:
% SCE Net Surplus Compensation Rate
% https://www.sce.com/regulatory/regulatory-information/ferc-Standards-conduct/tariff-books/rates-pricing-choices/net-surplus-compensation
%
% Source 2:
% SCE Base Services Charge
% https://www.sce.com/save-money/rates-financing/residential-rate-plans/bsc
%
% Access date: October 24, 2026
%
% Reference scenario:
% Standard residential customer (not CARE/FERA)
% Annual settlement ending October 2026
%
% IMPORTANT:
% Undefined values are NaN, not zero.
% Do not use an undefined assumption in billing calculations.

    %% Reference Period

    assumptions.referenceYear = 2026;
    assumptions.settlementMonth = 10;

    %% Net Surplus Compensation

    % SCE published NSCR for October 2026 settlement.
    assumptions.nscRate_perkWh = 0.01858;

    assumptions.nscSource = ...
        "SCE published NSCR - October 2026";

    %% Base Services Charge

    % SCE standard residential approximate daily charge.
    assumptions.baseServicesCharge_perDay = 0.80;

    % Non-leap reference year.
    assumptions.daysPerYear = 365;

    assumptions.fixedAnnualCharge = ...
        assumptions.baseServicesCharge_perDay * ...
        assumptions.daysPerYear;

    assumptions.fixedChargeSource = ...
        "SCE Base Services Charge - standard residential";

    %% Non-Bypassable Charges

    % These values require additional tariff verification.
    % NaN prevents accidental use of invented values.

    assumptions.nem1_nbcRate_perkWh = NaN;
    assumptions.nem2_nbcRate_perkWh = NaN;

    assumptions.nbcStatus = ...
        "Pending tariff-specific verification";

    %% Modeling Status

    assumptions.isComplete = false;

    assumptions.notes = ...
        "Reference assumptions only; complete SCE billing " + ...
        "rules and tariff-specific charges remain to be verified.";
end
