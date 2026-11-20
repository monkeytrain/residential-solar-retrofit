%% SYS 800 - Residential Solar Retrofit Decision Model (v3)
% Technical performance model: existing aged PV + new PV + battery storage.
% Run from project root containing data/, +sim/, and +econ/.
% Representative non-coincident hourly PV and load profiles; preliminary billing.
% Results: retrofitComparison, economicComparison; 3 decision-focused figures.
clear; clc; close all;

% Dark figure theme: readable in both MATLAB light and dark desktop modes.
theme.background = [0.10 0.12 0.15];
theme.axes = [0.15 0.17 0.21];
theme.foreground = [0.94 0.95 0.97];
theme.grid = [0.46 0.49 0.54];
theme.palette = [0.35 0.75 1.00; 0.98 0.66 0.33; ...
                 0.45 0.86 0.62; 0.81 0.60 1.00; ...
                 1.00 0.52 0.64; 0.98 0.83 0.40];
% Figure/axes/text defaults apply to plots created below.
set(groot,'defaultFigureColor',theme.background, ...
    'defaultAxesColor',theme.axes, ...
    'defaultAxesXColor',theme.foreground, ...
    'defaultAxesYColor',theme.foreground, ...
    'defaultAxesZColor',theme.foreground, ...
    'defaultAxesGridColor',theme.grid, ...
    'defaultAxesColorOrder',theme.palette, ...
    'defaultTextColor',theme.foreground);

%% 1. Configuration
location.city = "Palmdale";
location.state = "California";
location.latitude = 34.58;
location.longitude = -118.12;

% Reference load profile: ResStock building 198638 (1690 sq ft, 3 occupants).
% Original target home size was 1500 sq ft; this is a representative match,
% not a measured profile for the target home.
house.targetArea_sqft = 1500;
house.referenceArea_sqft = 1690;
house.resstockBuildingID = 198638;
house.occupants = 3;
house.type = "Single Family Detached";
house.heating = "Natural Gas";
house.cooling = "Central AC";
house.waterHeating = "Natural Gas";

pv.capacity_kW = 6;                 % Existing PV nameplate capacity
pv.age_years = 10;
pv.degradationRate = 0.005;        % Fraction per year
pv.addedCapacityScenarios_kW = [0 2 4]; % NEW PV only

battery.capacityScenarios_kWh = [0 5 10 15 20];
battery.capacity_kWh = 10;         % Overwritten for each scenario
battery.maxChargePower_kW = 5;
battery.maxDischargePower_kW = 5;
battery.roundTripEfficiency = 0.90;
battery.initialSOC_kWh = 0;

settings.hoursPerYear = 8760;
settings.timeStep_hours = 1;

settings.showFigures = true;

%% 2. Load and prepare hourly input data
assert(isfile("data/pvwatts_hourly.csv"), "PVWatts CSV not found. Run from project root.");
assert(isfile("data/198638-0.parquet"), "ResStock parquet not found. Run from project root.");

pvData = readtable("data/pvwatts_hourly.csv", ...
    "NumHeaderLines",31,"VariableNamingRule","preserve");
assert(height(pvData) == settings.hoursPerYear, "PVWatts must have 8760 hourly records.");
solarEnergy_kWh = pvData.("AC System Output (W)") / 1000 * settings.timeStep_hours;
solarEnergy_kWh = solarEnergy_kWh(:); % NEW, undegraded 6 kW reference profile
solarIrradiance = pvData.("Plane of Array Irradiance (W/m2)");
solarIrradiance = solarIrradiance(:);
degradationFactor = (1-pv.degradationRate)^pv.age_years;
solarAged_kWh = solarEnergy_kWh * degradationFactor;

loadData = parquetread("data/198638-0.parquet");
assert(height(loadData) == 35040, "ResStock must have 35040 15-minute records.");
demand15min_kWh = loadData.out_electricity_total_energy_consumption;
assert(all(isfinite(demand15min_kWh)) && all(demand15min_kWh >= 0), ...
    "ResStock demand must be finite and nonnegative.");
% Values are kWh PER 15-minute interval: sum groups of four, do not multiply by 0.25.
demandHourly_kWh = sum(reshape(demand15min_kWh,4,[]),1)';
assert(numel(demandHourly_kWh) == settings.hoursPerYear, "Demand must have 8760 hours.");
assert(all(isfinite(solarAged_kWh)) && all(solarAged_kWh >= 0), ...
    "PV generation must be finite and nonnegative.");

annualDemand_kWh = sum(demandHourly_kWh);
annualSolarAged_kWh = sum(solarAged_kWh);

%% 3. Existing system: no retrofit
baseline = sim.calculateEnergyFlows(demandHourly_kWh,solarAged_kWh);
annualGridImport_kWh = sum(baseline.gridImport_kWh);
annualGridExport_kWh = sum(baseline.gridExport_kWh);
annualSelfConsumed_kWh = sum(baseline.selfConsumed_kWh);

% Calendar assumes a non-leap year. PVWatts and ResStock are representative
% profiles from different source weather years, not coincident measurements.
monthNames = ["Jan" "Feb" "Mar" "Apr" "May" "Jun" ...
              "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"];
daysPerMonth = [31 28 31 30 31 30 31 31 30 31 30 31];
monthEndHours = cumsum(daysPerMonth)*24;
monthStartHours = [1 monthEndHours(1:end-1)+1];
monthlyDemand_kWh = zeros(12,1);
monthlySolar_kWh = zeros(12,1);
monthlyImport_kWh = zeros(12,1);
monthlyExport_kWh = zeros(12,1);
for m = 1:12
    idx = monthStartHours(m):monthEndHours(m);
    monthlyDemand_kWh(m) = sum(demandHourly_kWh(idx));
    monthlySolar_kWh(m) = sum(solarAged_kWh(idx));
    monthlyImport_kWh(m) = sum(baseline.gridImport_kWh(idx));
    monthlyExport_kWh(m) = sum(baseline.gridExport_kWh(idx));
end
monthlyResults = table(monthNames',monthlyDemand_kWh,monthlySolar_kWh, ...
    monthlyImport_kWh,monthlyExport_kWh, ...
    'VariableNames',{'Month','Demand_kWh','Solar_kWh','GridImport_kWh','GridExport_kWh'});

%% 4. Retrofit trade study (existing aged PV + NEW PV + storage)
addedPVSizes = pv.addedCapacityScenarios_kW;
batterySizes = battery.capacityScenarios_kWh;
numAddedPV = numel(addedPVSizes);
numBattery = numel(batterySizes);
numRetrofitScenarios = numAddedPV*numBattery;
assert(any(addedPVSizes==0) && any(batterySizes==0), ...
    "Scenario lists must include a zero-PV and zero-battery baseline.");
assert(all(addedPVSizes>=0) && all(batterySizes>=0), ...
    "Retrofit capacities must be nonnegative.");

retrofitAddedPV_kW = zeros(numRetrofitScenarios,1);
retrofitBattery_kWh = zeros(numRetrofitScenarios,1);
retrofitGeneration_kWh = zeros(numRetrofitScenarios,1);
retrofitImports_kWh = zeros(numRetrofitScenarios,1);
retrofitExports_kWh = zeros(numRetrofitScenarios,1);
retrofitImportReduction_pct = zeros(numRetrofitScenarios,1);
retrofitDischarge_kWh = zeros(numRetrofitScenarios,1);

% Preserve each scenario's hourly exchanges for tariff calculations.
hourlyRetrofitImports_kWh = zeros(settings.hoursPerYear,numRetrofitScenarios);
hourlyRetrofitExports_kWh = zeros(settings.hoursPerYear,numRetrofitScenarios);

% Verification maxima accumulated across EVERY retrofit configuration.
maxHourlyBalanceError = 0;
maxSOCBalanceError = 0;
eta = sqrt(battery.roundTripEfficiency);
tolerance = 1e-8;
scenarioIndex = 0;
for i = 1:numAddedPV
    % Existing panels are aged; newly installed panels are not.
    newPV_kWh = solarEnergy_kWh * (addedPVSizes(i)/pv.capacity_kW);
    totalSolar_kWh = solarAged_kWh + newPV_kWh;
    for j = 1:numBattery
        scenarioIndex = scenarioIndex+1;
        testBattery = battery;
        testBattery.capacity_kWh = batterySizes(j);
        scenario = sim.calculateBatteryDispatch(demandHourly_kWh,totalSolar_kWh,testBattery);

        retrofitAddedPV_kW(scenarioIndex) = addedPVSizes(i);
        retrofitBattery_kWh(scenarioIndex) = batterySizes(j);
        retrofitGeneration_kWh(scenarioIndex) = sum(totalSolar_kWh);
        retrofitImports_kWh(scenarioIndex) = sum(scenario.gridImport_kWh);
        retrofitExports_kWh(scenarioIndex) = sum(scenario.gridExport_kWh);
        hourlyRetrofitImports_kWh(:,scenarioIndex) = scenario.gridImport_kWh(:);
        hourlyRetrofitExports_kWh(:,scenarioIndex) = scenario.gridExport_kWh(:);
        retrofitDischarge_kWh(scenarioIndex) = sum(scenario.batteryDischarge_kWh);
        retrofitImportReduction_pct(scenarioIndex) = 100* ...
            (annualGridImport_kWh-retrofitImports_kWh(scenarioIndex))/annualGridImport_kWh;


        soc = scenario.stateOfCharge_kWh;

        % Hourly whole-system energy conservation and battery SOC accounting.
        hourlyBalance = demandHourly_kWh + scenario.batteryCharge_kWh + ...
            scenario.gridExport_kWh - totalSolar_kWh - ...
            scenario.batteryDischarge_kWh - scenario.gridImport_kWh;
        maxHourlyBalanceError = max(maxHourlyBalanceError,max(abs(hourlyBalance)));
        socStart = [testBattery.initialSOC_kWh; soc(1:end-1)];
        socExpected = socStart + eta*scenario.batteryCharge_kWh - ...
            scenario.batteryDischarge_kWh/eta;
        maxSOCBalanceError = max(maxSOCBalanceError,max(abs(soc-socExpected)));
        assert(all(soc >= -tolerance) && ...
               all(soc <= testBattery.capacity_kWh+tolerance), ...
               "Battery SOC outside capacity limits.");
        assert(all(scenario.batteryCharge_kWh >= -tolerance) && ...
               all(scenario.batteryCharge_kWh <= ...
                   testBattery.maxChargePower_kW*settings.timeStep_hours+tolerance), ...
               "Battery charging power limit violated.");
        assert(all(scenario.batteryDischarge_kWh >= -tolerance) && ...
               all(scenario.batteryDischarge_kWh <= ...
                   testBattery.maxDischargePower_kW*settings.timeStep_hours+tolerance), ...
               "Battery discharging power limit violated.");
        assert(all(scenario.gridImport_kWh >= -tolerance) && ...
               all(scenario.gridExport_kWh >= -tolerance), ...
               "Negative grid exchanges detected.");
    end
end
retrofitComparison = table(retrofitAddedPV_kW,retrofitBattery_kWh, ...
    retrofitGeneration_kWh,retrofitImports_kWh,retrofitExports_kWh, ...
    retrofitImportReduction_pct, ...
    'VariableNames',{'AddedPV_kW','BatteryCapacity_kWh', ...
    'Generation_kWh','GridImports_kWh','GridExports_kWh','ImportReduction_pct'});

%% 5. Technical model verification
assert(isequal(size(hourlyRetrofitImports_kWh), ...
    [settings.hoursPerYear,numRetrofitScenarios]));
assert(isequal(size(hourlyRetrofitExports_kWh), ...
    [settings.hoursPerYear,numRetrofitScenarios]));
assert(all(abs(sum(hourlyRetrofitImports_kWh,1)' - ...
    retrofitImports_kWh)<tolerance), ...
    "Hourly import totals mismatch annual totals.");
assert(all(abs(sum(hourlyRetrofitExports_kWh,1)' - ...
    retrofitExports_kWh)<tolerance), ...
    "Hourly export totals mismatch annual totals.");
assert(maxHourlyBalanceError < tolerance, "Hourly energy conservation failed.");
assert(maxSOCBalanceError < tolerance, "Battery SOC conservation failed.");
assert(abs(sum(monthlyDemand_kWh)-annualDemand_kWh) < tolerance, ...
    "Monthly demand does not sum to annual demand.");
assert(abs(sum(monthlySolar_kWh)-annualSolarAged_kWh) < tolerance, ...
    "Monthly PV generation does not sum to annual PV generation.");
assert(abs(sum(monthlyImport_kWh)-annualGridImport_kWh) < tolerance, ...
    "Monthly grid imports do not sum to annual imports.");
assert(abs(sum(monthlyExport_kWh)-annualGridExport_kWh) < tolerance, ...
    "Monthly grid exports do not sum to annual exports.");

baseIdx = retrofitAddedPV_kW==0 & retrofitBattery_kWh==0;
assert(nnz(baseIdx)==1,"Expected exactly one baseline configuration.");
assert(all(abs(hourlyRetrofitImports_kWh(:,baseIdx) - ...
    baseline.gridImport_kWh(:))<tolerance));
assert(all(abs(hourlyRetrofitExports_kWh(:,baseIdx) - ...
    baseline.gridExport_kWh(:))<tolerance));
assert(abs(retrofitImports_kWh(baseIdx)-annualGridImport_kWh)<tolerance, ...
    "Retrofit baseline imports mismatch.");
assert(abs(retrofitExports_kWh(baseIdx)-annualGridExport_kWh)<tolerance, ...
    "Retrofit baseline exports mismatch.");
assert(abs(retrofitGeneration_kWh(baseIdx)-annualSolarAged_kWh)<tolerance, ...
    "Retrofit baseline PV generation mismatch.");

% Independent PV-only checks using the no-storage energy-flow function.
for i = 1:numAddedPV
    idx = retrofitAddedPV_kW==addedPVSizes(i) & retrofitBattery_kWh==0;
    testSolar = solarAged_kWh + solarEnergy_kWh*(addedPVSizes(i)/pv.capacity_kW);
    testFlows = sim.calculateEnergyFlows(demandHourly_kWh,testSolar);
    assert(nnz(idx)==1 && ...
        abs(retrofitImports_kWh(idx)-sum(testFlows.gridImport_kWh))<tolerance && ...
        abs(retrofitExports_kWh(idx)-sum(testFlows.gridExport_kWh))<tolerance, ...
        "PV-only augmentation mismatch.");
end
% At fixed PV capacity, more battery capacity must not increase imports.
for i = 1:numAddedPV
    idx = retrofitAddedPV_kW==addedPVSizes(i);
    assert(all(diff(retrofitImports_kWh(idx))<=tolerance), ...
        "Grid imports increased with battery capacity.");
end
% At fixed battery capacity, more PV must not increase imports.
for j = 1:numBattery
    idx = retrofitBattery_kWh==batterySizes(j);
    assert(all(diff(retrofitImports_kWh(idx))<=tolerance), ...
        "Grid imports increased with new PV capacity.");
end

fprintf("\n=== MODEL VERIFICATION ===\n");
fprintf("PVWatts: %d hourly records; ResStock: %d 15-min records. PASS\n", ...
    height(pvData),height(loadData));
fprintf("Baseline: %.1f kWh demand, %.1f kWh aged PV, %.1f kWh imports, %.1f kWh exports.\n", ...
    annualDemand_kWh,annualSolarAged_kWh,annualGridImport_kWh,annualGridExport_kWh);
fprintf("Monthly aggregation and baseline scenario: PASS\n");
fprintf("PV-only cross-checks and scenario trends: PASS\n");
fprintf("All %d battery scenarios: SOC, power limits, nonnegative flows: PASS\n", ...
    numRetrofitScenarios);
fprintf("Maximum hourly energy balance residual: %.12f kWh\n",maxHourlyBalanceError);
fprintf("Maximum hourly SOC balance residual: %.12f kWh\n",maxSOCBalanceError);
fprintf("All verification checks passed.\n");


%% 6. Economic assumptions and hourly tariff alignment
% RESEARCH ESTIMATES ONLY: rounded retail tariffs, simplified annual billing.
% NEM1 and NEM2 NBC rates are intentionally set to zero for sensitivity.
% NBT credit accounting uses the preliminary annual-offset approximation.
% The PVWatts and ResStock profiles are not independently time-zone validated.

sceTariff = econ.loadSCETariffs();
billingAssumptions = econ.loadSCEBillingAssumptions();
economicYear = 2026;

% Retail imports for NEM 1.0 and NEM 2.0.
[nemImportRates,economicCalendar] = econ.buildTOURates( ...
    economicYear,"TOU-D-4-9PM",sceTariff.rateTable);

% NBT imports use a distinct assumed retail plan (TOU-D-PRIME).
[nbtImportRates,nbtCalendar] = econ.buildTOURates( ...
    economicYear,"TOU-D-PRIME",sceTariff.rateTable);

% NBT26 export compensation: bundled generation + delivery components.
[nbtExportRates,nbtComponents] = econ.loadNBTExportRates( ...
    "data/NBT26_2026_hourly_components.csv",economicYear);

assert(numel(nemImportRates)==settings.hoursPerYear && ...
       numel(nbtImportRates)==settings.hoursPerYear && ...
       numel(nbtExportRates)==settings.hoursPerYear, ...
       "All tariff vectors must contain 8760 hours.");
assert(isequal(economicCalendar.Timestamp,nbtCalendar.Timestamp) && ...
       isequal(economicCalendar.Timestamp,nbtComponents.Timestamp), ...
       "Economic and NBT timestamps are not aligned.");
assert(all(isfinite(nemImportRates) & nemImportRates>=0) && ...
       all(isfinite(nbtImportRates) & nbtImportRates>=0) && ...
       all(isfinite(nbtExportRates) & nbtExportRates>=0), ...
       "Tariff vectors must be finite and nonnegative.");

% Provisional billing assumptions. Zero NBC is NOT an actual SCE tariff.
nem1NBC_perkWh = 0;
nem2NBC_perkWh = 0;
nbtNBC_perkWh = 0;
nscRate_perkWh = billingAssumptions.nscRate_perkWh;
fixedAnnualCharge = billingAssumptions.fixedAnnualCharge;

%% 7. Annual operating costs for all 15 retrofit scenarios
nem1AnnualCost = zeros(numRetrofitScenarios,1);
nem2AnnualCost = zeros(numRetrofitScenarios,1);
nbtAnnualCost = zeros(numRetrofitScenarios,1);

for s = 1:numRetrofitScenarios
    imports = hourlyRetrofitImports_kWh(:,s);
    exports = hourlyRetrofitExports_kWh(:,s);

    nem1 = econ.calculateNEMBill( ...
        imports,exports,nemImportRates,economicCalendar,1, ...
        nbcRate_perkWh=nem1NBC_perkWh, ...
        nscRate_perkWh=nscRate_perkWh, ...
        fixedAnnualCharge=fixedAnnualCharge);

    nem2 = econ.calculateNEMBill( ...
        imports,exports,nemImportRates,economicCalendar,2, ...
        nbcRate_perkWh=nem2NBC_perkWh, ...
        nscRate_perkWh=nscRate_perkWh, ...
        fixedAnnualCharge=fixedAnnualCharge);

    nbt = econ.calculateNBTBill( ...
        imports,exports,nbtImportRates,nbtExportRates,nbtCalendar, ...
        nbcRate_perkWh=nbtNBC_perkWh, ...
        fixedAnnualCharge=fixedAnnualCharge);

    nem1AnnualCost(s) = nem1.annualCost;
    nem2AnnualCost(s) = nem2.annualCost;
    nbtAnnualCost(s) = nbt.annualCost;
end

% Compare each retrofit against the same 0 kW / 0 kWh configuration.
baseIdx = retrofitAddedPV_kW==0 & retrofitBattery_kWh==0;
baselineScenario = find(baseIdx);
nem1AnnualSavings = nem1AnnualCost(baselineScenario)-nem1AnnualCost;
nem2AnnualSavings = nem2AnnualCost(baselineScenario)-nem2AnnualCost;
nbtAnnualSavings = nbtAnnualCost(baselineScenario)-nbtAnnualCost;

economicComparison = table( ...
    retrofitAddedPV_kW,retrofitBattery_kWh, ...
    nem1AnnualCost,nem2AnnualCost,nbtAnnualCost, ...
    nem1AnnualSavings,nem2AnnualSavings,nbtAnnualSavings, ...
    'VariableNames',{'AddedPV_kW','BatteryCapacity_kWh', ...
    'NEM1_AnnualCost','NEM2_AnnualCost','NBT_AnnualCost', ...
    'NEM1_AnnualSavings','NEM2_AnnualSavings','NBT_AnnualSavings'});

%% 8. Economic verification and concise results
assert(height(economicComparison)==numRetrofitScenarios);
allAnnualCosts = [nem1AnnualCost nem2AnnualCost nbtAnnualCost];
allAnnualSavings = [nem1AnnualSavings nem2AnnualSavings nbtAnnualSavings];
assert(all(isfinite(allAnnualCosts(:))) && all(allAnnualCosts(:)>=0), ...
    "Nonfinite or negative annual costs detected.");
assert(all(abs(allAnnualSavings(baselineScenario,:))<tolerance), ...
    "Baseline savings must be zero for all programs.");
assert(all(abs(nem1AnnualCost-nem2AnnualCost)<tolerance), ...
    "NEM 1.0/2.0 should match in the provisional zero-NBC case.");
assert(all(abs(nbtAnnualSavings - ...
    (nbtAnnualCost(baselineScenario)-nbtAnnualCost))<tolerance));

fprintf("\n=== ECONOMIC MODEL VERIFICATION ===\n");
fprintf("2026 NEM/NBT hourly tariff alignment: PASS\n");
fprintf("All %d scenarios under NEM 1.0, NEM 2.0, and NBT: PASS\n", ...
    numRetrofitScenarios);
fprintf("Baseline annual costs: NEM1 $%.2f | NEM2 $%.2f | NBT $%.2f\n", ...
    allAnnualCosts(baselineScenario,:));
fprintf("NOTE: Rounded retail tariffs and simplified utility settlement; ");
fprintf("zero-NBC sensitivity. Not verified utility bills.\n");

%% 9. Decision-focused figures
if settings.showFigures
    % Figure 1: Baseline seasonal energy balance.
    figure('Name','01 - Baseline Monthly Energy Flows');
    bar(1:12,[monthlyDemand_kWh monthlySolar_kWh ...
        monthlyImport_kWh monthlyExport_kWh],'grouped');
    xticks(1:12); xticklabels(monthNames);
    xlim([0.5 12.5]);
    xlabel('Month'); ylabel('Energy (kWh/month)');
    title('Existing 6 kW PV System - Monthly Energy Flows');
    legend('Demand','Aged PV','Imports','Exports', ...
        'Location','northoutside','Orientation','horizontal');
    grid on;

    % Figure 2: Technical grid-import reduction by retrofit configuration.
    figure('Name','02 - Retrofit Grid Import Reduction');
    hold on;
    for i = 1:numAddedPV
        idx = retrofitAddedPV_kW==addedPVSizes(i);
        plot(retrofitBattery_kWh(idx),retrofitImportReduction_pct(idx), ...
            '-o','LineWidth',1.7,'DisplayName', ...
            sprintf('+%g kW new PV',addedPVSizes(i)));
    end
    hold off; grid on;
    xlabel('Battery capacity (kWh)');
    ylabel('Annual grid-import reduction (%)');
    title('Technical Benefit of Solar and Battery Retrofits');
    legend('Location','best');

    % Figure 3: Annual modeled savings for the three billing programs.
    figure('Name','03 - Annual Savings by Billing Program');
    tiledlayout(1,3,'TileSpacing','compact');
    savingsSets = {nem1AnnualSavings,nem2AnnualSavings,nbtAnnualSavings};
    programNames = {'NEM 1.0','NEM 2.0','NBT (Solar Billing Plan)'};
    for p = 1:3
        nexttile; hold on;
        for i = 1:numAddedPV
            idx = retrofitAddedPV_kW==addedPVSizes(i);
            plot(retrofitBattery_kWh(idx),savingsSets{p}(idx), ...
                '-o','LineWidth',1.5,'DisplayName', ...
                sprintf('+%g kW PV',addedPVSizes(i)));
        end
        hold off; grid on;
        xlabel('Battery capacity (kWh)');
        ylabel('Annual modeled savings ($/year)');
        title(programNames{p});
        if p==3
            legend('Location','best');
        end
    end
    sgtitle('Preliminary Annual Operating Savings vs. No Retrofit');
end

%% 10. Apply readable dark styling to legends
if settings.showFigures
    allFigures = findall(groot,'Type','figure');
    for k = 1:numel(allFigures)
        lgds = findall(allFigures(k),'Type','legend');
        for n = 1:numel(lgds)
            lgds(n).Color = theme.axes;
            lgds(n).TextColor = theme.foreground;
            lgds(n).EdgeColor = theme.grid;
        end
    end
end
