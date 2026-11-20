
function tariff = loadSCEDeliveryReferenceTariff()
% LOADSCEDELIVERYREFERENCETARIFF
% SCE Schedule TOU-D, Option 4-9 PM.
%
% Advice 5897-E, effective October 1, 2026.
% Source: ELECTRIC_SCHEDULES_TOU-D.pdf, Sheets 2-3.
%
% Delivery-only rates for a fixed-reference scenario.
% EPIC generation charges must be calculated separately.

    tariff.plan = "TOU-D-4-9PM";
    tariff.effectiveDate = datetime(2026,10,1);

    tariff.periods = [ ...
        "Summer On Peak";
        "Summer Mid Peak";
        "Summer Off Peak";
        "Winter Mid Peak";
        "Winter Off Peak";
        "Winter Super Off Peak"];

    tariff.deliveryRates = [ ...
        0.33582;
        0.33442;
        0.26222;
        0.31904;
        0.27056;
        0.25540];

    % Separate tariff components
    tariff.baselineCreditRate = -0.09101;
    tariff.fixedRecoveryRate = 0.01118;
    tariff.mcamRate = 0.00223;
    tariff.baseServicesChargePerDay = 0.794;

    tariff.climateCreditPerDisbursement = -36.00;

    tariff.source = ...
        "SCE Schedule TOU-D, Advice 5897-E, Oct 1 2026";

end
