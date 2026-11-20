
function results = calculateEnergyFlows(demand_kWh, solar_kWh)
% CALCULATEENERGYFLOWS
% Calculates hourly electricity flows for a residential
% solar PV system without battery storage.
%
% Inputs:
%   demand_kWh - Hourly household electricity demand
%   solar_kWh  - Hourly solar PV generation
%
% Output:
%   results - Structure containing hourly energy flows

    % Ensure inputs are column vectors
    demand_kWh = demand_kWh(:);
    solar_kWh = solar_kWh(:);

    % Verify input dimensions
    assert(numel(demand_kWh) == numel(solar_kWh), ...
        'Demand and solar vectors must have equal lengths.');

    % Calculate hourly energy flows
    results.selfConsumed_kWh = min(demand_kWh, solar_kWh);

    results.gridImport_kWh = max(demand_kWh - solar_kWh, 0);

    results.gridExport_kWh = max(solar_kWh - demand_kWh, 0);

    % Calculate performance metrics
    results.selfConsumptionRatio = ...
        sum(results.selfConsumed_kWh) / sum(solar_kWh);

    results.selfSufficiencyRatio = ...
        sum(results.selfConsumed_kWh) / sum(demand_kWh);

end
