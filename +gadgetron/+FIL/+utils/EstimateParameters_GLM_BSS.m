%%*******************************************************%%
%%% General linear model built with every acquired echoes
%%% Coil combination required beforehand
%%% Inputs: Complex data of dimension: [nx,ny,nz,nEchoes,nSets] (nSets=2)
%%%         TE vector of Echo times of all the echoes in sec
%%%         NbEchoes: Number of echoes in total
%%%         NbEchoesBefore: Number of echoes before the BS pulse
%%%         mask : mask
%%%
%%% returns the residuals(err) of the GLM and the parameters (beta)with
%%% dimensions [nx*ny*nz] and [nx*ny*nz,5] respectively
%%% NC 09/04/20
%%%********************************************************



function [beta,err]=EstimateParameters_GLM_BSS(Data,TE,NbEchoes,NbEchoesBefore,mask)

addpath(genpath('../+gadgetron/+FIL/+utils/QSMbox-master-471d609988c23ef02329bdacfc2c07f614db5c97/master/ptb/_3DSRNCP'))

%% unwrap phase
for set=1:2
    
    % Data dim: [nx,ny,nz,nEchoes,nSets]
    Pr= angle(Data(:,:,:,:,set));
    
    % Keep the first echo
    uwp(:,:,:,1)=Pr(:,:,:,1);
    
    % Unwrap the difference of successive echoes
    for k=2:NbEchoes
        d=Pr(:,:,:,k)-Pr(:,:,:,k-1);
        [uwpd,reliability_msk] =m1_shf_3DSRNCP(d,mask,2.1);
        
        if median(uwpd(mask>0))> pi
            uwpd=uwpd-2*pi;
        end
        
        uwp(:,:,:,k)=uwp(:,:,:,k-1)+uwpd;
   
    end
    Newuwp(:,:,:,:,set)=uwp;
end

Pu=reshape(Newuwp,[],NbEchoes*2);

A=reshape(abs(Data),[],NbEchoes*2);


%% GLM

% initialize design matrix
X=zeros(NbEchoes*2,5);

% Even/Odd regressor
X((1:2:NbEchoes),1)=1;
X(((NbEchoes+1):2:2*NbEchoes),1)=1;

% BSS regressor
X(((NbEchoesBefore+1):NbEchoes),2)=1;
X(((NbEchoes+NbEchoesBefore+1):2*NbEchoes),2)=-1;

% B0 regressor
X((1:NbEchoes),3)=TE;
X(((NbEchoes+1):(2*NbEchoes)),3)=TE;

%%% Different phase offset for the two frequency offsets
X((1:NbEchoes),4)=1;
X(((NbEchoes+1):2*NbEchoes),5)=1;


%%% Pre-whitening
% assumption : variance of the phase proportional to the square of the inverse of the
% magnitude, V=inv(A^2) (V= covariance matrix)
% pre-whitening with W such that W'W=inv(V) => W=sqrt(inv(V))=> W=A;
W=A';

%%% pre-whitening and Ordinary least square
maskR=reshape(mask,[],1);
ind=find(maskR);
beta=zeros(5,length(A));
for k=1:length(ind)
    wX=diag(W(:,ind(k)))*X;
    wPu=diag(W(:,ind(k)))*Pu(ind(k),:)';
    beta(:,ind(k))=inv(wX'*wX)*wX'*wPu;
end

%%% error
err=Pu'-X*beta;


