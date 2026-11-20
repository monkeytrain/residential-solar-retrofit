
%% SYS 800 - Residential Solar Retrofit Model
% Baseline Residential System

clear;
clc;
close all;

%% 1. Location
location.city = "Palmdale";
location.state = "California";
location.latitude = 34.58;
location.longitude = -118.12;

%% 2. Residential Building
house.area_sqft = 1500;
house.occupants = 3;
house.type = "Single Family Detached";
house.heating = "Natural Gas";
house.cooling = "Central AC";
house.waterHeating = "Natural Gas";

%% 3. Existing Solar PV System
pv.capacity_kW = 6;
pv.capacityScenarios_kW = [4, 6, 8, 10];
pv.age_years = 10;
pv.degradationRate = 0.005;


%% 4. Battery Storage

% Battery capacity scenarios for future comparison
battery.capacityScenarios_kWh = [0, 5, 10, 15, 20];

% Initial battery test configuration
battery.capacity_kWh = 10;

% Battery charging and discharging power limits
battery.maxChargePower_kW = 5;
battery.maxDischargePower_kW = 5;

% Battery round-trip efficiency
battery.roundTripEfficiency = 0.90;

% Initial battery state of charge
battery.initialSOC_kWh = 0;

%% 5. Simulation Settings
settings.hoursPerYear = 8760;
settings.timeStep_hours = 1;

settings.showDiagnosticPlots = true;

%% 6. Display Configuration
disp("Residential Solar Retrofit Model");
disp("Location: " + location.city);
disp("House Size: " + house.area_sqft + " sq ft");
disp("PV Capacity: " + pv.capacity_kW + " kW");

%% 7. Import PVWatts Hourly Data

% Import the hourly data, starting at row 33
pvData = readtable("data/pvwatts_hourly.csv", ...
    "NumHeaderLines", 31, ...
    "VariableNamingRule", "preserve");

% Check the number of hourly records
numHours = height(pvData);
assert(numHours == settings.hoursPerYear, ...
    "PVWatts data does not contain the expected number of hours.");

disp("Number of hourly records: " + numHours);

% Extract hourly AC output in watts
solarPower_W = pvData.("AC System Output (W)");

% Convert watts to kilowatt-hours
solarEnergy_kWh = solarPower_W / 1000 * settings.timeStep_hours;

% Calculate total annual generation
annualSolar_kWh = sum(solarEnergy_kWh);

%% 8. Prepare Data for Visualization

% Create an hourly time index
hour = 1:numHours;

% Extract solar irradiance data
solarIrradiance = pvData.("Plane of Array Irradiance (W/m2)");

%% 9. Diagnostic Plots

if settings.showDiagnosticPlots

    % Plot 1: Solar Generation
    figure;
    plot(hour(1:168), solarEnergy_kWh(1:168), ...
        "LineWidth", 1.5);

    xlabel("Hour of Simulation");
    ylabel("Solar Generation (kWh)");
    title("PV Generation - First 7 Days of January");
    grid on;

    % Plot 2: Solar Generation vs. Irradiance
    figure;

    yyaxis left;
    plot(hour(1:168), solarEnergy_kWh(1:168));
    ylabel("Solar Generation (kWh)");

    yyaxis right;
    plot(hour(1:168), solarIrradiance(1:168));
    ylabel("Solar Irradiance (W/m^2)");

    xlabel("Hour of Simulation");
    title("Solar Generation vs. Irradiance");
    grid on;

end

%% 10. Apply Solar Panel Degradation

% Calculate remaining performance after 10 years
degradationFactor = (1 - pv.degradationRate)^pv.age_years;

% Adjust hourly generation for system age
solarAged_kWh = solarEnergy_kWh .* degradationFactor;

% Calculate annual generation after degradation
annualSolarAged_kWh = sum(solarAged_kWh);

% Display results
fprintf("Original Annual Generation: %.1f kWh\n", annualSolar_kWh);
fprintf("Aged Annual Generation: %.1f kWh\n", annualSolarAged_kWh);
fprintf("Remaining Performance: %.2f%%\n", degradationFactor * 100);

%% 11. Import ResStock Household Electricity Demand

% ResStock Building ID: 198638
% Location: Los Angeles County
% Weather Station: Lancaster Fox Field
% Building Area: 1690 sq ft
% Occupants: 3
% Existing PV: None

% Import 15-minute electricity consumption data
loadData = parquetread("data/198638-0.parquet");

% Verify the expected number of 15-minute records
assert(height(loadData) == 35040, ...
    "ResStock data does not contain 35040 records.");

% Extract electricity consumed during each 15-minute interval (kWh)
demand15min_kWh = ...
    loadData.out_electricity_total_energy_consumption;

% Aggregate four 15-minute intervals into each hour
demandHourly_kWh = sum(reshape(demand15min_kWh, 4, []), 1)';

% Verify the hourly data length
assert(length(demandHourly_kWh) == settings.hoursPerYear, ...
    "Hourly demand does not match the simulation duration.");

% Calculate annual electricity consumption
annualDemand_kWh = sum(demandHourly_kWh);

% Display results
fprintf("Annual Household Demand: %.1f kWh\n", annualDemand_kWh);
fprintf("Hourly Demand Records: %d\n", length(demandHourly_kWh));

%% 12. Calculate Baseline Energy Flows

% Calculate hourly electricity flows without battery storage
baseline = sim.calculateEnergyFlows(demandHourly_kWh, solarAged_kWh);

% Calculate annual grid electricity imports and exports
annualGridImport_kWh = sum(baseline.gridImport_kWh);
annualGridExport_kWh = sum(baseline.gridExport_kWh);
annualSelfConsumed_kWh = sum(baseline.selfConsumed_kWh);

% Display baseline simulation results
disp(" ");
disp("=== BASELINE ENERGY FLOW RESULTS ===");

fprintf("Annual Household Demand: %.1f kWh\n", annualDemand_kWh);
fprintf("Annual Solar Generation: %.1f kWh\n", annualSolarAged_kWh);
fprintf("Annual Solar Self-Consumed: %.1f kWh\n", annualSelfConsumed_kWh);
fprintf("Annual Grid Imports: %.1f kWh\n", annualGridImport_kWh);
fprintf("Annual Grid Exports: %.1f kWh\n", annualGridExport_kWh);
fprintf("Solar Self-Consumption: %.1f%%\n", ...
    100 * baseline.selfConsumptionRatio);
fprintf("Solar Self-Sufficiency: %.1f%%\n", ...
    100 * baseline.selfSufficiencyRatio);

%% 13. Visualize Baseline Energy Flows

if settings.showDiagnosticPlots

    % Select the first seven days (168 hours)
    plotHours = 1:168;

    % Plot household demand and solar generation
    figure;

    plot(plotHours, demandHourly_kWh(plotHours), ...
        "LineWidth", 1.5);
    hold on;

    plot(plotHours, solarAged_kWh(plotHours), ...
        "LineWidth", 1.5);

    hold off;

    xlabel("Hour of Simulation");
    ylabel("Energy per Hour (kWh)");
    title("Baseline Household Demand vs. Solar Generation");

    legend("Household Demand", "Solar Generation");
    grid on;

end

%% 14. Visualize Grid Imports and Exports

if settings.showDiagnosticPlots

    % Plot the first seven days
    plotHours = 1:168;

    figure;

    plot(plotHours, baseline.gridImport_kWh(plotHours), ...
        "LineWidth", 1.5);
    hold on;

    plot(plotHours, baseline.gridExport_kWh(plotHours), ...
        "LineWidth", 1.5);

    hold off;

    xlabel("Hour of Simulation");
    ylabel("Energy per Hour (kWh)");
    title("Baseline Grid Imports vs. Exports");

    legend("Grid Imports", "Grid Exports");
    grid on;

end

%% 15. Monthly Energy Analysis

% Number of days in each month (non-leap year)
daysPerMonth = [31 28 31 30 31 30 31 31 30 31 30 31];

% Convert days into hourly boundaries
monthEndHours = cumsum(daysPerMonth) * 24;
monthStartHours = [1, monthEndHours(1:end-1) + 1];

% Initialize monthly results
monthlyDemand_kWh = zeros(12,1);
monthlySolar_kWh = zeros(12,1);
monthlyImport_kWh = zeros(12,1);
monthlyExport_kWh = zeros(12,1);

% Calculate monthly totals
for m = 1:12

    idx = monthStartHours(m):monthEndHours(m);

    monthlyDemand_kWh(m) = sum(demandHourly_kWh(idx));
    monthlySolar_kWh(m) = sum(solarAged_kWh(idx));
    monthlyImport_kWh(m) = sum(baseline.gridImport_kWh(idx));
    monthlyExport_kWh(m) = sum(baseline.gridExport_kWh(idx));

end

% Display monthly results
monthlyResults = table( ...
    string(month(datetime(2025,1:12,1), "name"))', ...
    monthlyDemand_kWh, ...
    monthlySolar_kWh, ...
    monthlyImport_kWh, ...
    monthlyExport_kWh, ...
    'VariableNames', { ...
    'Month', 'Demand_kWh', 'Solar_kWh', ...
    'GridImport_kWh', 'GridExport_kWh'});

disp(monthlyResults);

%% 16. Simulate Battery Storage

% Run the battery dispatch model for all 8760 hours
batteryResults = sim.calculateBatteryDispatch( ...
    demandHourly_kWh, solarAged_kWh, battery);

% Calculate annual energy flows with battery storage
batteryGridImport_kWh = sum(batteryResults.gridImport_kWh);
batteryGridExport_kWh = sum(batteryResults.gridExport_kWh);

batteryCharge_kWh = sum(batteryResults.batteryCharge_kWh);
batteryDischarge_kWh = sum(batteryResults.batteryDischarge_kWh);

% Compare against the no-battery baseline
importReduction_kWh = annualGridImport_kWh - batteryGridImport_kWh;
exportReduction_kWh = annualGridExport_kWh - batteryGridExport_kWh;

% Display results
disp(" ");
disp("=== BATTERY STORAGE RESULTS ===");

fprintf("Battery Capacity: %.1f kWh\n", battery.capacity_kWh);
fprintf("Grid Imports Without Battery: %.1f kWh\n", annualGridImport_kWh);
fprintf("Grid Imports With Battery: %.1f kWh\n", batteryGridImport_kWh);
fprintf("Grid Exports Without Battery: %.1f kWh\n", annualGridExport_kWh);
fprintf("Grid Exports With Battery: %.1f kWh\n", batteryGridExport_kWh);

fprintf("Annual Battery Charging: %.1f kWh\n", batteryCharge_kWh);
fprintf("Annual Battery Discharging: %.1f kWh\n", batteryDischarge_kWh);

fprintf("Grid Import Reduction: %.1f kWh\n", importReduction_kWh);
fprintf("Grid Export Reduction: %.1f kWh\n", exportReduction_kWh);


%% 17. Verify Battery Simulation

% Calculate one-way efficiency
eta = sqrt(battery.roundTripEfficiency);

% Reconstruct battery state of charge at the start of each hour
socStart = [battery.initialSOC_kWh; ...
    batteryResults.stateOfCharge_kWh(1:end-1)];

% Check battery capacity limits
assert(all(batteryResults.stateOfCharge_kWh >= -1e-9), ...
    "Battery state of charge fell below zero.");

assert(all(batteryResults.stateOfCharge_kWh <= ...
    battery.capacity_kWh + 1e-9), ...
    "Battery exceeded its capacity.");

% Check charging and discharging power limits
assert(all(batteryResults.batteryCharge_kWh <= ...
    battery.maxChargePower_kW * settings.timeStep_hours + 1e-9), ...
    "Battery charging power limit exceeded.");

assert(all(batteryResults.batteryDischarge_kWh <= ...
    battery.maxDischargePower_kW * settings.timeStep_hours + 1e-9), ...
    "Battery discharging power limit exceeded.");

% Verify battery state-of-charge changes
socExpected = socStart + ...
    batteryResults.batteryCharge_kWh * eta - ...
    batteryResults.batteryDischarge_kWh / eta;

socError = max(abs( ...
    batteryResults.stateOfCharge_kWh - socExpected));

% Verify whole-system hourly energy conservation
% Charging is energy absorbed; discharging is energy supplied.
energyError = demandHourly_kWh + ...
    batteryResults.batteryCharge_kWh + ...
    batteryResults.gridExport_kWh - ...
    solarAged_kWh - ...
    batteryResults.batteryDischarge_kWh - ...
    batteryResults.gridImport_kWh;

maxEnergyError = max(abs(energyError));

assert(socError < 1e-9, ...
    "Battery state-of-charge conservation failed.");

assert(maxEnergyError < 1e-9, ...
    "Hourly energy conservation failed.");

disp(" ");
disp("=== BATTERY VERIFICATION RESULTS ===");

fprintf("Minimum Battery SOC: %.4f kWh\n", ...
    min(batteryResults.stateOfCharge_kWh));

fprintf("Maximum Battery SOC: %.4f kWh\n", ...
    max(batteryResults.stateOfCharge_kWh));

fprintf("Maximum SOC Error: %.12f kWh\n", socError);

fprintf("Maximum Hourly Energy Error: %.12f kWh\n", ...
    maxEnergyError);

disp("All battery verification checks passed.");

%% 18. Battery Capacity Trade Study

% Define battery capacities to evaluate
capacities = battery.capacityScenarios_kWh;

% Initialize result arrays
numScenarios = length(capacities);

scenarioImports_kWh = zeros(numScenarios,1);
scenarioExports_kWh = zeros(numScenarios,1);
scenarioImportReduction_pct = zeros(numScenarios,1);

% Run each battery capacity scenario
for i = 1:numScenarios

    % Create a copy of the battery configuration
    testBattery = battery;

    % Set the battery capacity for this scenario
    testBattery.capacity_kWh = capacities(i);

    % Simulate the full year
    scenario = sim.calculateBatteryDispatch( ...
        demandHourly_kWh, solarAged_kWh, testBattery);

    % Calculate annual grid imports and exports
    scenarioImports_kWh(i) = sum(scenario.gridImport_kWh);
    scenarioExports_kWh(i) = sum(scenario.gridExport_kWh);

    % Calculate percentage reduction in grid imports
    scenarioImportReduction_pct(i) = ...
        100 * (annualGridImport_kWh - scenarioImports_kWh(i)) ...
        / annualGridImport_kWh;

end

% Create results table
batteryComparison = table( ...
    capacities(:), ...
    scenarioImports_kWh, ...
    scenarioExports_kWh, ...
    scenarioImportReduction_pct, ...
    'VariableNames', { ...
    'BatteryCapacity_kWh', ...
    'GridImports_kWh', ...
    'GridExports_kWh', ...
    'ImportReduction_pct'});

disp(" ");
disp("=== BATTERY CAPACITY COMPARISON ===");
disp(batteryComparison);

%% 19. Verify Battery Capacity Trade Study

% Verify zero-capacity battery matches the original baseline
assert(abs(scenarioImports_kWh(1) - annualGridImport_kWh) < 1e-6, ...
    "Zero-capacity scenario does not match baseline imports.");

assert(abs(scenarioExports_kWh(1) - annualGridExport_kWh) < 1e-6, ...
    "Zero-capacity scenario does not match baseline exports.");

% Verify increasing capacity does not increase grid imports
assert(all(diff(scenarioImports_kWh) <= 1e-6), ...
    "Grid imports increased with battery capacity.");

% Verify increasing capacity does not increase grid exports
assert(all(diff(scenarioExports_kWh) <= 1e-6), ...
    "Grid exports increased with battery capacity.");

disp(" ");
disp("=== BATTERY TRADE STUDY VERIFICATION ===");
disp("Zero-capacity scenario matches baseline.");
disp("Grid imports decrease or remain constant with capacity.");
disp("Grid exports decrease or remain constant with capacity.");
disp("All trade study verification checks passed.");

%% 20. Monthly Battery Performance Analysis

% Initialize monthly grid import results
monthlyBatteryImports_kWh = zeros(12, numScenarios);

% Simulate each battery capacity
for i = 1:numScenarios

    % Configure battery capacity
    testBattery = battery;
    testBattery.capacity_kWh = capacities(i);

    % Run full-year battery simulation
    scenario = sim.calculateBatteryDispatch( ...
        demandHourly_kWh, solarAged_kWh, testBattery);

    % Calculate monthly grid imports
    for m = 1:12

        idx = monthStartHours(m):monthEndHours(m);

        monthlyBatteryImports_kWh(m,i) = ...
            sum(scenario.gridImport_kWh(idx));

    end

end

% Create monthly results table
monthlyBatteryComparison = array2table( ...
    monthlyBatteryImports_kWh, ...
    'VariableNames', { ...
    'Battery_0kWh', ...
    'Battery_5kWh', ...
    'Battery_10kWh', ...
    'Battery_15kWh', ...
    'Battery_20kWh'});

monthlyBatteryComparison.Month = monthlyResults.Month;

% Move month names to first column
monthlyBatteryComparison = movevars( ...
    monthlyBatteryComparison, 'Month', 'Before', 1);

disp(" ");
disp("=== MONTHLY BATTERY PERFORMANCE ===");
disp(monthlyBatteryComparison);

%% 21. Battery State-of-Charge Utilization Analysis

% Exclude zero-capacity scenario
batterySizes = capacities(capacities > 0);

numBatterySizes = length(batterySizes);

percentFull = zeros(numBatterySizes,1);
percentEmpty = zeros(numBatterySizes,1);
averageSOC_pct = zeros(numBatterySizes,1);

% Evaluate each battery configuration
for i = 1:numBatterySizes

    testBattery = battery;
    testBattery.capacity_kWh = batterySizes(i);

    % Run annual battery simulation
    scenario = sim.calculateBatteryDispatch( ...
        demandHourly_kWh, solarAged_kWh, testBattery);

    soc = scenario.stateOfCharge_kWh;

    % Percentage of hours battery is at or near full capacity
    percentFull(i) = 100 * mean( ...
        soc >= 0.99 * testBattery.capacity_kWh);

    % Percentage of hours battery is at or near empty
    percentEmpty(i) = 100 * mean( ...
        soc <= 0.01 * testBattery.capacity_kWh);

    % Average battery state of charge as percentage of capacity
    averageSOC_pct(i) = 100 * mean(soc) ...
        / testBattery.capacity_kWh;

end

% Display results
batteryUtilization = table( ...
    batterySizes(:), ...
    percentFull, ...
    percentEmpty, ...
    averageSOC_pct, ...
    'VariableNames', { ...
    'Capacity_kWh', ...
    'PercentHoursFull', ...
    'PercentHoursEmpty', ...
    'AverageSOC_pct'});

disp(" ");
disp("=== BATTERY CAPACITY UTILIZATION ===");
disp(batteryUtilization);

%% 22. Battery Equivalent Full Cycle Analysis

% Exclude zero-capacity scenario
batterySizes = capacities(capacities > 0);

% Initialize results
annualDischarge_kWh = zeros(length(batterySizes),1);
equivalentFullCycles = zeros(length(batterySizes),1);

for i = 1:length(batterySizes)

    % Configure battery capacity
    testBattery = battery;
    testBattery.capacity_kWh = batterySizes(i);

    % Simulate annual operation
    scenario = sim.calculateBatteryDispatch( ...
        demandHourly_kWh, solarAged_kWh, testBattery);

    % Calculate annual battery energy delivered to household
    annualDischarge_kWh(i) = ...
        sum(scenario.batteryDischarge_kWh);

    % Convert delivered energy to equivalent full cycles
    equivalentFullCycles(i) = ...
        annualDischarge_kWh(i) / ...
        (batterySizes(i) * sqrt(battery.roundTripEfficiency));

end

% Create results table
batteryCycling = table( ...
    batterySizes(:), ...
    annualDischarge_kWh, ...
    equivalentFullCycles, ...
    'VariableNames', { ...
    'Capacity_kWh', ...
    'AnnualDischarge_kWh', ...
    'EquivalentFullCycles'});

disp(" ");
disp("=== BATTERY CYCLING ANALYSIS ===");
disp(batteryCycling);

%% 23. PV Capacity Trade Study

% PV capacities to evaluate
pvCapacities_kW = pv.capacityScenarios_kW;

numPVScenarios = length(pvCapacities_kW);

% Initialize results
pvGeneration_kWh = zeros(numPVScenarios,1);
pvGridImports_kWh = zeros(numPVScenarios,1);
pvGridExports_kWh = zeros(numPVScenarios,1);
pvSelfConsumed_kWh = zeros(numPVScenarios,1);

for i = 1:numPVScenarios

    % Scale existing aged PV generation profile
    scaleFactor = pvCapacities_kW(i) / pv.capacity_kW;

    scenarioSolar_kWh = solarAged_kWh * scaleFactor;

    % Run baseline energy flow model without a battery
    scenario = sim.calculateEnergyFlows( ...
        demandHourly_kWh, scenarioSolar_kWh);

    % Calculate annual totals
    pvGeneration_kWh(i) = sum(scenarioSolar_kWh);

    pvGridImports_kWh(i) = sum(scenario.gridImport_kWh);

    pvGridExports_kWh(i) = sum(scenario.gridExport_kWh);

    pvSelfConsumed_kWh(i) = sum(scenario.selfConsumed_kWh);

end

% Create comparison table
pvComparison = table( ...
    pvCapacities_kW(:), ...
    pvGeneration_kWh, ...
    pvGridImports_kWh, ...
    pvGridExports_kWh, ...
    pvSelfConsumed_kWh, ...
    'VariableNames', { ...
    'PVCapacity_kW', ...
    'PVGeneration_kWh', ...
    'GridImports_kWh', ...
    'GridExports_kWh', ...
    'SelfConsumed_kWh'});

disp(" ");
disp("=== PV CAPACITY COMPARISON ===");
disp(pvComparison);

%% 24. Verify PV Capacity Trade Study

% Verify 6 kW scenario matches original baseline
baselinePVIndex = find(pvCapacities_kW == pv.capacity_kW);

assert(numel(baselinePVIndex) == 1, ...
    "Exactly one baseline PV scenario must be present.");

assert(abs(pvGridImports_kWh(baselinePVIndex) - ...
    annualGridImport_kWh) < 1e-6, ...
    "Baseline PV imports do not match.");

assert(abs(pvGridExports_kWh(baselinePVIndex) - ...
    annualGridExport_kWh) < 1e-6, ...
    "Baseline PV exports do not match.");

% Verify annual PV energy conservation
pvEnergyError = pvGeneration_kWh - ...
    pvSelfConsumed_kWh - pvGridExports_kWh;

assert(all(abs(pvEnergyError) < 1e-6), ...
    "PV energy conservation failed.");

% Verify demand energy conservation
demandEnergyError = annualDemand_kWh - ...
    pvSelfConsumed_kWh - pvGridImports_kWh;

assert(all(abs(demandEnergyError) < 1e-6), ...
    "Demand energy conservation failed.");

% Verify expected trends
assert(all(diff(pvGeneration_kWh) >= -1e-6), ...
    "PV generation decreased with capacity.");

assert(all(diff(pvGridImports_kWh) <= 1e-6), ...
    "Grid imports increased with PV capacity.");

disp(" ");
disp("=== PV TRADE STUDY VERIFICATION ===");
disp("Baseline PV scenario matches original model.");
disp("PV energy conservation verified.");
disp("Household demand energy conservation verified.");
disp("PV generation and grid import trends verified.");
disp("All PV trade study verification checks passed.");

%% 25. Combined PV and Battery Trade Study

% Define scenario combinations
pvSizes = pv.capacityScenarios_kW;
batterySizes = battery.capacityScenarios_kWh;

numPV = length(pvSizes);
numBattery = length(batterySizes);
numCombinedScenarios = numPV * numBattery;

% Initialize results
combinedPV_kW = zeros(numCombinedScenarios,1);
combinedBattery_kWh = zeros(numCombinedScenarios,1);
combinedImports_kWh = zeros(numCombinedScenarios,1);
combinedExports_kWh = zeros(numCombinedScenarios,1);
combinedImportReduction_pct = zeros(numCombinedScenarios,1);

scenarioIndex = 0;

% Evaluate all PV and battery combinations
for i = 1:numPV

    % Scale PV generation for selected capacity
    scaleFactor = pvSizes(i) / pv.capacity_kW;
    scenarioSolar_kWh = solarAged_kWh * scaleFactor;

    for j = 1:numBattery

        scenarioIndex = scenarioIndex + 1;

        % Configure battery
        testBattery = battery;
        testBattery.capacity_kWh = batterySizes(j);

        % Simulate hourly energy flows
        scenario = sim.calculateBatteryDispatch( ...
            demandHourly_kWh, scenarioSolar_kWh, testBattery);

        % Store configuration
        combinedPV_kW(scenarioIndex) = pvSizes(i);
        combinedBattery_kWh(scenarioIndex) = batterySizes(j);

        % Calculate annual grid exchanges
        combinedImports_kWh(scenarioIndex) = ...
            sum(scenario.gridImport_kWh);

        combinedExports_kWh(scenarioIndex) = ...
            sum(scenario.gridExport_kWh);

        % Compare imports against original 6 kW, no-battery baseline
        combinedImportReduction_pct(scenarioIndex) = ...
            100 * (annualGridImport_kWh - ...
            combinedImports_kWh(scenarioIndex)) ...
            / annualGridImport_kWh;

    end
end

% Create comparison table
combinedComparison = table( ...
    combinedPV_kW, ...
    combinedBattery_kWh, ...
    combinedImports_kWh, ...
    combinedExports_kWh, ...
    combinedImportReduction_pct, ...
    'VariableNames', { ...
    'PVCapacity_kW', ...
    'BatteryCapacity_kWh', ...
    'GridImports_kWh', ...
    'GridExports_kWh', ...
    'ImportReduction_pct'});

disp(" ");
disp("=== COMBINED PV AND BATTERY COMPARISON ===");
disp(combinedComparison);

%% 26. Verify Combined PV and Battery Trade Study

tolerance = 1e-6;

% Verify every zero-battery scenario matches the PV trade study
for i = 1:numPV

    idx = combinedPV_kW == pvSizes(i) & ...
          combinedBattery_kWh == 0;

    assert(sum(idx) == 1, ...
        "Expected exactly one matching PV-only scenario.");

    assert(abs(combinedImports_kWh(idx) - ...
        pvGridImports_kWh(i)) < tolerance, ...
        "Combined PV-only imports do not match.");

    assert(abs(combinedExports_kWh(idx) - ...
        pvGridExports_kWh(i)) < tolerance, ...
        "Combined PV-only exports do not match.");

end

% Verify every 6 kW scenario matches the battery trade study
for j = 1:numBattery

    idx = combinedPV_kW == pv.capacity_kW & ...
          combinedBattery_kWh == batterySizes(j);

    assert(sum(idx) == 1, ...
        "Expected exactly one matching battery scenario.");

    assert(abs(combinedImports_kWh(idx) - ...
        scenarioImports_kWh(j)) < tolerance, ...
        "Combined battery imports do not match.");

    assert(abs(combinedExports_kWh(idx) - ...
        scenarioExports_kWh(j)) < tolerance, ...
        "Combined battery exports do not match.");

end

% Verify that all scenarios have nonnegative grid exchanges
assert(all(combinedImports_kWh >= -tolerance), ...
    "Negative grid imports detected.");

assert(all(combinedExports_kWh >= -tolerance), ...
    "Negative grid exports detected.");

disp(" ");
disp("=== COMBINED TRADE STUDY VERIFICATION ===");
disp("PV-only scenarios match the PV trade study.");
disp("Battery-only scenarios match the battery trade study.");
disp("All grid exchanges are nonnegative.");
disp("All combined trade study verification checks passed.");

%% 27. PV Augmentation Model

% Existing PV system
existingPV_kW = pv.capacity_kW;
existingPVGeneration_kWh = solarAged_kWh;

% Additional NEW PV capacity scenarios
addedPVScenarios_kW = [0, 2, 4];

numAugmentationScenarios = length(addedPVScenarios_kW);

% Initialize results
augmentationGeneration_kWh = zeros(numAugmentationScenarios,1);
augmentationImports_kWh = zeros(numAugmentationScenarios,1);
augmentationExports_kWh = zeros(numAugmentationScenarios,1);

for i = 1:numAugmentationScenarios

    % New panels use the undegraded PVWatts generation profile
    addedPVGeneration_kWh = solarEnergy_kWh * ...
        (addedPVScenarios_kW(i) / existingPV_kW);

    % Combine existing aged panels with new panels
    totalSolar_kWh = existingPVGeneration_kWh + ...
        addedPVGeneration_kWh;

    % Simulate hourly energy flows without battery storage
    scenario = sim.calculateEnergyFlows( ...
        demandHourly_kWh, totalSolar_kWh);

    % Store annual results
    augmentationGeneration_kWh(i) = sum(totalSolar_kWh);
    augmentationImports_kWh(i) = sum(scenario.gridImport_kWh);
    augmentationExports_kWh(i) = sum(scenario.gridExport_kWh);

end

% Create results table
augmentationComparison = table( ...
    addedPVScenarios_kW(:), ...
    existingPV_kW + addedPVScenarios_kW(:), ...
    augmentationGeneration_kWh, ...
    augmentationImports_kWh, ...
    augmentationExports_kWh, ...
    'VariableNames', { ...
    'AddedPV_kW', ...
    'TotalPV_kW', ...
    'Generation_kWh', ...
    'GridImports_kWh', ...
    'GridExports_kWh'});

disp(" ");
disp("=== PV AUGMENTATION COMPARISON ===");
disp(augmentationComparison);

%% 28. Verify PV Augmentation Model

tolerance = 1e-6;

% Verify no-augmentation scenario matches baseline
assert(abs(augmentationGeneration_kWh(1) - ...
    sum(solarAged_kWh)) < tolerance, ...
    "No-augmentation generation does not match baseline.");

assert(abs(augmentationImports_kWh(1) - ...
    annualGridImport_kWh) < tolerance, ...
    "No-augmentation imports do not match baseline.");

assert(abs(augmentationExports_kWh(1) - ...
    annualGridExport_kWh) < tolerance, ...
    "No-augmentation exports do not match baseline.");

% Verify expected generation for each augmentation scenario
expectedGeneration_kWh = sum(solarAged_kWh) + ...
    sum(solarEnergy_kWh) * ...
    (addedPVScenarios_kW(:) / existingPV_kW);

assert(all(abs(augmentationGeneration_kWh - ...
    expectedGeneration_kWh) < tolerance), ...
    "PV augmentation generation calculation failed.");

% Verify energy conservation
selfConsumedAugmentation_kWh = ...
    augmentationGeneration_kWh - augmentationExports_kWh;

demandBalanceError = annualDemand_kWh - ...
    selfConsumedAugmentation_kWh - augmentationImports_kWh;

assert(all(abs(demandBalanceError) < tolerance), ...
    "PV augmentation energy conservation failed.");

disp(" ");
disp("=== PV AUGMENTATION VERIFICATION ===");
disp("No-augmentation scenario matches baseline.");
disp("Existing and new PV generation calculations verified.");
disp("Annual energy conservation verified.");
disp("All PV augmentation verification checks passed.");

%% 29. Combined PV Augmentation and Battery Trade Study

% Define retrofit scenarios
addedPVSizes = addedPVScenarios_kW;
batterySizes = battery.capacityScenarios_kWh;

numAddedPV = length(addedPVSizes);
numBattery = length(batterySizes);
numRetrofitScenarios = numAddedPV * numBattery;

% Initialize result arrays
retrofitAddedPV_kW = zeros(numRetrofitScenarios,1);
retrofitBattery_kWh = zeros(numRetrofitScenarios,1);
retrofitImports_kWh = zeros(numRetrofitScenarios,1);
retrofitExports_kWh = zeros(numRetrofitScenarios,1);
retrofitImportReduction_pct = zeros(numRetrofitScenarios,1);

scenarioIndex = 0;

for i = 1:numAddedPV

    % Existing aged PV plus newly installed PV
    newPV_kWh = solarEnergy_kWh * ...
        (addedPVSizes(i) / existingPV_kW);

    totalSolar_kWh = solarAged_kWh + newPV_kWh;

    for j = 1:numBattery

        scenarioIndex = scenarioIndex + 1;

        % Configure battery capacity
        testBattery = battery;
        testBattery.capacity_kWh = batterySizes(j);

        % Run full-year simulation
        scenario = sim.calculateBatteryDispatch( ...
            demandHourly_kWh, totalSolar_kWh, testBattery);

        % Store configuration
        retrofitAddedPV_kW(scenarioIndex) = addedPVSizes(i);
        retrofitBattery_kWh(scenarioIndex) = batterySizes(j);

        % Store annual grid exchanges
        retrofitImports_kWh(scenarioIndex) = ...
            sum(scenario.gridImport_kWh);

        retrofitExports_kWh(scenarioIndex) = ...
            sum(scenario.gridExport_kWh);

        % Reduction relative to existing 6 kW system
        retrofitImportReduction_pct(scenarioIndex) = ...
            100 * (annualGridImport_kWh - ...
            retrofitImports_kWh(scenarioIndex)) ...
            / annualGridImport_kWh;

    end
end

% Create results table
retrofitComparison = table( ...
    retrofitAddedPV_kW, ...
    retrofitBattery_kWh, ...
    retrofitImports_kWh, ...
    retrofitExports_kWh, ...
    retrofitImportReduction_pct, ...
    'VariableNames', { ...
    'AddedPV_kW', ...
    'BatteryCapacity_kWh', ...
    'GridImports_kWh', ...
    'GridExports_kWh', ...
    'ImportReduction_pct'});

disp(" ");
disp("=== REALISTIC RETROFIT COMPARISON ===");
disp(retrofitComparison);

%% 30. Verify Realistic Retrofit Trade Study

tolerance = 1e-6;

% Verify no-added-PV scenarios match battery-only study
for j = 1:numBattery

    idx = retrofitAddedPV_kW == 0 & ...
          retrofitBattery_kWh == batterySizes(j);

    assert(sum(idx) == 1, ...
        "Expected exactly one battery-only retrofit scenario.");

    assert(abs(retrofitImports_kWh(idx) - ...
        scenarioImports_kWh(j)) < tolerance, ...
        "Battery-only retrofit imports do not match.");

    assert(abs(retrofitExports_kWh(idx) - ...
        scenarioExports_kWh(j)) < tolerance, ...
        "Battery-only retrofit exports do not match.");

end

% Verify zero-battery scenarios match PV augmentation study
for i = 1:numAddedPV

    idx = retrofitAddedPV_kW == addedPVSizes(i) & ...
          retrofitBattery_kWh == 0;

    assert(sum(idx) == 1, ...
        "Expected exactly one PV-only retrofit scenario.");

    assert(abs(retrofitImports_kWh(idx) - ...
        augmentationImports_kWh(i)) < tolerance, ...
        "PV-only retrofit imports do not match.");

    assert(abs(retrofitExports_kWh(idx) - ...
        augmentationExports_kWh(i)) < tolerance, ...
        "PV-only retrofit exports do not match.");

end

% Verify all grid exchanges are nonnegative
assert(all(retrofitImports_kWh >= -tolerance), ...
    "Negative grid imports detected.");

assert(all(retrofitExports_kWh >= -tolerance), ...
    "Negative grid exports detected.");

disp(" ");
disp("=== REALISTIC RETROFIT VERIFICATION ===");
disp("Battery-only scenarios match previous results.");
disp("PV-only scenarios match previous results.");
disp("All grid exchanges are nonnegative.");
disp("All realistic retrofit verification checks passed.");
