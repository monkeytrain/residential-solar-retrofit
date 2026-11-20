%% Independent normalization pilot; run after main.
run('monte_carlo_setup.m');
if ~exist('mcPilotN','var'), mcPilotN=100; end
mcPilotSeed=801;
mcPilotSamples=mc.generateSamples(mcDistributions,mcPilotN,mcPilotSeed);
mcPilotBounds=decisionBounds;
mcPilotTimer=tic;
for j=1:mcPilotN
    P=mc.evaluateRealization(mcContext,mcPilotSamples(j,:));
    X=[P.LifecycleNPV(P.Feasible),P.InitialInvestment(P.Feasible),P.SelfSufficiency_pct(P.Feasible)];
    mcPilotBounds=[min(mcPilotBounds(1,:),min(X,[],1));max(mcPilotBounds(2,:),max(X,[],1))];
    if mod(j,10)==0 || j==mcPilotN, fprintf('Pilot %d/%d; %.1f s\n',j,mcPilotN,toc(mcPilotTimer)); end
end
% Expand empirical NPV extremes by 10% of their span; not guaranteed limits.
pad=max(1,.1*diff(mcPilotBounds(:,1)));
mcPilotBounds(:,1)=mcPilotBounds(:,1)+[-pad;pad];
% Physical SSR and analytical maximum capital expenditure.
A=mcContext.alternatives;
cost=A.AddedPV_kW*1000*mcDistributions.Maximum(5)+A.BatteryCapacity_kWh*mcDistributions.Maximum(6);
side=A.Category=="Efficiency" | A.Category=="Load shifting";
cost(side)=A.InitialInvestment(side);
mcPilotBounds(:,2)=[0;max([1;cost(isfinite(cost))])];
mcPilotBounds(:,3)=[0;100];
mcPilotContext=mcContext;
mcPilotDistributions=mcDistributions;
disp(array2table(mcPilotBounds,'VariableNames',{'NPV','Investment','SSR'},'RowNames',{'Lower','Upper'}));
fprintf('Pilot complete; bounds frozen for independent production samples.\n');
