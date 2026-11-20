%% Independent stochastic analysis; run main and test_monte_carlo first.
run('monte_carlo_setup.m');
if ~exist('mcN','var'), mcN=10; end
if ~exist('mcSeed','var'), mcSeed=800; end
mcSamples=mc.generateSamples(mcDistributions,mcN,mcSeed);
mcW=[decision.calculateAHPWeights([3 5 2]),ones(3,1)/3,decision.calculateAHPWeights([2 1/3 1/5])];
mcNames=["Financial","Balanced","Grid independence"];
% Fixed nominal feasible-set bounds; clipping is explicitly tracked.
mcBounds=decisionBounds;
mcCount=height(decisionAlternatives);
mcNPV=nan(mcN,mcCount); mcCost=mcNPV; mcSSR=mcNPV;
mcFeasible=false(mcN,mcCount); mcWinner=zeros(mcN,3);
mcRanks=nan(mcN,mcCount,3); mcClipped=zeros(mcN,3);
mcTimer=tic;
for mcI=1:mcN
    mcT=mc.evaluateRealization(mcContext,mcSamples(mcI,:));
    mcNPV(mcI,:)=mcT.LifecycleNPV';
    mcCost(mcI,:)=mcT.InitialInvestment';
    mcSSR(mcI,:)=mcT.SelfSufficiency_pct';
    mcFeasible(mcI,:)=mcT.Feasible';
    mcX=[mcT.LifecycleNPV(mcT.Feasible),mcT.InitialInvestment(mcT.Feasible),mcT.SelfSufficiency_pct(mcT.Feasible)];
    mcClipped(mcI,:)=sum(mcX<mcBounds(1,:)|mcX>mcBounds(2,:),1);
    for mcP=1:3
        mcR=decision.rankAlternatives(mcT,mcW(:,mcP),mcBounds);
        [~,mcIdx]=ismember(mcR.Alternative,mcT.Alternative);
        mcWinner(mcI,mcP)=mcIdx(1);
        mcRanks(mcI,mcIdx,mcP)=mcR.Rank';
    end
    if mod(mcI,max(1,floor(mcN/10)))==0 || mcI==mcN
        fprintf('Monte Carlo %d/%d; elapsed %.1f s\n',mcI,mcN,toc(mcTimer));
    end
end
mcSummary=mc.summarizeResults(mcContext.alternatives,mcNPV,mcFeasible,mcWinner);
mcSensitivity=mc.calculateSensitivity(mcSamples,mcNPV);
mcConvergence=mc.checkConvergence(mcWinner,mcCount);
fprintf('Mean seconds per realization: %.2f\n',toc(mcTimer)/mcN);
fprintf('Clipped feasible criterion observations (NPV, cost, SSR):\n');
disp(sum(mcClipped,1));
disp(mcSummary);
mc.plotResults(mcDistributions,mcSamples,mcContext.alternatives,mcNPV,mcSummary,mcSensitivity);
