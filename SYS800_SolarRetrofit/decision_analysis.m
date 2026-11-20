%% AHP-weighted decision analysis
% Run after technical_model and lifecycle_analysis. Re-run independently
% to change preferences or constraints without repeating simulation.
fprintf('\n=== AHP DECISION ANALYSIS ===\n');
decisionConfig = decision.collectInputs(efficiencyReductionCases,dailyShiftCases_kWh);
[decisionWeights,decisionCR,decisionPairwise,decisionLambda,decisionCI] = ...
    decision.calculateAHPWeights(decisionConfig.judgments);
assert(decisionCR<=0.1,'Inconsistent preferences.');
assert(isequal(referenceComparison.AddedPV_kW,technicalPerformance.AddedPV_kW) && ...
    isequal(referenceComparison.BatteryCapacity_kWh,technicalPerformance.BatteryCapacity_kWh));
decisionPV = referenceComparison.AddedPV_kW;
decisionBattery = referenceComparison.BatteryCapacity_kWh;
decisionNE = numel(efficiencyReductionCases);
decisionNS = numel(dailyShiftCases_kWh);
decisionN = numel(decisionPV);
decisionCategory = repmat("PV + battery",decisionN,1);
decisionCategory(decisionPV==0)="Battery only";
decisionCategory(decisionBattery==0)="PV only";
decisionCategory(decisionPV==0 & decisionBattery==0)="No retrofit";
decisionLabel = compose("+%g kW PV / %g kWh battery",decisionPV,decisionBattery);
decisionLabel(decisionCategory=="No retrofit")="No retrofit";
decisionDemand = sum(demandHourly_kWh);
decisionEffDemand = decisionDemand*(1-efficiencyReductionCases(:));
decisionImports = [annualImports(:,1);efficiencyAnnualImports(:,1);loadShiftAnnualImports(:,1)];
decisionExports = [annualExports(:,1);efficiencyAnnualExports(:,1);loadShiftAnnualExports(:,1)];
decisionGeneration = [annualPVGeneration(:,1);repmat(sum(solarAged_kWh)*pvRetention(1),decisionNE+decisionNS,1)];
decisionSSR = 100*(1-decisionImports./[repmat(decisionDemand,decisionN,1);decisionEffDemand;repmat(decisionDemand,decisionNS,1)]);
decisionSCR = 100*(1-decisionExports./decisionGeneration);
decisionCosts = [referenceComparison.InitialInvestment;decisionConfig.efficiencyCosts(:);decisionConfig.shiftCosts(:)];
decisionNPV = [referenceComparison.NPV_Degraded;efficiencyPresentValue(:)-decisionConfig.efficiencyCosts(:);loadShiftPresentValue(:)-decisionConfig.shiftCosts(:)];
decisionAlternatives = table([decisionLabel;compose("%g%% efficiency",100*efficiencyReductionCases(:));compose("%g kWh/day shift",dailyShiftCases_kWh(:))], ...
    [decisionCategory;repmat("Efficiency",decisionNE,1);repmat("Load shifting",decisionNS,1)], ...
    [decisionPV;zeros(decisionNE+decisionNS,1)], [decisionBattery;zeros(decisionNE+decisionNS,1)], ...
    [zeros(decisionN,1);100*efficiencyReductionCases(:);zeros(decisionNS,1)], ...
    [zeros(decisionN+decisionNE,1);dailyShiftCases_kWh(:)],decisionCosts,decisionNPV,decisionSSR,decisionSCR,decisionImports,decisionExports, ...
    'VariableNames',{'Alternative','Category','AddedPV_kW','BatteryCapacity_kWh','Efficiency_pct','Shift_kWhDay','InitialInvestment','LifecycleNPV','SelfSufficiency_pct','PVSelfConsumption_pct','GridImports_kWh','GridExports_kWh'});
assert(all(isfinite(decisionSSR)) && all(decisionSSR>=-1e-8 & decisionSSR<=100+1e-8));
[decisionAlternatives.Feasible,decisionAlternatives.ExclusionReason] = decision.screenFeasibility(decisionAlternatives,decisionConfig);
[decisionRanking,decisionBounds] = decision.rankAlternatives(decisionAlternatives,decisionWeights);
decisionBest = decisionRanking(1,:);
disp(table(["Economics";"Affordability";"Grid independence"],decisionWeights,'VariableNames',{'Criterion','Weight'}));
fprintf('Consistency ratio: %.4f\n',decisionCR);
disp(decisionRanking(:,{'Alternative','InitialInvestment','LifecycleNPV','SelfSufficiency_pct','Feasible','Score','Rank','ExclusionReason'}));
fprintf('Preferred alternative: %s (score %.4f)\n',decisionBest.Alternative,decisionBest.Score);
