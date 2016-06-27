function [Estimation_X0] = Ideal_EKF_update(Estimation_X0, CameraMeasurementThis, obsv_sigma, Aorientation, Aposition, landmarks)
% function [Estimation_X0, Cov_EstX0, IndexOfFeature] = LEKFonestepUpdate(Estimation_X0, CameraMeasurementThis, obCov)
% 
% Estimation_X0     - state vector after propagation(prediction)
% CameraMeasurementThis
%                   - observations
% obCov             - observation convariance
%
% Estimation_X0     - update state vector, STRUCT: robot poses, landmarks
%                     and covariance


NumberOfLandmarksObInThisStep = size(CameraMeasurementThis,1)/3;

% initialise the IndexOfFeature if possible
if size(Estimation_X0.landmarks,2) > 0
    IndexOfFeature = Estimation_X0.landmarks(4,:)';
else
    IndexOfFeature = [];
end

IndexObservedAlreadyThis = [];
IndexObservedNew = [];   
for i = 1:NumberOfLandmarksObInThisStep
    % check whether the feature is observed before or not
    M = find( IndexOfFeature== CameraMeasurementThis(3*i,2) );
    if isempty(M)
        IndexObservedNew = [IndexObservedNew;CameraMeasurementThis(3*i,2) ];
    else
        IndexObservedAlreadyThis = [IndexObservedAlreadyThis;CameraMeasurementThis(3*i,2)];
    end             
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% IndexObservedNew=[78; 97; 18] indicates that the 
% robot firstly observes landmarks 78 97 18 in this step
% IndexObservedAlreadyThis=[19; 20; 53] indicates 
% that the robot observes again landmarks 19 20 53 in this step
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


orientation = Estimation_X0.orientation;
position    = Estimation_X0.position;
cov         = Estimation_X0.cov;

NumberOfFeature = size( IndexOfFeature,1);
NumberOfOldFeatureInThisStep = size(IndexObservedAlreadyThis,1);
NumberOfNewFeatureInThisStep = size(IndexObservedNew,1);
 
   
% update state and covariance 
if ~isempty(IndexObservedAlreadyThis)
    Z = zeros( NumberOfOldFeatureInThisStep*3 , 1); 
    Y = zeros( NumberOfOldFeatureInThisStep*3 , 1); 
    H = zeros(3*NumberOfOldFeatureInThisStep, 6+3*NumberOfFeature);
    
    temp = repmat({eye(3)}, NumberOfOldFeatureInThisStep,1 );
    R = blkdiag(temp{:});
    
    % update old features
    for i = 1:NumberOfOldFeatureInThisStep
        ind = find(IndexOfFeature == IndexObservedAlreadyThis(i));
        fi  = Estimation_X0.landmarks(1:3,ind);
        
        Afi=landmarks(IndexObservedAlreadyThis(i) ,:)';
        Y(3*i-2:3*i,1) = observation_model( orientation, position, fi );
        AY=observation_model( Aorientation, Aposition, Afi );
        
        ind2 = find(CameraMeasurementThis(:,2) == IndexObservedAlreadyThis(i));
        Z(3*i-2:3*i,1 ) = CameraMeasurementThis(ind2,1);
        
        H(3*i-2:3*i, 1:6) = [-skew(AY) Aorientation'];
        H(3*i-2:3*i, 6+3*ind-2:6+3*ind) = -Aorientation';
        R(3*i-2:3*i,3*i-2:3*i) = diag(CameraMeasurementThis(ind2,1).^2)*obsv_sigma^2;
    end    
    
    % question @RomaTeng, different computaton scheme
    z = Z-Y;
    S = H*cov*H'+R;
    K = cov*H'*inv(S);
    s = K*z;
    
    Estimation_X0 = special_add_ideal_ekf(Estimation_X0,-s);
    cov = ( eye(6+3*NumberOfFeature) -K*H )*cov;
    Estimation_X0.cov = cov;
    
    % @todo @RomaTeng, right Jacobian
    %Estimation_X0.cov=JJJr(-s)*cov*(JJJr(-s))';
end  
     

% update state vector and covariance by considering 
% new feature into state and covariance
if ~isempty(IndexObservedNew)
    % copy previous covariance
    temp    = repmat({eye(3)}, NumberOfNewFeatureInThisStep, 1 );
    tempKK  = blkdiag(temp{:});
    Sigma   = blkdiag(Estimation_X0.cov,tempKK);
    KK      = eye(6+3*(NumberOfFeature+NumberOfNewFeatureInThisStep));
    
    % add new features
    for i = 1:NumberOfNewFeatureInThisStep
        indNewf = IndexObservedNew(i);
        Estimation_X0.landmarks(4,NumberOfFeature+i) = indNewf;
        m2 = find( CameraMeasurementThis(:,2) == indNewf );
        nf = CameraMeasurementThis( m2, 1 );
        Anf=landmarks( indNewf,1:3)';
        %Estimation_X0.landmarks(1:3,NumberOfFeature+i) = Estimation_X0.orientation*nf+Estimation_X0.position;
        Estimation_X0.landmarks(1:3,NumberOfFeature+i) = Aorientation*nf+Aposition;
        KK( 6+3*NumberOfFeature+3*i-2:6+3*NumberOfFeature+3*i,1:6 ) = [-Aorientation*skew(Anf) eye(3)];  
        KK (6+3*NumberOfFeature+3*i-2:6+3*NumberOfFeature+3*i, 6+3*NumberOfFeature+3*i-2:6+3*NumberOfFeature+3*i )=Aorientation;
        tempKK(3*i-2:3*i,3*i-2:3*i)=diag(nf.^2)*obsv_sigma^2;
    end
    Sigma   = blkdiag(Estimation_X0.cov,tempKK);
    Estimation_X0.cov = KK*Sigma*KK';
end

end
  
     
     


