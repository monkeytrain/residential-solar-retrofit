function C=checkConvergence(winner,n)
N=size(winner,1); counts=unique(max(1,round(N*[.1 .25 .5 .75 1])));
C=table(counts(:),'VariableNames',{'Iterations'});
for p=1:size(winner,2)
    full=accumarray(winner(:,p),1,[n 1])/N;
    delta=zeros(numel(counts),1);
    for k=1:numel(counts)
        m=counts(k); est=accumarray(winner(1:m,p),1,[n 1])/m;
        delta(k)=max(abs(est-full));
    end
    C.("MaxWinProbabilityChange_"+p)=delta;
end
disp(C);
end
