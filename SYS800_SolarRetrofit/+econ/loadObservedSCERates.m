
function observed = loadObservedSCERates()
% LOADOBSERVEDSCERATES
% SCE delivery and EPIC generation rates transcribed from
% the September 8 - October 6, 2026 utility statement.
%
% These rates are specific to the observed billing period.
% They are NOT a verified full-year tariff schedule.

    observed.periodStart = datetime(2026,9,8);
    observed.periodEnd = datetime(2026,10,6);

    observed.periods = [ ...
        "Summer On Peak";
        "Summer Mid Peak";
        "Summer Off Peak";
        "Winter Mid Peak";
        "Winter Off Peak";
        "Winter Super Off Peak"];

    % SCE delivery rates ($/kWh)
    observed.sceDeliveryRates = [ ...
        0.32565;
        0.32565;
        0.26679;
        0.31313;
        0.26465;
        0.24949];

    % EPIC generation rates ($/kWh)
    observed.epicGenerationRates = [ ...
        0.31299;
        0.18747;
        0.11419;
        0.23432;
        0.14279;
        0.12008];

    % Baseline credit line items
    observed.baselineQuantities_kWh = [110;64];
    observed.baselineRates = [-0.10099;-0.09101];

    % CCA/CRS line items
    observed.ccaQuantities_kWh = [110;64;174;174];
    observed.ccaRates = [ ...
        0.02419;
        0.02425;
        0.00591;
        0.00014];

    % Fixed recovery charge line items
    observed.recoveryQuantities_kWh = [110;64];
    observed.recoveryRates = [0.00619;0.01118];

    observed.sceTrackedCharge = 46.24;
    observed.epicGenerationCharge = 49.08;

    observed.source = ...
        "Observed SCE/EPIC statement, October 2026";
end
