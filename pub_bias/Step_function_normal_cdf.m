function cdf=Step_function_normal_cdf(X,theta,sigma,betap,cutoffs,symmetric)
%arguments:
%X: point at which to evaluate cdf
%theta: parameter value under which to evaluate cdf
%sigma: standard deviation of (untruncated) normal variable
%sigma: stdev of distribution pi of mu
%betap: coefficient vector for step function p, in increasing order
%cutoffs:vector of thresholds for step function p, in increasing order.
%Cutoffs are given in terms of X, not z statistics
%symmetric: dummy indicating whether publication probability is symmetric
%around zero.  In symmetric case, cutoffs should include only positive
%values
%NOTE: publication probability for largest category (i.e. for those points beyond largest cutoff) normalized to one.

if length(betap)~=(length(cutoffs)+1)
    error('length of betap must be one greater then length of cutoffs');
end

%For symmetric case, create symmetrized version of cutoffs and coefficients
if symmetric==1;
    cutoffs_u=zeros(length(cutoffs),1);
    betap_u=zeros(1,length(cutoffs));
    for n=1:length(cutoffs)
        cutoffs_u(n)=-cutoffs(end+1-n);
        betap_u(n)=betap(end+1-n);
    end
    for n=1:length(cutoffs)
        cutoffs_u(length(cutoffs)+n)=cutoffs(n);
        betap_u(length(cutoffs)+n)=betap(n);
    end
    betap_u(end+1)=1;
else
    cutoffs_u=cutoffs;
    betap_u=betap;
end


%Calculate denominator in cdf
prob_vec=zeros(length(cutoffs_u)+1,1);
for m=1:length(cutoffs_u)
    prob_vec(m+1)=normcdf((cutoffs_u(m)-theta)/sigma);
end
prob_vec(end+1,1)=1;
mean_Z1=prob_vec(2:end,1)-prob_vec(1:end-1,1);
denominator=mean_Z1'*betap_u';

%Calculate numerator in cdf
cutoffs_u(end+1)=inf;
if X<=cutoffs_u(1)
    numerator=normcdf((X-theta)/sigma)*betap_u(1);
else
    numerator=normcdf((cutoffs_u(1)-theta)/sigma)*betap_u(1);
    m=1;
    while X>cutoffs_u(m)
        Xcap=min(X,cutoffs_u(m+1));
        numerator=numerator+(normcdf((Xcap-theta)/sigma)-normcdf((cutoffs_u(m)-theta)/sigma))*betap_u(m+1);
        m=m+1;
    end
end

%Evaluate cdf
cdf=numerator/denominator;
end

