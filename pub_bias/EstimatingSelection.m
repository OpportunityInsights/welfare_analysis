%options for optimization and numerical derivatives
options=optimset( 'PlotFcn','optimplotfval','MaxFunEvals',10^7,'MaxIter',10^6,'TolFun',10^-8, 'TolX',10^-8);
%options=optimset('MaxFunEvals',10^3,'MaxIter',10^3,'TolFun',10^-8);
stepsize=10^-6;

if GMMapproach==0
    %setting the objective function
    if  identificationapproach==2
        %Use metastudy approach
        %Run model with normal distribution for latent effects
        %    LLH = @(Psi) VariationVarianceLogLikelihoodControls(Psi(1), Psi(2),...
        %       [reshape(Psi(3:end)',[length(Psi(3:end))/length(cutoffs),length(cutoffs)]) [1;zeros(size(C,2)-1,1)]]...
        %      ,cutoffs,symmetric, X(includeinestimation), sigma(includeinestimation),C(includeinestimation,:),numerical_integration);
        % this is what runs for welfare
        LLH = @(Psi) VariationVarianceLogLikelihoodControls(Psi(1), Psi(2),...
            [[Psi(1,3:3+((length(cutoffs)/2)-1))] [1] [Psi(1,(length(Psi)-((length(cutoffs)/2)-1):length(Psi)))]]...
            ,cutoffs,symmetric, X(includeinestimation), sigma(includeinestimation),C(includeinestimation,:),numerical_integration);

        nn=sum(includeinestimation);
    end
        
end

    
problem =  createOptimProblem('fmincon', 'objective', LLH,'x0', Psihat0, 'lb', lb, 'options', options);   
gs = GlobalSearch;
[Psihat, LLHmax] = run(gs,problem);
%[Psihat1, LLHmax] = fminunc(LLH,Psihat0,options);
%[Psihat, LLHmax] = fminunc(LLH,Psihat1,options);

%find the robust variance matrix
Var_robust=RobustVariance(stepsize, nn, Psihat, LLH,cluster_ID(includeinestimation));
se_robust=diag(Var_robust).^.5;
