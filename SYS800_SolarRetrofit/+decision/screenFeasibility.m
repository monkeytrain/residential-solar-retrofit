function [eligible,reasons] = screenFeasibility(T,c)
% User-confirmed limits reflect contract, roof, equipment and interconnection.
n = height(T); reasons = strings(n,1);
for i=1:n
    r = strings(0,1);
    if ~isfinite(T.InitialInvestment(i)) || ~isfinite(T.LifecycleNPV(i))
        r(end+1)="Implementation cost unknown";
    elseif T.InitialInvestment(i)>c.maxBudget
        r(end+1)="Over budget";
    end
    if T.AddedPV_kW(i)>c.maxAddedPV, r(end+1)="PV limit/permission"; end
    if T.BatteryCapacity_kWh(i)>c.maxBattery, r(end+1)="Battery limit/permission"; end
    if T.Category(i)=="Efficiency" && ~c.allowEfficiency, r(end+1)="Efficiency not confirmed"; end
    if T.Category(i)=="Load shifting" && T.Shift_kWhDay(i)>c.maxShift, r(end+1)="Load flexibility limit"; end
    if ~isempty(r), reasons(i)=strjoin(r,"; "); end
end
eligible = reasons=="";
end
