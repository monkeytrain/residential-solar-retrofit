function [w,CR,A,lambda,CI] = calculateAHPWeights(p)
% Order: economics, affordability, self-sufficiency.
% p = [C1/C2 C1/C3 C2/C3], Saaty scale or reciprocal.
scale = [1:9 1./(2:9)];
assert(isnumeric(p) && isreal(p) && numel(p)==3 && all(isfinite(p(:))), 'Three finite judgments required.');
assert(all(arrayfun(@(x) any(abs(scale-x)<1e-10),p(:))), 'Use Saaty scale or reciprocal.');
A = [1 p(1) p(2); 1/p(1) 1 p(3); 1/p(2) 1/p(3) 1];
[V,D] = eig(A);
[lambda,k] = max(real(diag(D)));
w = abs(real(V(:,k))); w = w/sum(w);
CI = max(0,(lambda-3)/2); CR = CI/0.58;
end
