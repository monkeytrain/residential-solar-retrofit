function R=calculateSensitivity(X,Y)
% Spearman correlation using average ranks for ties; no toolbox required.
R=nan(size(X,2),size(Y,2));
for j=1:size(Y,2)
    ok=isfinite(Y(:,j)); y=Y(ok,j);
    if numel(y)<3 || max(y)==min(y), continue; end
    for k=1:size(X,2)
        x=X(ok,k);
        if max(x)==min(x), continue; end
        c=corrcoef(ranks(x),ranks(y)); R(k,j)=c(1,2);
    end
end
end
function r=ranks(x)
[s,i]=sort(x); r=zeros(size(x)); a=1;
while a<=numel(x)
    b=a; while b<numel(x)&&s(b+1)==s(a), b=b+1; end
    r(i(a:b))=(a+b)/2; a=b+1;
end
end
