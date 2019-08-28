clear all; 
close all;
%% Path
addpath(fullfile('Romberg_noiselet','Measurements'));
addpath(fullfile('Romberg_noiselet','Optimization'));
addpath(fullfile('Romberg_noiselet','Utils')); 
%% Size Specifications
M = 300; % length of h
N = 1; % number of signals 
K = 200; % length of signal expansion coefficents
J = 10; % Number of frames
it = 15; % to 
ehP = zeros(it,J);
ratio = zeros(it,1);
for IT = 1:1:it
        Q = 500 + 50*(IT-1); %length of signals
        L = Q; % length of ffts L >= max(Q,M)
        ratio(IT) = L/(N*(K+M));
        for num = 1:J
            %% Synthetic Signals 

            m = cell(N,1);
            for n = 1:N
                m{n} = randn(K,1);
            end
            h = randn(M,1); 



            %% General functions
            Nfft = @(x) (1/sqrt(L))*fft(x,L); %Normalized fft
            Nifft = @(x) sqrt(L)*ifft(x,L);

            %% Generating Coding Matrices C

            EE = cell(N,1);
            d = cell(N,1);
            for n = 1:N
                idx = randperm(Q);
            %     idx = 1:L;
                idx = idx(1:K);
                I = eye(Q);
                EE{n} = I(:,idx); % Array of N matrices each of size L x K
                d{n} = randsample([-1,1],Q,'true')';
            end

            CC = @(x,n) sqrt(L)*Nfft(d{n}.*(dct(EE{n}*x,Q)));
            CCT = @(x,n) sqrt(L)*(EE{n}'*idct(d{n}.*(eye(Q,L)*Nifft(x))));


            %% Implicit funtions for the action of B and B'

            BB = @(h) Nfft(h);
            BBT = @(w) speye(M,L)*Nifft(w);


            %% Measurements 

            y = cell(N,1);
            for n = 1:N
                y{n} = BB(h).*CC(m{n},n);
            end

            %% Initialization 

            % Generate matrix Bhat
            BB_exp = Nfft(eye(L,M));

            % Generate matrix Chat
            CC_exp = cell(N,1);
            for n = 1:N
                for i = 1:K
                    CC_exp{n}(:,i) = sqrt(L)*Nfft(d{n}.*dct(EE{n}(:,i),Q));
                end
            end
            XX = adjcA1d(y,BB_exp,CC_exp,N); % initialized value

            Xhat = concat1d(XX,N,K);
            [h0,s,m0] = svds(Xhat,1); 
            h0 = sqrt(s)*h0; m0 = sqrt(s)*m0; %initial value for Gradient Descent

            %% split

            split = @(x,n) x((n-1)*K+1:n*K);

            %% Gradient Descent 

            maxIter = 8000; 
            tau0 = 30; 
            mu = @(t) min(1-exp(-t/tau0), 0.2); 

            yi = cell(N,1);
            mm = cell(N,1);
            gradhh = zeros(M,1);
            gradmm = cell(N,1);

            for n = 1:N
                mm{n} = split(m0,n);
            end
            hh = h0; 

            mF = transpose(concat1d(cellfun(@transpose,m,'UniformOutput',false),N,K)); 
            error_m = zeros(maxIter,1);
            error_h = zeros(maxIter,1); 
            for i = 1:maxIter
                gradhh = zeros(M,1);
               for n = 1:N
                  xx = CC(mm{n},n);
                  ww = BB(hh);
                  yi{n} = ww.*xx;
                  gradhh = gradhh + BBT((yi{n}-y{n}).*conj(xx));
                  gradmm{n} = CCT((yi{n}-y{n}).*conj(ww),n);
                  mm{n} = mm{n} - mu(i)*gradmm{n}/s;
               end
               hh = hh - mu(i)*gradhh/s; 
               mmF = transpose(concat1d(cellfun(@transpose,mm,'UniformOutput',false),N,K));
               error_m(i) = norm(abs(mmF/norm(mmF))-abs(mF/norm(mF)));
               error_h(i) = norm(abs(hh/norm(hh))-abs(h/norm(h)));
            end

            %% Quantize Recovery Error
            xEst = cell(N,1); 
            xApp = cell(N,1);
            for n = 1:N
                xEst{n} = abs(Nifft(CC(mm{n},n))/sqrt(L));
                xApp{n} = abs(Nifft(CC(m{n},n))/sqrt(L));
            end
            mmF = transpose(concat1d(cellfun(@transpose,mm,'UniformOutput',false),N,K)); 
            ehm1 = norm(abs(hh*mmF'/norm(hh*mmF','fro'))-abs(h*mF'/norm(h*mF','fro')),'fro');
            if ehm1 <= 1
               ehP(IT,num) = ehm1;
            else
               ehP(IT,num) = 1;
            end
        end
end
ehP = sum(ehP,2)/J;
% figure;
plot(ratio,ehP), xlabel('Oversampling: L/(N*(K+M))'), ylabel('Relative error');
