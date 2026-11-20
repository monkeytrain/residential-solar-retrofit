
function tariff = loadSCETariffs()
% LOADSCETARIFFS Published SCE residential TOU reference rates.
%
% Source: Southern California Edison, Time-of-Use Rate Plans
% https://www.sce.com/save-money/rates-financing/residential-rate-plans/time-of-use-plans
% Accessed: 2026-10-24
%
% Rates are rounded published $/kWh values before baseline
% credits, for SCE bundled delivery and generation service.
%
% These are reference inputs, not a complete billing tariff.
% Holiday rules, exact tariff-sheet rates, NEM settlements,
% non-bypassable charges, and NBT export credits are separate.

    plan = strings(0,1);
    season = strings(0,1);
    dayType = strings(0,1);
    startHour = zeros(0,1);
    endHour = zeros(0,1);
    rate = zeros(0,1);

    % Append tariff rows: [startHour, endHour, rate].
    add("TOU-D-4-9PM","Summer","Weekday", ...
        [0 16 .33; 16 21 .59; 21 24 .33]);
    add("TOU-D-4-9PM","Summer","Weekend", ...
        [0 16 .33; 16 21 .44; 21 24 .33]);
    add("TOU-D-4-9PM","Winter","All", ...
        [0 8 .36; 8 16 .32; 16 21 .50; 21 24 .36]);

    add("TOU-D-PRIME","Summer","Weekday", ...
        [0 16 .26; 16 21 .61; 21 24 .26]);
    add("TOU-D-PRIME","Summer","Weekend", ...
        [0 16 .26; 16 21 .39; 21 24 .26]);
    add("TOU-D-PRIME","Winter","All", ...
        [0 8 .30; 8 16 .24; 16 21 .45; 21 24 .30]);

    tariff.rateTable = table(plan,season,dayType, ...
        startHour,endHour,rate, ...
        'VariableNames',{'Plan','Season','DayType', ...
        'StartHour','EndHour','Rate'});

    tariff.source = ...
        "SCE Time-of-Use Rate Plans";
    tariff.accessDate = "2026-10-24";
    tariff.rateStatus = ...
        "Published rounded reference rates";

    tariff.baseServicesCharge_perDay = 0.79;
    tariff.baselineCredit_perkWh = 0.09;
    tariff.baselineCreditPlan = "TOU-D-4-9PM";

    tariff.NBTExportRatesVerified = false;
    tariff.completeNEMBillingImplemented = false;

    function add(p,s,d,rows)
        n = size(rows,1);
        plan = [plan; repmat(string(p),n,1)];
        season = [season; repmat(string(s),n,1)];
        dayType = [dayType; repmat(string(d),n,1)];
        startHour = [startHour; rows(:,1)];
        endHour = [endHour; rows(:,2)];
        rate = [rate; rows(:,3)];
    end
end
