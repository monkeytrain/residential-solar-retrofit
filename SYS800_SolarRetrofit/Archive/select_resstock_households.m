
%% SYS 800 - Final ResStock Household Selection
% Select three representative residential electricity demand profiles
% using consistent geographic and household characteristics.
%
% Selection criterion:
% Building with annual electricity consumption closest to the
% median consumption of its household-size category.

clear; clc;

%% 1. Open metadata

filePath = "data/metadata.parquet";

ds = parquetDatastore(filePath);

allNames = string(ds.VariableNames);

%% 2. Identify water-heating fuel column

waterCandidates = allNames( ...
    contains(lower(allNames),"water") & ...
    (contains(lower(allNames),"fuel") | ...
     contains(lower(allNames),"heater")));

fprintf('\n=== WATER HEATING COLUMN CANDIDATES ===\n');
disp(waterCandidates');

% ResStock 2021.1 commonly uses this column.
waterColumn = "in_water_heater_fuel";

if ~ismember(waterColumn,allNames)
    error(['Water-heating column not found. ' ...
        'Review the candidate names printed above.']);
end

%% 3. Load required variables only

requiredNames = [ ...
    "bldg_id", ...
    "in_county", ...
    "in_weather_file_city", ...
    "in_geometry_building_type_recs", ...
    "in_geometry_floor_area", ...
    "in_occupants", ...
    "in_heating_fuel", ...
    "in_hvac_cooling_type", ...
    waterColumn, ...
    "out_electricity_total_energy_consumption"];

missingNames = setdiff(requiredNames,allNames);

if ~isempty(missingNames)
    disp(missingNames');
    error('Required metadata columns are missing.');
end

ds.SelectedVariableNames = cellstr(requiredNames);

metadata = readall(ds);

fprintf('\nLoaded %d buildings using %d columns.\n', ...
    height(metadata),width(metadata));

%% 4. Inspect original reference household

referenceIdx = string(metadata.bldg_id) == "198638";

assert(nnz(referenceIdx) == 1, ...
    'Reference building 198638 not found.');

reference = metadata(referenceIdx,:);

fprintf('\n=== ORIGINAL REFERENCE HOUSEHOLD ===\n');

disp(reference);

%% 5. Apply consistent household filters

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
    string(metadata.(waterColumn)) == ...
        string(reference.(waterColumn));

filtered = metadata(mask,:);

fprintf('\nBuildings matching all characteristics: %d\n', ...
    height(filtered));

%% 6. Define household-size categories

groupNames = ["Small";"Medium";"Large"];

groupBins = { ...
    ["1000-1499"], ...
    ["1500-1999","2000-2499"], ...
    ["2500-2999","3000-3999"]};

%% 7. Select representative households

selectedID = strings(3,1);
selectedArea = strings(3,1);

matchingBuildings = zeros(3,1);
medianDemand = zeros(3,1);
selectedDemand = zeros(3,1);
differenceFromMedian = zeros(3,1);

for g = 1:3

    floorArea = string(filtered.in_geometry_floor_area);

    groupMask = ismember(floorArea,groupBins{g});

    candidates = filtered(groupMask,:);

    demand = double( ...
        candidates.out_electricity_total_energy_consumption);

    valid = isfinite(demand) & demand > 0;

    candidates = candidates(valid,:);
    demand = demand(valid);

    matchingBuildings(g) = height(candidates);

    if isempty(candidates)
        warning('No valid households found for %s.', ...
            groupNames(g));
        continue;
    end

    medianDemand(g) = median(demand);

    [~,idx] = min(abs(demand - medianDemand(g)));

    selected = candidates(idx,:);

    selectedID(g) = string(selected.bldg_id);
    selectedArea(g) = ...
        string(selected.in_geometry_floor_area);

    selectedDemand(g) = demand(idx);

    differenceFromMedian(g) = ...
        selectedDemand(g) - medianDemand(g);

end

%% 8. Display summary table

results = table( ...
    groupNames, ...
    matchingBuildings, ...
    selectedID, ...
    selectedArea, ...
    medianDemand, ...
    selectedDemand, ...
    differenceFromMedian, ...
    'VariableNames',{ ...
    'HouseholdSize', ...
    'MatchingBuildings', ...
    'BuildingID', ...
    'FloorArea_sqft', ...
    'MedianAnnual_kWh', ...
    'SelectedAnnual_kWh', ...
    'DifferenceFromMedian_kWh'});

fprintf('\n=== FINAL HOUSEHOLD SELECTION ===\n');

disp(results);

%% 9. Compare with original medium household

fprintf('\n=== ORIGINAL MEDIUM HOUSEHOLD ===\n');

fprintf('Building ID: 198638\n');

fprintf('Annual electricity: %.1f kWh\n', ...
    double(reference.out_electricity_total_energy_consumption));

fprintf('\n=== SELECTION COMPLETE ===\n');
