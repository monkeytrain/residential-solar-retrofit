
function result = calculateNBTBill(gridImport_kWh,gridExport_kWh, ...
    importRates,exportRates,calendar,options)
% CALCULATENBTBILL Preliminary Solar Billing Plan model.
%
% Separately values hourly grid imports at retail rates
% and grid exports at hourly avoided-cost rates.
%
% Simplified research accounting:
% - Export credits offset eligible energy charges only.
% - Unused export credits are reported, not paid as cash.
% - Fixed and non-bypassable charges are not credit-eligible.
% - Annual settlement is used as a modeling simplification.
%
% NOT a complete SCE NBT billing implementation.
% Does not implement monthly credit rollover, vintage-specific
% export schedules, ACC Plus adders, or full tariff rules.

    arguments
        gridImport_kWh (:,1) double
        gridExport_kWh (:,1) double
        importRates (:,1) double
        exportRates (:,1) double
        calendar table
        options.nbcRate_perkWh (1,1) double = 0
        options.fixedAnnualCharge (1,1) double = 0
    end

    %% Validate inputs

    n = numel(gridImport_kWh);

    assert(n==8760 && ...
        numel(gridExport_kWh)==n && ...
        numel(importRates)==n && ...
        numel(exportRates)==n && ...
        height(calendar)==n, ...
        "All hourly inputs must contain 8760 records.");

    assert(ismember("Timestamp", ...
        string(calendar.Properties.VariableNames)), ...
        "Calendar must contain Timestamp.");

    assert(all(isfinite(gridImport_kWh) & gridImport_kWh>=0));
    assert(all(isfinite(gridExport_kWh) & gridExport_kWh>=0));
    assert(all(isfinite(importRates) & importRates>=0));
    assert(all(isfinite(exportRates) & exportRates>=0));

    assert(isfinite(options.nbcRate_perkWh) && ...
        options.nbcRate_perkWh>=0);
    assert(isfinite(options.fixedAnnualCharge) && ...
        options.fixedAnnualCharge>=0);

    %% Hourly energy accounting

    hourlyImportCharges = gridImport_kWh .* importRates;
    hourlyExportCredits = gridExport_kWh .* exportRates;

    annualImportCharges = sum(hourlyImportCharges);
    annualExportCredits = sum(hourlyExportCredits);

    %% Preliminary annual credit settlement

    % Credits can offset eligible energy charges, but not
    % non-bypassable or fixed charges.
    exportCreditsApplied = min( ...
        annualExportCredits,annualImportCharges);

    unusedExportCredits = ...
        annualExportCredits-exportCreditsApplied;

    netEnergyCharges = ...
        annualImportCharges-exportCreditsApplied;

    %% Non-bypassable and fixed charges

    annualImports = sum(gridImport_kWh);
    annualExports = sum(gridExport_kWh);

    nonBypassableCharges = ...
        annualImports*options.nbcRate_perkWh;

    fixedAnnualCharge = options.fixedAnnualCharge;

    annualCost = netEnergyCharges + ...
        nonBypassableCharges + fixedAnnualCharge;

    %% Monthly diagnostics

    months = month(calendar.Timestamp);

    monthlyImportCharges = accumarray( ...
        months,hourlyImportCharges,[12 1]);

    monthlyExportCredits = accumarray( ...
        months,hourlyExportCredits,[12 1]);

    monthlyNetEnergyValue = ...
        monthlyImportCharges-monthlyExportCredits;

    monthlyCumulativeEnergyValue = ...
        cumsum(monthlyNetEnergyValue);

    %% Output structure

    result.annualImports_kWh = annualImports;
    result.annualExports_kWh = annualExports;

    result.annualImportCharges = annualImportCharges;
    result.annualExportCredits = annualExportCredits;

    result.exportCreditsApplied = exportCreditsApplied;
    result.unusedExportCredits = unusedExportCredits;

    result.netEnergyCharges = netEnergyCharges;
    result.nonBypassableCharges = nonBypassableCharges;
    result.fixedAnnualCharge = fixedAnnualCharge;

    result.annualCost = annualCost;

    result.hourlyImportCharges = hourlyImportCharges;
    result.hourlyExportCredits = hourlyExportCredits;

    result.monthly = table( ...
        (1:12)', ...
        monthlyImportCharges, ...
        monthlyExportCredits, ...
        monthlyNetEnergyValue, ...
        monthlyCumulativeEnergyValue, ...
        'VariableNames', ...
        {'Month','ImportCharges','ExportCredits', ...
         'NetEnergyValue','CumulativeEnergyValue'});

    result.modelStatus = ...
        "Preliminary NBT research model";
end
