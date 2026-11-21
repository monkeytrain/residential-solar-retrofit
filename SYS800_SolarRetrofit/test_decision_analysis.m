function test_decision_analysis()
% Run from project root. Synthetic unit tests; no external data needed.
[w,cr,A]=decision.calculateAHPWeights([1 1 1]);
assert(max(abs(w-1/3))<1e-10 && cr<1e-10);
[w,cr]=decision.calculateAHPWeights([2 6 3]);
assert(max(abs(w-[6;3;1]/10))<1e-10 && cr<1e-10);
[~,cr]=decision.calculateAHPWeights([9 1/9 9]); assert(cr>0.1);
for p={[3 5 2],[2 1/3 1/5]}
    [w,cr]=decision.calculateAHPWeights(p{1}); assert(cr<=0.1 && abs(sum(w)-1)<1e-10);
end
[U,b]=decision.normalizeCriteria([-100 0 20;100 50 80]);
assert(isequal(U,[0 1 0;1 0 1]));
assert(isequal(decision.normalizeCriteria([0 0 20;0 0 20]),0.5*ones(2,3)));
assert(isequal(decision.normalizeCriteria([200 0 100],b),[1 1 1]));
T=table(["Base";"Battery";"Unknown";"Over budget"],["No retrofit";"Battery only";"Efficiency";"PV only"], ...
    [0;0;0;2],[0;5;0;0],[0;0;0;0],[0;500;NaN;2000],[0;1000;NaN;10000],[20;60;30;90], ...
    'VariableNames',{'Alternative','Category','AddedPV_kW','BatteryCapacity_kWh','Shift_kWhDay','InitialInvestment','LifecycleNPV','SelfSufficiency_pct'});
c=struct('maxBudget',1000,'maxAddedPV',4,'maxBattery',10,'allowEfficiency',true,'maxShift',3);
[T.Feasible,T.ExclusionReason]=decision.screenFeasibility(T,c);
assert(isequal(T.Feasible,[true;true;false;false]));
R=decision.rankAlternatives(T,[0.5;0.2;0.3]);
assert(R.Alternative(1)=="Battery" && all(isnan(R.Score(~R.Feasible))));
c.maxBudget=0;
[T.Feasible,T.ExclusionReason]=decision.screenFeasibility(T,c);
R=decision.rankAlternatives(T,[1;0;0]); assert(R.Alternative(1)=="Base" && nnz(R.Feasible)==1);
fprintf('Decision-analysis unit tests PASSED.\n');
end
