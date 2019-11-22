function selection_welfare(gitpath,filepath)
%set seed
rng(1);

application=0;

%add code and input file paths
addpath(strcat(gitpath,'/pub_bias/code_and_data_2019/Matlab'));
cd(strcat(filepath,'/data/inputs/causal_estimates/uncorrected'));

%loading the data
% 1 - skip estimating betap and assume kid estimates abs(t)>1.64 are 34.48x more
% 2 - estimate break at +/-1.64 on all estimates
% 3 - estimate break at +/-1.96 on all estimates
% 4 - estimate breaks at +/-1.64 and +/-1.96 on all estimates
samples = {'baseline', 'restricted'};
for mode = 1:4
    for kidnum = 0:1
        for s= 1:length(samples)
            sample = samples{s};
            outpath = strcat(filepath,'/data/inputs/causal_estimates/corrected/MLE/mode_', string(mode));
            input_data = strcat('kid_', string(kidnum), '_names.csv');
            data = readtable(input_data);

            names = data.estimate;
            X = data.pe(:,1);
            sigma = data.se(:,1);

            cluster_ID=data.clusterid(:,1);
            disp(sample)
            if strcmp(sample,'restricted')
                includeinestimation=logical(data.restricted(:,1));
            elseif strcmp(sample,'baseline')
                includeinestimation=logical(data.baseline(:,1));
            end

            n=size(X(includeinestimation),1);
            C=ones(length(X),1);

            name=strcat('welfare_kid_', string(kidnum), '_sample_', sample);

            %Set options for estimation
            identificationapproach=2;
            GMMapproach=0;

            %Estimate baseline model, rather than running spec test
            spec_test=0;
            %Set cutoffs to use in step function: should be given in increasing order;
            Psihat0=[0,10,1,1];    % [mean, sd of underlying dist., betap(1), betap(2)]

            if mode < 3
                cutoffs=[ -1.64,1.64];
                lb = [-inf 0 0 0 ];
            elseif mode == 3
                cutoffs = [ -1.96,1.96 ];
                lb = [-inf 0 0 0 ];

            else
                cutoffs = [-1.96,-1.64,1.64,1.96 ];
                lb = [-inf 0 0 0 0 0];
                Psihat0=[Psihat0,1,1];    %[mean, sd of underlying dist., betap(1), betap(2), betap(3), betap(4)]
            end

            %Use a step function not symmetric around zero
            symmetric=0;
            symmetric_p=0;
            asymmetric_likelihood_spec=1; %Use a normal model for latent distribution of true effects (spec 1)
            controls=0;
            numerical_integration=0;

            %starting values for optimization
            %estimating the model
            if mode>1
                display(strcat('mode: ',string(mode)))
                EstimatingSelection;
            else
                if kidnum == 1
                    Psihat = [0,1,1,34.48];
                else
                    Psihat = [0,1,1,1];
                end

                se_robust = [0,0,0,0]';
            end

            % export to csv
            filename = strcat(outpath,'/MLE_model_parameters_kid_',string(kidnum),'_sample_', sample,'.csv');
            csvwrite(filename,[Psihat;se_robust']);

            % MLE estimates for the true underlying parameters
            if strcmp(sample,'baseline')
                corrected_mle;
            end
        end
    end
end
close;
display('Publication bias estimation complete, please proceed');
end
