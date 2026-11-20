function [T,costs]=evaluateRealization(C,x)
% Reuse deterministic hourly dispatch and applicable annual billing functions.
% x order is defined by mc.defineDistributions.
T=C.alternatives; n=height(T); H=numel(C.years);
d=C.demand(:)*x(1); pvPerKW=C.pvPerKW(:)*x(2);
existing=pvPerKW*C.pvCapacity*(1-x(3))^C.pvAge;
base=find(T.Category=="No retrofit"); assert(isscalar(base));
costs=zeros(n,H); imports=zeros(n,H); exports=imports;
demandTotal=zeros(n,1); generation=zeros(n,1);
T.InitialInvestment=T.AddedPV_kW*1000*x(5)+T.BatteryCapacity_kWh*x(6);
side=T.Category=="Efficiency" | T.Category=="Load shifting";
T.InitialInvestment(side)=C.alternatives.InitialInvestment(side);
effIdx=find(T.Category=="Efficiency");
for j=1:numel(effIdx)
    if C.config.efficiencyEstimated(j), T.InitialInvestment(effIdx(j))=x(9+j); end
end
for i=1:n
    load=d*(1-T.Efficiency_pct(i)/100);
    if T.Shift_kWhDay(i)>0
        z=reshape(load,24,365);
        avail=sum(z(18:21,:),1); moved=min(avail,T.Shift_kWhDay(i)*x(13));
        f=zeros(1,365); ix=avail>0; f(ix)=moved(ix)./avail(ix);
        z(18:21,:)=z(18:21,:).*(1-f);
        z(11:14,:)=z(11:14,:)+moved/4;
        load=z(:);
        assert(abs(sum(load)-sum(d))<1e-6);
    end
    demandTotal(i)=sum(load);
    for t=1:H
        gen=(existing+pvPerKW*T.AddedPV_kW(i))*(1-x(3))^(t-1);
        cap=T.BatteryCapacity_kWh(i)*(1-x(4))^(t-1);
        if cap==0
            F=sim.calculateEnergyFlows(load,gen);
        else
            B=struct('capacity_kWh',cap,'maxChargePower_kW',5,'maxDischargePower_kW',5,'roundTripEfficiency',.9,'initialSOC_kWh',0);
            F=sim.calculateBatteryDispatch(load,gen,B);
            assert(all(F.stateOfCharge_kWh>=-1e-8 & F.stateOfCharge_kWh<=cap+1e-8));
        end
        I=F.gridImport_kWh; E=F.gridExport_kWh;
        assert(all(isfinite(I)&I>=0) && all(isfinite(E)&E>=0));
        imports(i,t)=sum(I); exports(i,t)=sum(E);
        if t==1, generation(i)=sum(gen); end
        if C.years(t)<C.expiration && T.AddedPV_kW(i)<=max(1,.1*C.pvCapacity)
            bill=econ.calculateNEMBill(I,E,C.nemRates*x(7),C.nemCalendar,1,nbcRate_perkWh=C.nemNBC,nscRate_perkWh=C.nsc,fixedAnnualCharge=C.fixed);
        else
            bill=econ.calculateNBTBill(I,E,C.nbtRates*x(7),C.exportRates*x(8),C.nbtCalendar,nbcRate_perkWh=C.nbtNBC,fixedAnnualCharge=C.fixed);
        end
        costs(i,t)=bill.annualCost;
    end
end
T.LifecycleNPV=-T.InitialInvestment+sum((costs(base,:)-costs-T.AddedPV_kW*C.om)./(1+x(9)).^(1:H),2);
T.GridImports_kWh=imports(:,1); T.GridExports_kWh=exports(:,1);
T.SelfSufficiency_pct=100*(1-imports(:,1)./demandTotal);
T.PVSelfConsumption_pct=100*(1-exports(:,1)./generation);
assert(abs(T.LifecycleNPV(base))<1e-8);
assert(all(T.SelfSufficiency_pct>=-1e-8 & T.SelfSufficiency_pct<=100+1e-8));
[T.Feasible,T.ExclusionReason]=decision.screenFeasibility(T,C.config);
end
