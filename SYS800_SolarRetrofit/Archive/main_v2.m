%% SYS 800 - Residential Solar Retrofit Decision Model
% Technical performance model: existing aged PV + new PV + battery storage.
% Run from the project root containing data/ and +sim/.
% Figures show model results; Command Window reports verification only.
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
battery.capacity_kWh = 10;         % Reference battery for hourly diagnostics
battery.maxChargePower_kW = 5;
battery.maxDischargePower_kW = 5;
battery.roundTripEfficiency = 0.90;
battery.initialSOC_kWh = 0;

settings.hoursPerYear = 8760;
settings.timeStep_hours = 1;
settings.showDiagnosticPlots = true;
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
retrofitCycles = NaN(numRetrofitScenarios,1); % Undefined for zero battery
retrofitFullHours_pct = NaN(numRetrofitScenarios,1);
retrofitEmptyHours_pct = NaN(numRetrofitScenarios,1);
retrofitAverageSOC_pct = NaN(numRetrofitScenarios,1);
monthlyRetrofitImports_kWh = zeros(12,numRetrofitScenarios);

% Preserve hourly grid exchanges for economic analysis.
% Rows = hours (8760); columns = retrofit scenarios (15).
hourlyRetrofitImports_kWh = zeros(settings.hoursPerYear, ...
    numRetrofitScenarios);
hourlyRetrofitExports_kWh = zeros(settings.hoursPerYear, ...
    numRetrofitScenarios);

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
        
        % Store complete hourly import/export profiles.
        hourlyRetrofitImports_kWh(:,scenarioIndex) = ...
            scenario.gridImport_kWh(:);

        hourlyRetrofitExports_kWh(:,scenarioIndex) = ...
            scenario.gridExport_kWh(:);


        retrofitDischarge_kWh(scenarioIndex) = sum(scenario.batteryDischarge_kWh);
        retrofitImportReduction_pct(scenarioIndex) = 100* ...
            (annualGridImport_kWh-retrofitImports_kWh(scenarioIndex))/annualGridImport_kWh;

        for m = 1:12
            idx = monthStartHours(m):monthEndHours(m);
            monthlyRetrofitImports_kWh(m,scenarioIndex) = sum(scenario.gridImport_kWh(idx));
        end

        soc = scenario.stateOfCharge_kWh;
        if testBattery.capacity_kWh > 0
            retrofitCycles(scenarioIndex) = retrofitDischarge_kWh(scenarioIndex) / ...
                (testBattery.capacity_kWh*eta);
            retrofitFullHours_pct(scenarioIndex) = 100*mean(soc>=0.99*testBattery.capacity_kWh);
            retrofitEmptyHours_pct(scenarioIndex) = 100*mean(soc<=0.01*testBattery.capacity_kWh);
            retrofitAverageSOC_pct(scenarioIndex) = 100*mean(soc)/testBattery.capacity_kWh;
        end

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

% Battery-only results and diagnostics are derived from the same simulations.
batteryOnly = retrofitAddedPV_kW==0;
batteryComparison = retrofitComparison(batteryOnly,:);
batteryUtilization = table(retrofitBattery_kWh(batteryOnly), ...
    retrofitFullHours_pct(batteryOnly),retrofitEmptyHours_pct(batteryOnly), ...
    retrofitAverageSOC_pct(batteryOnly),retrofitCycles(batteryOnly), ...
    'VariableNames',{'Capacity_kWh','PercentHoursFull', ...
    'PercentHoursEmpty','AverageSOC_pct','EquivalentFullCycles'});
% PV-only augmentation results are also derived from the same simulations.
augmentationComparison = retrofitComparison(retrofitBattery_kWh==0,:);

%% 5. Verification (Command Window only)
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

%% Verify hourly scenario storage

assert(isequal(size(hourlyRetrofitImports_kWh), ...
    [settings.hoursPerYear,numRetrofitScenarios]), ...
    "Incorrect hourly import matrix dimensions.");

assert(isequal(size(hourlyRetrofitExports_kWh), ...
    [settings.hoursPerYear,numRetrofitScenarios]), ...
    "Incorrect hourly export matrix dimensions.");

assert(all(abs(sum(hourlyRetrofitImports_kWh,1)' - ...
    retrofitImports_kWh) < tolerance), ...
    "Hourly import totals do not match annual results.");

assert(all(abs(sum(hourlyRetrofitExports_kWh,1)' - ...
    retrofitExports_kWh) < tolerance), ...
    "Hourly export totals do not match annual results.");

assert(all(abs(hourlyRetrofitImports_kWh(:,baseIdx) - ...
    baseline.gridImport_kWh(:)) < tolerance), ...
    "Baseline hourly imports do not match.");

assert(all(abs(hourlyRetrofitExports_kWh(:,baseIdx) - ...
    baseline.gridExport_kWh(:)) < tolerance), ...
    "Baseline hourly exports do not match.");

fprintf("Hourly import/export storage for all %d scenarios: PASS\n", ...
    numRetrofitScenarios);


%% 5B. Preliminary NEM 1.0 and NEM 2.0 Economic Analysis
% Uses rounded SCE TOU-D-4-9PM reference rates.
% NBC = 0 is a sensitivity assumption, NOT a verified SCE rate.
% Results are preliminary research estimates, not utility bills.

sceTariff = econ.loadSCETariffs();
billingAssumptions = econ.loadSCEBillingAssumptions();

% Reference calendar: 2026
% The 2026 tariff values are applied to a representative
% 2026 calendar, so weekday/weekend assignments follow 2026.
economicYear = 2026;

[hourlyTOURates, economicCalendar] = econ.buildTOURates( ...
    economicYear,"TOU-D-4-9PM",sceTariff.rateTable);


% Verify 2026 NBT calendar alignment

[nbtExportRates,nbtComponents] = ...
    econ.loadNBTExportRates( ...
    "data/NBT26_2026_hourly_components.csv",2026);

assert(isequal( ...
    economicCalendar.Timestamp, ...
    nbtComponents.Timestamp), ...
    "NBT and economic calendar timestamps do not match.");

assert(numel(hourlyTOURates)==numel(nbtExportRates));

fprintf("2026 economic calendar and NBT alignment: PASS\n");

%Resume
assert(numel(hourlyTOURates)==settings.hoursPerYear, ...
    "TOU rates must contain 8760 hourly values.");

assert(height(economicCalendar)==settings.hoursPerYear, ...
    "Economic calendar must contain 8760 hourly records.");

% Provisional zero-NBC sensitivity case.
% Replace only after tariff-specific verification.
nem1NBC_perkWh = 0;
nem2NBC_perkWh = 0;

nscRate_perkWh = billingAssumptions.nscRate_perkWh;
fixedAnnualCharge = billingAssumptions.fixedAnnualCharge;

nem1AnnualCost = zeros(numRetrofitScenarios,1);
nem2AnnualCost = zeros(numRetrofitScenarios,1);

for s = 1:numRetrofitScenarios

    imports = hourlyRetrofitImports_kWh(:,s);
    exports = hourlyRetrofitExports_kWh(:,s);

    nem1 = econ.calculateNEMBill( ...
        imports,exports,hourlyTOURates,economicCalendar,1, ...
        nbcRate_perkWh=nem1NBC_perkWh, ...
        nscRate_perkWh=nscRate_perkWh, ...
        fixedAnnualCharge=fixedAnnualCharge);

    nem2 = econ.calculateNEMBill( ...
        imports,exports,hourlyTOURates,economicCalendar,2, ...
        nbcRate_perkWh=nem2NBC_perkWh, ...
        nscRate_perkWh=nscRate_perkWh, ...
        fixedAnnualCharge=fixedAnnualCharge);

    nem1AnnualCost(s) = nem1.annualCost;
    nem2AnnualCost(s) = nem2.annualCost;

end

%% Baseline-relative annual savings

baselineScenario = find(baseIdx);

nem1BaselineCost = nem1AnnualCost(baselineScenario);
nem2BaselineCost = nem2AnnualCost(baselineScenario);

nem1AnnualSavings = nem1BaselineCost - nem1AnnualCost;
nem2AnnualSavings = nem2BaselineCost - nem2AnnualCost;

%% Economic comparison table

economicComparison = table( ...
    retrofitAddedPV_kW, ...
    retrofitBattery_kWh, ...
    nem1AnnualCost, ...
    nem2AnnualCost, ...
    nem1AnnualSavings, ...
    nem2AnnualSavings, ...
    'VariableNames', ...
    {'AddedPV_kW','BatteryCapacity_kWh', ...
     'NEM1_AnnualCost','NEM2_AnnualCost', ...
     'NEM1_AnnualSavings','NEM2_AnnualSavings'});

%% Economic verification

assert(height(economicComparison)==numRetrofitScenarios, ...
    "Economic scenario count mismatch.");

assert(all(isfinite(nem1AnnualCost)) && ...
       all(isfinite(nem2AnnualCost)), ...
    "Nonfinite economic results detected.");

assert(abs(nem1AnnualSavings(baselineScenario))<1e-8);
assert(abs(nem2AnnualSavings(baselineScenario))<1e-8);

% With both NBC rates set to zero, the current NEM 1.0
% and NEM 2.0 calculation functions must produce identical
% results for identical hourly energy flows.
assert(all(abs(nem1AnnualCost-nem2AnnualCost)<1e-8), ...
    "Unexpected NEM 1.0 / NEM 2.0 difference.");

fprintf("\n=== PRELIMINARY ECONOMIC VERIFICATION ===\n");
fprintf("TOU-D-4-9PM hourly rate construction: PASS\n");
fprintf("Economic calculations for %d scenarios: PASS\n", ...
    numRetrofitScenarios);
fprintf("Baseline annual modeled cost: $%.2f\n", ...
    nem1BaselineCost);
fprintf("NEM 1.0 / NEM 2.0 zero-NBC equivalence: PASS\n");
fprintf("Economic results use provisional billing assumptions.\n");

%% 6. Figures and results table
if settings.showFigures
    % Figure 1: Monthly baseline energy accounting.
    figure('Name','01 - Baseline Monthly Performance');
    bar(1:12, ...
        [monthlyDemand_kWh monthlySolar_kWh monthlyImport_kWh monthlyExport_kWh], ...
        'grouped');
    xticks(1:12);
    xticklabels(monthNames);
    xlim([0.5 12.5]);
    xlabel('Month');
    ylabel('Monthly energy (kWh)');
    title('Existing 6 kW PV System - Monthly Energy Flows');
    legend('Household demand','Aged PV generation','Grid imports','Grid exports', ...
        'Location','northoutside','Orientation','horizontal');
    grid on;

    % Figure 2: Annual import reduction for all realistic retrofit options.
    figure('Name','02 - Retrofit Import Reduction');
    hold on;
    for i = 1:numAddedPV
        idx = retrofitAddedPV_kW==addedPVSizes(i);
        plot(retrofitBattery_kWh(idx),retrofitImportReduction_pct(idx), ...
            '-o','LineWidth',1.7,'MarkerSize',6, ...
            'DisplayName',sprintf('+%g kW new PV',addedPVSizes(i)));
    end
    hold off;
    xlabel('Battery capacity (kWh)');
    ylabel('Reduction in annual grid imports (%)');
    title('Realistic Retrofit Trade Study - Grid Import Reduction');
    legend('Location','northwest');
    grid on;

    % Figure 3: Annual imports and exports for all retrofit configurations.
    figure('Name','03 - Retrofit Grid Exchanges');
    tiledlayout(1,2,'TileSpacing','compact');
    nexttile; hold on;
    for i = 1:numAddedPV
        idx = retrofitAddedPV_kW==addedPVSizes(i);
        plot(retrofitBattery_kWh(idx),retrofitImports_kWh(idx),'-o', ...
            'LineWidth',1.5,'DisplayName',sprintf('+%g kW PV',addedPVSizes(i)));
    end
    hold off; grid on; xlabel('Battery (kWh)'); ylabel('Imports (kWh/year)');
    title('Annual Grid Imports'); legend('Location','northeast');
    nexttile; hold on;
    for i = 1:numAddedPV
        idx = retrofitAddedPV_kW==addedPVSizes(i);
        plot(retrofitBattery_kWh(idx),retrofitExports_kWh(idx),'-o', ...
            'LineWidth',1.5,'DisplayName',sprintf('+%g kW PV',addedPVSizes(i)));
    end
    hold off; grid on; xlabel('Battery (kWh)'); ylabel('Exports (kWh/year)');
    title('Annual Grid Exports'); legend('Location','northeast');

    % Figure 4: Monthly grid imports for battery-only scenarios.
    figure('Name','04 - Seasonal Battery Performance');
    hold on;
    for j = 1:numBattery
        idx = retrofitAddedPV_kW==0 & retrofitBattery_kWh==batterySizes(j);
        plot(1:12,monthlyRetrofitImports_kWh(:,idx),'-o', ...
            'LineWidth',1.3,'DisplayName',sprintf('%g kWh battery',batterySizes(j)));
    end
    hold off; grid on; xlim([1 12]); xticks(1:12); xticklabels(monthNames);
    xlabel('Month'); ylabel('Grid imports (kWh/month)');
    title('Monthly Grid Imports - Existing PV with Battery Storage');
    legend('Location','northoutside','Orientation','horizontal');

    % Figure 5: Battery state-of-charge behavior and equivalent full cycles.
    batteryPositive = batteryOnly & retrofitBattery_kWh>0;
    figure('Name','05 - Battery Utilization');
    tiledlayout(1,2,'TileSpacing','compact');
    nexttile;
    plot(retrofitBattery_kWh(batteryPositive), ...
        retrofitFullHours_pct(batteryPositive),'-o','LineWidth',1.6); hold on;
    plot(retrofitBattery_kWh(batteryPositive), ...
        retrofitEmptyHours_pct(batteryPositive),'-o','LineWidth',1.6); hold off;
    xlabel('Battery capacity (kWh)'); ylabel('Share of hours (%)');
    title('Near-Full and Near-Empty Hours');
    legend('Near full','Near empty','Location','best'); grid on;
    nexttile;
    plot(retrofitBattery_kWh(batteryPositive),retrofitCycles(batteryPositive), ...
        '-o','LineWidth',1.6);
    xlabel('Battery capacity (kWh)'); ylabel('Equivalent full cycles/year');
    title('Battery Cycling'); grid on;

    % Figure 6: Interactive MATLAB figure table (no Command Window table).
    tableFig = uifigure('Name','06 - Realistic Retrofit Results', ...
        'Position',[120 120 920 480], ...
        'Color',theme.background);
    uilabel(tableFig,'Text','Existing 6 kW PV + New PV + Battery Storage', ...
        'Position',[20 445 850 25],'FontSize',16,'FontWeight','bold', ...
        'FontColor',theme.foreground);
    displayTable = retrofitComparison;
    displayTable.Generation_kWh = round(displayTable.Generation_kWh,1);
    displayTable.GridImports_kWh = round(displayTable.GridImports_kWh,1);
    displayTable.GridExports_kWh = round(displayTable.GridExports_kWh,1);
    displayTable.ImportReduction_pct = round(displayTable.ImportReduction_pct,2);
    % Keep table cells at MATLAB's default readable colors. Some MATLAB
    % releases do not support the FontColor property on uitable.
    uitable(tableFig,'Data',displayTable,'Position',[20 20 880 420], ...
        'ColumnWidth',{95 145 135 130 130 155});
end

%% 7. Optional hourly diagnostic (first 7 days)
if settings.showDiagnosticPlots
    hours = 1:168;
    figure('Name','07 - First-Week Diagnostics');
    tiledlayout(2,1,'TileSpacing','compact');
    nexttile;
    plot(hours,demandHourly_kWh(hours),'LineWidth',1.2); hold on;
    plot(hours,solarAged_kWh(hours),'LineWidth',1.2); hold off;
    title('Household Demand and Aged PV Generation - First Week');
    ylabel('Energy per hour (kWh)');
    legend('Demand','PV generation','Location','best'); grid on;
    nexttile;
    plot(hours,baseline.gridImport_kWh(hours),'LineWidth',1.2); hold on;
    plot(hours,baseline.gridExport_kWh(hours),'LineWidth',1.2); hold off;
    xlabel('Simulation hour'); ylabel('Energy per hour (kWh)');
    title('Baseline Grid Imports and Exports - First Week');
    legend('Imports','Exports','Location','best'); grid on;
end

%% 8. Finalize dark styling for all chart legends
% Legends are styled after creation so this also covers tiled layouts.
allFigures = findall(groot,'Type','figure');
for k = 1:numel(allFigures)
    lgds = findall(allFigures(k),'Type','legend');
    for n = 1:numel(lgds)
        lgds(n).Color = theme.axes;
        lgds(n).TextColor = theme.foreground;
        lgds(n).EdgeColor = theme.grid;
    end
end
