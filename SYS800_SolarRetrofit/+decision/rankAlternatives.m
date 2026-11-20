function [R,bounds] = rankAlternatives(T,w,bounds)
% T includes feasibility and all three raw metrics. Excluded rows retained.
if nargin<3, bounds=[]; end
assert(numel(w)==3 && all(isfinite(w(:))) && all(w(:)>=0) && abs(sum(w)-1)<1e-9);
idx=find(T.Feasible);
assert(~isempty(idx),'No feasible alternatives.');
X=[T.LifecycleNPV(idx),T.InitialInvestment(idx),T.SelfSufficiency_pct(idx)];
[U,bounds]=decision.normalizeCriteria(X,bounds);
T.NPVUtility=nan(height(T),1); T.CostUtility=T.NPVUtility; T.SSRUtility=T.NPVUtility;
T.NPVUtility(idx)=U(:,1); T.CostUtility(idx)=U(:,2); T.SSRUtility(idx)=U(:,3);
T.Score=nan(height(T),1); T.Score(idx)=U*w(:);
[~,order]=sortrows([-T.Score(idx),T.InitialInvestment(idx),-T.LifecycleNPV(idx),idx]);
ranked=idx(order); T.Rank=nan(height(T),1);
T.Rank(ranked)=(1:numel(ranked))';
R=T([ranked;find(~T.Feasible)],:);
end
