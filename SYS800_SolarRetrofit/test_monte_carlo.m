%% Run after main; tests actual integrated nominal recovery.
run('monte_carlo_setup.m');
mcTestSamples=mc.generateSamples(mcDistributions,1000,800);
assert(isequal(mcTestSamples,mc.generateSamples(mcDistributions,1000,800)));
assert(all(mcTestSamples>=mcDistributions.Minimum' & mcTestSamples<=mcDistributions.Maximum','all'));
tic
% Deterministic model is the full-participation reference, not the stochastic mode.
mcNominalInputs=mcDistributions.Mode'; mcNominalInputs(13)=1;
mcNominal=mc.evaluateRealization(mcContext,mcNominalInputs);
fprintf('Nominal evaluator time: %.2f seconds\n',toc);
mcFields={'InitialInvestment','LifecycleNPV','SelfSufficiency_pct','PVSelfConsumption_pct','GridImports_kWh','GridExports_kWh'};
for mcK=1:numel(mcFields)
    mcA=decisionAlternatives.(mcFields{mcK}); mcB=mcNominal.(mcFields{mcK});
    assert(isequal(isnan(mcA),isnan(mcB)));
    mcError=max(abs(mcA(isfinite(mcA))-mcB(isfinite(mcA))));
    fprintf('%s maximum nominal error: %.10g\n',mcFields{mcK},mcError);
    assert(mcError<1e-6,'Nominal recovery failed: %s',mcFields{mcK});
end
assert(isequal(mcNominal.Feasible,decisionAlternatives.Feasible));
mcNominalRanking=decision.rankAlternatives(mcNominal,decisionWeights);
assert(isequal(mcNominalRanking.Alternative,decisionRanking.Alternative));
fprintf('Monte Carlo nominal recovery and sampling tests PASSED.\n');
