function Sigma= Clustered_covariance_estimate(g,cluster_index)
%given a matrix of moment condition values g, compute a clustering-robust
%estimate of the covariance matrix Sigma
[cluster_index, I]=sort(cluster_index);
g=g(I,:);
g=g-repmat(mean(g,1),size(g,1),1);
gsum=cumsum(g,1);
index_diff=cluster_index(2:end,1)~=cluster_index(1:end-1,1);
index_diff=[index_diff;1];
gsum=[gsum(index_diff==1,:)];
gsum=[gsum(1,:); diff(gsum)];
Sigma=1/(size(g,1)-1)*(gsum'*gsum);
end

