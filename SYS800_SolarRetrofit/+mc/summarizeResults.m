function S=summarizeResults(T,npv,feasible,winner)
n=height(T); P=zeros(n,3); positive=nan(n,1); avg=positive; sd=positive; q05=positive; q50=positive; q95=positive;
for i=1:n
    x=npv(:,i); x=x(isfinite(x));
    if ~isempty(x)
        avg(i)=mean(x); sd(i)=std(x); positive(i)=mean(x>0);
        q=prctile(x,[5 50 95]); q05(i)=q(1); q50(i)=q(2); q95(i)=q(3);
    end
    P(i,:)=mean(winner==i,1);
end
assert(all(abs(sum(P,1)-1)<1e-10));
S=table(T.Alternative,avg,sd,q05,q50,q95,positive,mean(feasible,1)',P(:,1),P(:,2),P(:,3),...
 'VariableNames',{'Alternative','MeanNPV','StdNPV','P05NPV','MedianNPV','P95NPV','ProbabilityPositiveNPV','ProbabilityFeasible','WinFinancial','WinBalanced','WinIndependence'});
end
