
function [rates, calendar] = buildTOURates(year, plan, rateTable)
% BUILDTOURATES Assign hourly TOU rates from a supplied tariff table.
%
% Required rateTable columns:
%   Plan, Season, DayType, StartHour, EndHour, Rate
%
% StartHour is inclusive; EndHour is exclusive.
% A period crossing midnight must be split into two rows.
%
% DayType: "Weekday", "Weekend", or "All"
% Season:  "Summer", "Winter", or "All"
%
% NOTE: Holiday treatment is not implemented yet.

    arguments
        year (1,1) double {mustBeInteger}
        plan (1,1) string
        rateTable table
    end

    assert(year >= 1900 && year <= 9999, ...
        "Year must be between 1900 and 9999.");

    assert(~(mod(year,4)==0 && ...
        (mod(year,100)~=0 || mod(year,400)==0)), ...
        "Current energy model requires a non-leap year.");

    timestamps = (datetime(year,1,1):hours(1): ...
                  datetime(year,12,31,23,0,0))';

    n = numel(timestamps);
    assert(n == 8760);

    months = month(timestamps);
    hourOfDay = hour(timestamps);
    weekdayNumber = weekday(timestamps);

    isWeekend = weekdayNumber == 1 | weekdayNumber == 7;
    isSummer = months >= 6 & months <= 9;

    season = repmat("Winter",n,1);
    season(isSummer) = "Summer";

    dayType = repmat("Weekday",n,1);
    dayType(isWeekend) = "Weekend";

    rates = NaN(n,1);
    matchedCount = zeros(n,1);

    for k = 1:height(rateTable)

        if string(rateTable.Plan(k)) ~= plan
            continue;
        end

        rowSeason = string(rateTable.Season(k));
        rowDayType = string(rateTable.DayType(k));

        seasonMatch = rowSeason == "All" | season == rowSeason;
        dayMatch = rowDayType == "All" | dayType == rowDayType;

        startHour = rateTable.StartHour(k);
        endHour = rateTable.EndHour(k);

        assert(startHour >= 0 && endHour <= 24 && ...
               startHour < endHour, ...
               "Invalid tariff hour range.");

        hourMatch = hourOfDay >= startHour & hourOfDay < endHour;

        match = seasonMatch & dayMatch & hourMatch;

        rates(match) = rateTable.Rate(k);
        matchedCount(match) = matchedCount(match) + 1;
    end

    assert(all(matchedCount == 1), ...
        "Tariff table must assign exactly one rate per hour.");

    assert(all(isfinite(rates) & rates >= 0), ...
        "Invalid electricity rates detected.");

    calendar = table(timestamps,season,dayType,hourOfDay,rates, ...
        'VariableNames', ...
        {'Timestamp','Season','DayType','Hour','Rate'});
end
