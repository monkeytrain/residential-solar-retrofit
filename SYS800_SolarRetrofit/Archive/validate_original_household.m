
%% SYS 800 - Validate Original ResStock Household Selection
% Determine whether building 198638 is the median representative
% for the 1500-1999 sq ft household category.

clear; clc;

%% 1. Load required metadata

ds = parquetDatastore("data/metadata.parquet");

requiredNames = { ...
    'bldg_id', ...
    'in_county', ...
    'in_weather_file_city', ...
    'in_geometry_building_type_recs', ...
    'in_geometry_floor_area', ...
    'in_occupants', ...
    'in_heating_fuel', ...
    'in_hvac_cooling_type', ...
    'in_water_heater_fuel', ...
    'out_electricity_total_energy_consumption'};

ds.SelectedVariableNames = requiredNames;

metadata = readall(ds);

%% 2. Locate original reference building

referenceMask = metadata.bldg_id == 198638;

assert(nnz(referenceMask) == 1, ...
    'Building 198638 not found.');

reference = metadata(referenceMask,:);

%% 3. Apply original household characteristics

mask = ...
    string(metadata.in_county) == ...
        string(reference.in_county) & ...
    string(metadata.in_weather_file_city) == ...
        string(reference.in_weather_file_city) & ...
    string(metadata.in_geometry_building_type_recs) == ...
        string(reference.in_geometry_building_type_recs) & ...
    string(metadata.in_occupants) == ...
        string(reference.in_occupants) & ...
    string(metadata.in_heating_fuel) == ...
        string(reference.in_heating_fuel) & ...
    string(metadata.in_hvac_cooling_type) == ...
        string(reference.in_hvac_cooling_type) & ...
    string(metadata.in_water_heater_fuel) == ...
        string(reference.in_water_heater_fuel);

%% 4. Restrict to original floor-area category

mask = mask & ...
    string(metadata.in_geometry_floor_area) == "1500-1999";

candidates = metadata(mask,:);

demand = double( ...
    candidates.out_electricity_total_energy_consumption);

valid = isfinite(demand) & demand > 0;

candidates = candidates(valid,:);
demand = demand(valid);

%% 5. Find the median representative building

medianDemand = median(demand);

[~,idx] = min(abs(demand - medianDemand));

selected = candidates(idx,:);

%% 6. Compare against building 198638

originalDemand = double( ...
    reference.out_electricity_total_energy_consumption);

fprintf('\n=== ORIGINAL SELECTION VALIDATION ===\n');

fprintf('Qualifying households: %d\n', ...
    height(candidates));

fprintf('Median annual demand: %.2f kWh\n', ...
    medianDemand);

fprintf('Closest building ID: %s\n', ...
    string(selected.bldg_id));

fprintf('Closest building demand: %.2f kWh\n', ...
    demand(idx));

fprintf('\nOriginal building ID: 198638\n');

fprintf('Original building demand: %.2f kWh\n', ...
    originalDemand);

fprintf('Original distance from median: %.2f kWh\n', ...
    abs(originalDemand - medianDemand));

fprintf('Selected distance from median: %.2f kWh\n', ...
    abs(demand(idx) - medianDemand));

%% 7. Check whether original building is selected

if selected.bldg_id == 198638

    fprintf('\nRESULT: Original selection reproduced.\n');

else

    fprintf('\nRESULT: Original selection NOT reproduced.\n');
    fprintf('The original selection likely used additional or ');
    fprintf('different filtering criteria.\n');

end

fprintf('\n=== VALIDATION COMPLETE ===\n');
