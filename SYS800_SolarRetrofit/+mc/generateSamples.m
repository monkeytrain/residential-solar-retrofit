function X=generateSamples(D,N,seed)
assert(isscalar(N)&&N>=1&&N==floor(N));
stream=RandStream('mt19937ar','Seed',seed);
u=rand(stream,N,height(D));
a=D.Minimum'; b=D.Mode'; c=D.Maximum';
assert(all(a<=b & b<=c));
X=a+sqrt(u.*(c-a).*(b-a));
upper=u>(b-a)./max(c-a,eps);
Y=c-sqrt((1-u).*(c-a).*(c-b));
X(upper)=Y(upper);
end
