
function [exportRates,components] = loadNBTExportRates(filePath,year)
% LOADNBTEXPORTRATES Load SCE NBT26 hourly export rates.
%
% Assumes a bundled SCE customer receiving both generation
% and delivery export compensation.
%
% Uses the 8760-hour local STANDARD time convention.
% Does not implement daylight-saving clock changes.

    arguments
        filePath (1,1) string
        year (1,1) double = 2026
    end

    data = readtable(filePath);

    required = ["LocalStandardTime", ...
        "XXSC_Rate_per_kWh","SCXX_Rate_per_kWh"];

    assert(all(ismember(required, ...
        string(data.Properties.VariableNames))), ...
        "NBT CSV is missing required columns.");

    assert(height(data)==8760, ...
        "Expected 8760 hourly records.");

    timestamps = datetime( ...
        string(data.LocalStandardTime), ...
        'InputFormat','yyyy-MM-dd HH:mm:ss');

    expected = (datetime(year,1,1):hours(1): ...
        datetime(year,12,31,23,0,0))';

    assert(isequal(timestamps,expected), ...
        "NBT timestamps do not match the simulation year.");

    generation = data.XXSC_Rate_per_kWh;
    delivery = data.SCXX_Rate_per_kWh;

    assert(all(isfinite(generation) & generation>=0));
    assert(all(isfinite(delivery) & delivery>=0));

    exportRates = generation + delivery;

    components = table( ...
        timestamps,generation,delivery,exportRates, ...
        'VariableNames', ...
        {'Timestamp','GenerationRate', ...
         'DeliveryRate','TotalExportRate'});
end
