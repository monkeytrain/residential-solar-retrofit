
function results = calculateBatteryDispatch(demand_kWh, solar_kWh, battery)
% CALCULATEBATTERYDISPATCH
% Simulates hourly residential battery charging and discharging.
%
% The battery charges using excess solar generation and
% discharges when household demand exceeds solar generation.
%
% Inputs:
%   demand_kWh - Hourly household electricity demand
%   solar_kWh  - Hourly solar electricity generation
%   battery    - Structure containing battery parameters
%
% Output:
%   results    - Structure containing hourly energy flows

    % Ensure input vectors are columns
    demand_kWh = demand_kWh(:);
    solar_kWh = solar_kWh(:);

    % Verify input dimensions
    n = numel(demand_kWh);

    assert(numel(solar_kWh) == n, ...
        "Demand and solar vectors must have equal lengths.");

    % Battery parameters
    capacity = battery.capacity_kWh;
    maxCharge = battery.maxChargePower_kW;
    maxDischarge = battery.maxDischargePower_kW;

    % Split round-trip efficiency equally between
    % charging and discharging
    efficiency = sqrt(battery.roundTripEfficiency);

    % Initialize hourly results
    results.gridImport_kWh = zeros(n,1);
    results.gridExport_kWh = zeros(n,1);
    results.batteryCharge_kWh = zeros(n,1);
    results.batteryDischarge_kWh = zeros(n,1);
    results.stateOfCharge_kWh = zeros(n,1);

    % Initialize battery state of charge
    soc = battery.initialSOC_kWh;

    % Simulate each hour
    for t = 1:n

        % Electricity remaining after direct solar consumption
        netEnergy = solar_kWh(t) - demand_kWh(t);

        if netEnergy > 0

            % Excess solar is available to charge battery
            availableStorage = (capacity - soc) / efficiency;

            charge = min([netEnergy, maxCharge, availableStorage]);

            % Update stored energy
            soc = soc + charge * efficiency;

            % Remaining excess solar is exported
            results.gridExport_kWh(t) = netEnergy - charge;
            results.batteryCharge_kWh(t) = charge;

        elseif netEnergy < 0

            % Household demand exceeds solar generation
            deficit = -netEnergy;

            % Available energy from battery
            availableDischarge = soc * efficiency;

            discharge = min([deficit, maxDischarge, availableDischarge]);

            % Update stored energy
            soc = soc - discharge / efficiency;

            % Remaining demand is supplied by grid
            results.gridImport_kWh(t) = deficit - discharge;
            results.batteryDischarge_kWh(t) = discharge;

        end

        % Record battery state of charge
        results.stateOfCharge_kWh(t) = soc;

    end

end
