function [LLH, logL] = VariationVarianceLogLikelihoodControls(lambdabar, tauhat, betap, cutoffs, symmetric, X, sigma,C,numerical_integration)

%arguments: mean and stdev of distribution pi of mu
%coefficient vector for polynomial logit p
%n vector X of estimates
%vector of stdevs of X

n=length(X);

%regressors for step function p
T=X./sigma;

Tpowers=zeros(n,length(cutoffs)+1);
if symmetric==1
    Tpowers(:,1)=abs(T)<cutoffs(1);
    if length(cutoffs)>1
        for m=2:length(cutoffs)
            Tpowers(:,m)=(abs(T)<cutoffs(m)).*(abs(T)>=cutoffs(m-1));
        end
    end
    Tpowers(:,end)=abs(T)>=cutoffs(end);
else
    Tpowers(:,1)=T<cutoffs(1);
    if length(cutoffs)>1
        for m=2:length(cutoffs)
            Tpowers(:,m)=(T<cutoffs(m)).*(T>=cutoffs(m-1));
        end
    end
    Tpowers(:,end)=T>=cutoffs(end);
end

%%%%%%%%%%%%%%%%%%%%%%%%
% Calculate objective function LLH

%calculating components of the likelihood
%vector of estimated publication probabilities
phat=zeros(size(Tpowers,1),1);
for m=1:size(Tpowers,2)
    Cmat=repmat(Tpowers(:,m),1,size(C,2)).*C;
    phat=phat+Cmat*betap(:,m);
end

%vector of un-truncated likelihoods
if symmetric==1
    %fX=0.5*normpdf(X,lambdabar, sqrt(sigma.^2 + tauhat^2))+0.5*normpdf(-X,lambdabar, sqrt(sigma.^2 + tauhat^2));
    
    %     %likelihoods calculated by numerical integration, normal distribution
    %     g=@(theta) (0.5*normpdf((X-theta)./sigma)+0.5*normpdf((-X-theta)./sigma))./sigma...
    %         .*normpdf(theta,lambdabar,tauhat);
    
    if numerical_integration==1
        %likelihoods calculated by numerical integration, gamma distribution
        g=@(theta) (0.5*normpdf((X-theta)./sigma)+0.5*normpdf((-X-theta)./sigma))./sigma...
            .*gampdf(theta,lambdabar,tauhat);
        
        fX=integral(g,-inf,inf,'Arrayvalued',true);
    else
        %Monte-carlo integration
        rng(1)
        draw=rand(1,10^5);
        theta_vec=gaminv(draw,lambdabar,tauhat);
        theta_mat=repmat(theta_vec,n,1);
        X_mat=repmat(X,1,length(theta_vec));
        sigma_mat=repmat(sigma,1,length(theta_vec));
        g= (0.5*normpdf((X_mat-theta_mat)./sigma_mat)...
            +0.5*normpdf((-X_mat-theta_mat)./sigma_mat))./sigma_mat;
        clear Xmat
        fX=mean(g,2);
    end
    
else
        fX=normpdf(X,lambdabar, sqrt(sigma.^2 + tauhat^2));
end

%normalizing constant
mu_vec=lambdabar*ones(n,1);
sigma_tilde_vec=((tauhat)^2 +sigma.^2).^.5;
prob_vec=zeros(n,length(cutoffs)+1);
if symmetric==1
    for m=1:length(cutoffs)
        %          prob_vec(:,m+1)=(normcdf((cutoffs(m)*sigma-mu_vec)./sigma_tilde_vec)...
        %             -normcdf((-cutoffs(m)*sigma-mu_vec)./sigma_tilde_vec));
        
        %         %Normalizing constant, normal distribution
        %         g=@(theta)(normcdf(cutoffs(m)-theta./sigma)-normcdf(-cutoffs(m)-theta./sigma))...
        %            .*normpdf(theta,lambdabar,tauhat);
        
        if numerical_integration==1
            %Normalizing constant, gamma distribution
            g=@(theta)(normcdf(cutoffs(m)-theta./sigma)-normcdf(-cutoffs(m)-theta./sigma))...
                .*gampdf(theta,lambdabar,tauhat);
            prob_vec(:,m+1)=integral(g,-inf,inf,'Arrayvalued',true);  
        else
            %Monte Carlo Integration
            g=(normcdf(cutoffs(m)-theta_mat./sigma_mat)...
                -normcdf(-cutoffs(m)-theta_mat./sigma_mat));
            prob_vec(:,m+1)=mean(g,2);
        end
    end
    prob_vec(:,end+1)=1;
    mean_Z1=prob_vec(:,2:end)-prob_vec(:,1:end-1);
else
    for m=1:length(cutoffs)
        prob_vec(:,m+1)=normcdf((cutoffs(m)*sigma-mu_vec)./sigma_tilde_vec);
    end
    prob_vec(:,end+1)=1;
    mean_Z1=prob_vec(:,2:end)-prob_vec(:,1:end-1);
end

normalizingconst=zeros(n,1);
parameter_space_violation=0;
for m=1:size(mean_Z1,2)
    Cmat=C.*repmat(mean_Z1(:,m),1,size(C,2));
    normalizingconst=normalizingconst+Cmat*betap(:,m);
    if min(Cmat*betap(:,m))<0
        parameter_space_violation=1;
    end
end

%vector of likelihoods
L=phat.*fX./normalizingconst; %cf equation 25 in the draft
logL=log(phat)+log(fX)-log(normalizingconst);
%logL=log(L);

LLH=-sum(log(L)); %objective function; note the sign flip, since we are doing minimization
if parameter_space_violation==1
    LLH=10^5;
end
end