
function bill = calculateAnnualSCEEPICBill( ...
    imports_kWh, exports_kWh, calendar)
% CALCULATEANNUALSCEEPICBILL
% Preliminary annual NEM settlement for SCE delivery
% and EPIC generation.
%
% Reference rates:
% SCE delivery: October 2026
% EPIC generation: February 2024
%
% This is a fixed-reference research scenario,
% NOT a verified utility bill.
%
% Excludes unresolved baseline credits, NBC,
% CCA-CRS, taxes, and climate credits.

    imports_kWh = imports_kWh(:);
    exports_kWh = exports_kWh(:);

    assert(numel(imports_kWh) == height(calendar));
    assert(numel(exports_kWh) == height(calendar));
    assert(all(isfinite(imports_kWh)) && ...
        all(imports_kWh >= 0));
    assert(all(isfinite(exports_kWh)) && ...
        all(exports_kWh >= 0));

    sce = econ.loadSCEDeliveryReferenceTariff();
    epic = econ.loadEPICReferenceTariff();

    tou = econ.aggregateSCETOU( ...
        imports_kWh, exports_kWh, calendar);

    assert(isequal(string(tou.Period), sce.periods));
    assert(isequal(sce.periods, epic.periods));

    % Annual grid energy
    annualImports = sum(imports_kWh);
    annualExports = sum(exports_kWh);

    netSurplus_kWh = max( ...
        annualExports - annualImports, 0);

    % SCE delivery retail energy valuation
    sceImportValue = sum( ...
        tou.Imports_kWh .* sce.deliveryRates);

    sceExportValue = sum( ...
        tou.Exports_kWh .* sce.deliveryRates);

    sceNetRetail = sceImportValue - sceExportValue;

    % EPIC generation retail energy valuation
    epicImportValue = sum( ...
        tou.Imports_kWh .* epic.generationRates);

    epicExportValue = sum( ...
        tou.Exports_kWh .* epic.generationRates);

    epicNetRetail = epicImportValue - epicExportValue;

    % Annual settlement approximation:
    % Unused retail credits do not become cash.
    sceDeliveryDue = max(sceNetRetail, 0);
    epicGenerationDue = max(epicNetRetail, 0);

    % EPIC published February 2024 NSC rate
    epicNSCRate = 0.06;

    % EPIC NSC is calculated on annual net surplus kWh.
    % It is distinct from the retail credit balance.
    epicNSC = netSurplus_kWh * epicNSCRate;

    % SCE base services charge:
    % Fixed-reference assumption of 365 service days.
    baseServices = ...
        sce.baseServicesChargePerDay * 365;

    % Explicitly excluded pending tariff verification
    baselineCredit = NaN;
    nonbypassableCharges = NaN;
    ccaCRSCharges = NaN;
    otherAdjustments = NaN;

    % Preliminary net annual economic cost.
    % NSC is treated as an economic benefit even if
    % EPIC issues it as a rollover credit rather than cash.
    preliminaryCost = ...
        sceDeliveryDue + ...
        epicGenerationDue + ...
        baseServices - ...
        epicNSC;

    bill = struct();

    bill.annualImports_kWh = annualImports;
    bill.annualExports_kWh = annualExports;
    bill.netSurplus_kWh = netSurplus_kWh;

    bill.sceImportValue = sceImportValue;
    bill.sceExportValue = sceExportValue;
    bill.sceNetRetail = sceNetRetail;

    bill.epicImportValue = epicImportValue;
    bill.epicExportValue = epicExportValue;
    bill.epicNetRetail = epicNetRetail;

    bill.sceDeliveryDue = sceDeliveryDue;
    bill.epicGenerationDue = epicGenerationDue;

    bill.epicNSCRate = epicNSCRate;
    bill.epicNSC = epicNSC;

    bill.baseServices = baseServices;

    bill.baselineCredit = baselineCredit;
    bill.nonbypassableCharges = nonbypassableCharges;
    bill.ccaCRSCharges = ccaCRSCharges;
    bill.otherAdjustments = otherAdjustments;

    bill.preliminaryCost = preliminaryCost;

    bill.isComplete = false;
    bill.status = ...
        "Preliminary annual settlement; billing adjustments pending";
end
