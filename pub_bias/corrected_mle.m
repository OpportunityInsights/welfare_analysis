% get t-stats
t = X./sigma;
se = sigma;

obs = size(t,1);

%Define zones for pub bias
beta = [Psihat(3:3+((length(cutoffs)/2)-1)), 1 ,  Psihat(length(Psihat)-((length(cutoffs)/2)-1):length(Psihat))]';
regions = size(cutoffs,1)+1;
%Initialise estimates
init_theta = t;

% Define objective
costFunction = @(theta) llh_pubbias(theta, t, beta, cutoffs);

% Set options
options=optimset( 'PlotFcn','optimplotfval','MaxFunEvals',10^7,'MaxIter',10^6,'TolFun',10^-8, 'TolX',10^-8);


% Minimise cost function

problem_correction =  createOptimProblem('fmincon', 'objective', costFunction,'x0', init_theta, 'options', options);  
gs = GlobalSearch;
[theta, fval] = run(gs,problem_correction);
%[theta, fval] = fminunc(costFunction, init_theta, options);

%save
filename = strcat(outpath,'/MLE_corrected_estimates_kid_',string(kidnum),'_sample_', sample,'.csv');
csvwrite(filename,[theta t]);
