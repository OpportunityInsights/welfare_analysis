function [C] = cost(theta, z, beta, cuts)

obs = size(z,1);

% make p(z)
% make indicators for which cuts each observation is less than
less_z = (z<=cuts.*ones(obs,1));
% indicator matrix for regions
region_z = [less_z, ones(obs,1)] - [zeros(obs,1),less_z];
% get p(z)
p = region_z*beta;

% make E(p(Z*))
F1 = [normcdf(cuts,theta,1), ones(obs,1)]; % probability each observation lies below each cutoff (with infinity at top)
F2 = [zeros(obs,1), normcdf(cuts,theta,1)]; % probability each observation lies above each cutoff (with -infinity at bottom)
E = (F1-F2)*beta; % Probability each observation lies in each region, multiplied by pub. prob. in region

% make f(z)
phi = normpdf(z,theta,ones(obs,1));

% bring together for individual likelihoods
all_L = p.*phi./E;

% take logs and collapse to get LL
LL = sum(log(all_L));

C = -LL;

end
