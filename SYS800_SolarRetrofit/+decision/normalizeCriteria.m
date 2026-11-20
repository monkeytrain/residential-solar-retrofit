function [U,bounds] = normalizeCriteria(X,bounds)
% Columns: NPV (benefit), investment (cost), SSR (benefit).
% Optional fixed bounds: row 1 minima, row 2 maxima.
assert(isnumeric(X) && isreal(X) && size(X,2)==3 && ~isempty(X) && all(isfinite(X(:))));
if nargin<2 || isempty(bounds)
    bounds = [min(X,[],1);max(X,[],1)];
end
assert(isequal(size(bounds),[2 3]) && all(isfinite(bounds(:))) && all(bounds(2,:)>=bounds(1,:)));
U = zeros(size(X));
for k=1:3
    span = bounds(2,k)-bounds(1,k);
    if span==0
        U(:,k)=0.5;
    else
        U(:,k)=min(1,max(0,(X(:,k)-bounds(1,k))/span));
        if k==2, U(:,k)=1-U(:,k); end
    end
end
end
