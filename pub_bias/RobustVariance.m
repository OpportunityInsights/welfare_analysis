function Var_robust=RobustVariance(stepsize,n, thetahat, LLH,cluster_ID)


        Info=zeros(length(thetahat));
        for n1=1:length(thetahat)
            for n2=1:length(thetahat)
                thetaplusplus=thetahat;
                thetaplusminus=thetahat;
                thetaminusplus=thetahat;
                thetaminusminus=thetahat;

                thetaplusplus(n1)=thetaplusplus(n1)+stepsize;
                thetaplusplus(n2)=thetaplusplus(n2)+stepsize;
                LLH_plusplus=LLH(thetaplusplus);

                thetaplusminus(n1)=thetaplusminus(n1)+stepsize;
                thetaplusminus(n2)=thetaplusminus(n2)-stepsize;
                LLH_plusminus=LLH(thetaplusminus);

                thetaminusplus(n1)=thetaminusplus(n1)-stepsize;
                thetaminusplus(n2)=thetaminusplus(n2)+stepsize;
                LLH_minusplus=LLH(thetaminusplus);

                thetaminusminus(n1)=thetaminusminus(n1)-stepsize;
                thetaminusminus(n2)=thetaminusminus(n2)-stepsize;
                LLH_minusminus=LLH(thetaminusminus);

                Info(n1,n2)=((LLH_plusplus-LLH_plusminus)/(2*stepsize)-(LLH_minusplus-LLH_minusminus)/(2*stepsize))/(2*stepsize);
            end
        end

        Var=Info^-1;

        %Calculate misspecification-robust standard errors
        score_mat=zeros(n , length(thetahat));
        for n1=1:length(thetahat)
            theta_plus=thetahat;
            theta_plus(n1)=theta_plus(n1)+stepsize;
            [LLH_plus, logL_plus]=LLH(theta_plus);
            theta_minus=thetahat;
            theta_minus(n1)=theta_minus(n1)-stepsize;
            [LLH_minus, logL_minus]=LLH(theta_minus);
            score_mat(:,n1)=(logL_plus-logL_minus)/(2*stepsize);
        end
        %Cov=cov(score_mat);
        disp(size(score_mat))
        Cov=Clustered_covariance_estimate(score_mat,cluster_ID);

        Var_robust=n*Info^-1*Cov*Info^-1;
end