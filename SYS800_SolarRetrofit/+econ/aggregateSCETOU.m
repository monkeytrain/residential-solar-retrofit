
function tou = aggregateSCETOU(imports_kWh, exports_kWh, calendar)
% AGGREGATESCETOU Aggregate hourly grid energy into
% SCE TOU-D-4-9PM billing categories.
%
% Inputs:
%   imports_kWh - Hourly grid imports (kWh)
%   exports_kWh - Hourly grid exports (kWh)
%   calendar    - Calendar from econ.buildTOURates
%
% Output:
%   tou - Table containing seasonal TOU energy totals.
%
% Holiday treatment:
%   SCE holidays follow the weekend TOU schedule.
%
% NOTE:
%   Aggregates net energy only.
%   Does not calculate billing charges.

    imports_kWh = imports_kWh(:);
    exports_kWh = exports_kWh(:);

    n = numel(imports_kWh);

    assert(numel(exports_kWh) == n, ...
        'Import/export array lengths must match.');

    assert(height(calendar) == n, ...
        'Calendar length must match hourly energy arrays.');

    assert(all(isfinite(imports_kWh)) && ...
           all(isfinite(exports_kWh)), ...
        'Energy arrays must contain finite values.');

    assert(all(imports_kWh >= 0) && ...
           all(exports_kWh >= 0), ...
        'Grid imports and exports cannot be negative.');

    % Calendar information
    season = string(calendar.Season);
    hourOfDay = calendar.Hour;

    % Determine weekends and SCE holidays
    isWeekend = ismember(weekday(calendar.Timestamp), [1 7]);

    isHoliday = econ.isSCEHoliday(calendar.Timestamp);

    isWeekendOrHoliday = isWeekend | isHoliday;
    isWeekday = ~isWeekendOrHoliday;

    % Hourly net grid energy
    net_kWh = imports_kWh - exports_kWh;

    % Fixed order matches SCE delivery billing categories
    labels = [ ...
        "Summer On Peak";
        "Summer Mid Peak";
        "Summer Off Peak";
        "Winter Mid Peak";
        "Winter Off Peak";
        "Winter Super Off Peak"];

    periodIndex = zeros(n,1);

    % Seasonal and hourly classifications
    summer = season == "Summer";
    winter = season == "Winter";

    evening = hourOfDay >= 16 & hourOfDay < 21;

    % -------------------------------------------------
    % SUMMER: June through September
    % -------------------------------------------------

    % Weekdays, excluding holidays, 4 PM to 9 PM
    periodIndex(summer & isWeekday & evening) = 1;

    % Weekends and holidays, 4 PM to 9 PM
    periodIndex(summer & isWeekendOrHoliday & evening) = 2;

    % All other summer hours
    periodIndex(summer & ~evening) = 3;

    % -------------------------------------------------
    % WINTER: October through May
    % -------------------------------------------------

    % Every day, 4 PM to 9 PM
    periodIndex(winter & evening) = 4;

    % Every day, 8 AM to 4 PM
    periodIndex(winter & ...
        hourOfDay >= 8 & hourOfDay < 16) = 6;

    % All remaining winter hours
    periodIndex(winter & periodIndex == 0) = 5;

    % -------------------------------------------------
    % VERIFICATION
    % -------------------------------------------------

    assert(all(periodIndex >= 1 & periodIndex <= 6), ...
        'One or more hours were not assigned a TOU period.');

    % Aggregate hourly energy by TOU period
    importTotals = accumarray( ...
        periodIndex, imports_kWh, [6 1]);

    exportTotals = accumarray( ...
        periodIndex, exports_kWh, [6 1]);

    netTotals = accumarray( ...
        periodIndex, net_kWh, [6 1]);

    % Build output table
    tou = table( ...
        labels, ...
        importTotals, ...
        exportTotals, ...
        netTotals, ...
        'VariableNames', ...
        {'Period','Imports_kWh','Exports_kWh','Net_kWh'});

    % Verify conservation of energy
    assert(abs(sum(tou.Net_kWh) - sum(net_kWh)) < 1e-6, ...
        'TOU aggregation failed energy balance verification.');

    assert(abs(sum(tou.Imports_kWh) - sum(imports_kWh)) < 1e-6, ...
        'Import aggregation failed verification.');

    assert(abs(sum(tou.Exports_kWh) - sum(exports_kWh)) < 1e-6, ...
        'Export aggregation failed verification.');

end
