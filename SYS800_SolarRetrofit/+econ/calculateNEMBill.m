
function result = calculateNEMBill(gridImport_kWh,gridExport_kWh, ...
    hourlyRates,calendar,nemVersion,options)
% CALCULATENEMBILL Annual legacy NEM research billing model.
%
% Uses hourly retail-rate energy accounting and an annual true-up.
%
% Inputs:
%   gridImport_kWh   Hourly grid imports (kWh)
%   gridExport_kWh   Hourly grid exports (kWh)
%   hourlyRates      Hourly retail rates ($/kWh)
%   calendar         Table containing Timestamp
%   nemVersion       1 or 2
%
% Name-value options:
%   nbcRate_perkWh       Non-bypassable charge rate ($/kWh)
%   nscRate_perkWh       Net surplus compensation rate ($/kWh)
%   fixedAnnualCharge   Fixed annual charges ($)
%
% IMPORTANT:
% This is a simplified research model, not a complete SCE
% billing implementation. It does not yet include baseline
% credits, detailed billing adjustments, taxes, or all
% applicable tariff provisions.

    arguments
        gridImport_kWh (:,1) double
        gridExport_kWh (:,1) double
        hourlyRates (:,1) double
        calendar table
        nemVersion (1,1) double {mustBeMember(nemVersion,[1 2])}
        options.nbcRate_perkWh (1,1) double = 0
        options.nscRate_perkWh (1,1) double = 0
        options.fixedAnnualCharge (1,1) double = 0
    end

    %% Validate inputs

    n = numel(gridImport_kWh);

    assert(n==8760 && numel(gridExport_kWh)==n && ...
        numel(hourlyRates)==n && height(calendar)==n, ...
        "All hourly inputs must contain 8760 records.");

    assert(ismember("Timestamp",string(calendar.Properties.VariableNames)), ...
        "Calendar must contain Timestamp.");

    assert(all(isfinite(gridImport_kWh) & gridImport_kWh>=0));
    assert(all(isfinite(gridExport_kWh) & gridExport_kWh>=0));
    assert(all(isfinite(hourlyRates) & hourlyRates>=0));

    assert(options.nbcRate_perkWh>=0 && ...
        options.nscRate_perkWh>=0 && ...
        options.fixedAnnualCharge>=0, ...
        "Billing assumptions must be nonnegative.");

    %% Hourly energy accounting

    importCharges = gridImport_kWh .* hourlyRates;
    exportCredits = gridExport_kWh .* hourlyRates;

    hourlyNetCharges = importCharges-exportCredits;

    %% Monthly energy ledger

    months = month(calendar.Timestamp);

    monthlyImportCharges = ...
        accumarray(months,importCharges,[12 1]);

    monthlyExportCredits = ...
        accumarray(months,exportCredits,[12 1]);

    monthlyNetCharges = ...
        accumarray(months,hourlyNetCharges,[12 1]);

    monthlyCumulativeBalance = cumsum(monthlyNetCharges);

    %% Monthly NEM retail-credit rollover ledger

    monthlyCreditsGenerated = zeros(12,1);
    monthlyCreditsApplied = zeros(12,1);
    monthlyCreditBalance = zeros(12,1);
    monthlyUncoveredCharges = zeros(12,1);

    creditBalance = 0;

    for m = 1:12

        netCharge = monthlyNetCharges(m);

        if netCharge < 0

            % Excess monthly export credits are carried forward.
            monthlyCreditsGenerated(m) = -netCharge;

            creditBalance = creditBalance + ...
                monthlyCreditsGenerated(m);

        else

            % Use available credits to offset monthly
            % retail energy charges.
            creditsUsed = min(creditBalance,netCharge);

            monthlyCreditsApplied(m) = creditsUsed;

            creditBalance = creditBalance - creditsUsed;

            monthlyUncoveredCharges(m) = ...
                netCharge - creditsUsed;

        end

        monthlyCreditBalance(m) = creditBalance;

    end


    %% Monthly fixed-charge allocation

    % Allocate the supplied annual fixed charge by the number
    % of calendar days in each month.

    daysInMonth = eomday(year(calendar.Timestamp(1)),(1:12)');

    totalDays = sum(daysInMonth);

    monthlyFixedCharges = ...
        options.fixedAnnualCharge * daysInMonth / totalDays;

    % Fixed charges are tracked separately from retail
    % energy credits and the annual true-up balance.

    monthlyChargesBeforeSettlement = ...
        monthlyNetCharges + monthlyFixedCharges;


    %% Annual electricity quantities

    annualImports = sum(gridImport_kWh);
    annualExports = sum(gridExport_kWh);

    annualNetConsumption = annualImports-annualExports;

    % Positive only when annual exports exceed imports.
    surplus_kWh = max(-annualNetConsumption,0);

    %% Annual retail credit settlement

    annualRetailBalance = sum(hourlyNetCharges);

    % Positive balance: retail energy charges owed.
    annualRetailAmountDue = max(annualRetailBalance,0);

    % Negative balance: unused retail-dollar credits.
    % These are not automatically payable at retail value.
    unusedRetailCredits = max(-annualRetailBalance,0);

    %% Net surplus compensation

    % Annual surplus eligibility is based on kWh,
    % not on the retail-dollar balance.
    %
    % The compensation rate is supplied externally.
    % This value is a separate settlement component.
    netSurplusCompensation = ...
        surplus_kWh*options.nscRate_perkWh;

    %% Non-bypassable charges

    switch nemVersion
        case 1
            % NEM 1.0: annual net consumption basis.
            nbcBasis_kWh = max(annualNetConsumption,0);

        case 2
            % NEM 2.0: metered hourly import basis.
            % Assumes gridImport_kWh is interval net import.
            nbcBasis_kWh = annualImports;
    end

    nonBypassableCharges = ...
        nbcBasis_kWh*options.nbcRate_perkWh;

    %% Annual modeled economic result

    % Research net-cost metric:
    % Energy charges plus NBC and fixed charges,
    % less annual net surplus compensation.
    %
    % Actual SCE cash billing and compensation
    % may be administered separately.
    annualCost = annualRetailAmountDue + ...
        nonBypassableCharges + ...
        options.fixedAnnualCharge - ...
        netSurplusCompensation;

    %% Output structure

    result.nemVersion = nemVersion;

    result.annualImports_kWh = annualImports;
    result.annualExports_kWh = annualExports;
    result.annualNetConsumption_kWh = annualNetConsumption;

    result.annualImportCharges = sum(importCharges);
    result.annualExportCredits = sum(exportCredits);

    result.annualRetailBalance = annualRetailBalance;
    result.annualRetailAmountDue = annualRetailAmountDue;
    result.unusedRetailCredits = unusedRetailCredits;

    result.annualSurplus_kWh = surplus_kWh;
    result.netSurplusCompensation = netSurplusCompensation;

    result.nbcBasis_kWh = nbcBasis_kWh;
    result.nonBypassableCharges = nonBypassableCharges;
    result.fixedAnnualCharge = options.fixedAnnualCharge;

    result.monthlyFixedCharges = monthlyFixedCharges;
    result.monthlyChargesBeforeSettlement = ...
        monthlyChargesBeforeSettlement;


    result.annualCost = annualCost;

    result.hourlyImportCharges = importCharges;
    result.hourlyExportCredits = exportCredits;
    result.hourlyNetCharges = hourlyNetCharges;

    result.monthlyCreditsGenerated = monthlyCreditsGenerated;
    result.monthlyCreditsApplied = monthlyCreditsApplied;
    result.monthlyCreditBalance = monthlyCreditBalance;
    result.monthlyUncoveredCharges = monthlyUncoveredCharges;

    result.monthly = table((1:12)', ...
        monthlyImportCharges, ...
        monthlyExportCredits, ...
        monthlyNetCharges, ...
        monthlyCumulativeBalance, ...
        monthlyFixedCharges, ...
        monthlyChargesBeforeSettlement, ...
        monthlyCreditsGenerated, ...
        monthlyCreditsApplied, ...
        monthlyCreditBalance, ...
        monthlyUncoveredCharges, ...
        'VariableNames', ...
        {'Month','ImportCharges','ExportCredits', ...
         'NetCharges','CumulativeBalance', ...
         'FixedCharges','ChargesBeforeSettlement', ...
         'CreditsGenerated','CreditsApplied', ...
         'CreditBalance','UncoveredCharges'});


end
