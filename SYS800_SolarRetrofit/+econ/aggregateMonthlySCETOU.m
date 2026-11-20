
function monthlyTOU = aggregateMonthlySCETOU( ...
    imports_kWh, exports_kWh, calendar)
% AGGREGATEMONTHLYSCETOU
% Aggregate hourly grid energy into monthly SCE TOU categories.
%
% Each output row represents one calendar month and TOU period.
%
% NOTE:
% Calendar months are used as a preliminary approximation
% of utility billing periods.

    imports_kWh = imports_kWh(:);
    exports_kWh = exports_kWh(:);

    assert(numel(imports_kWh) == height(calendar));
    assert(numel(exports_kWh) == height(calendar));

    months = month(calendar.Timestamp);

    monthlyTOU = table();

    for m = 1:12

        idx = months == m;

        monthlyCalendar = calendar(idx,:);

        tou = econ.aggregateSCETOU( ...
            imports_kWh(idx), ...
            exports_kWh(idx), ...
            monthlyCalendar);

        tou.Month = repmat(m,height(tou),1);

        monthlyTOU = [monthlyTOU; tou]; %#ok<AGROW>
    end

    monthlyTOU = movevars(monthlyTOU, ...
        'Month','Before','Period');

    % Verify annual energy conservation
    assert(abs(sum(monthlyTOU.Imports_kWh) - ...
        sum(imports_kWh)) < 1e-6);

    assert(abs(sum(monthlyTOU.Exports_kWh) - ...
        sum(exports_kWh)) < 1e-6);
end
