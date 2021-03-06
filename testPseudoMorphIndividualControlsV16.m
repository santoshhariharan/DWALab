%% PSEUDOMORPH - CODE
% Read data
% Filter Data
%     - For Intensity
%     - For Morphology
%     - For Focus
%     - For expression
% Cluster data (Repeat)
%     - Per control K = 5
%     - Create MST for each run by jaccard
% Save multiple MST
%
clear;clc;close all;
warning('off','all');
%% Read data from files
%
% Module - 1:
% Define Variables

fprintf('Starting pseudomorph\n');
% Define Inputs:
% pth='F:\Projects\Proteinlocalization\PseudoMorph\Bin2Data';
allPth = {'F:\Projects\Proteinlocalization\PseudoMorph\Bin2Data\Mito-ER';
%         'F:\Projects\Proteinlocalization\PseudoMorph\Bin2Data\SecPathway';
%     'F:\Projects\Proteinlocalization\PseudoMorph\Bin2Data\ER';
%     'F:\Projects\Proteinlocalization\PseudoMorph\Bin2Data\Golgi';
%     'F:\Projects\Proteinlocalization\PseudoMorph\Bin2Data\Mito-Mam';
%     'F:\Projects\Proteinlocalization\PseudoMorph\Bin2Data\Peroxisome-LaminA';
%     'F:\Projects\Proteinlocalization\PseudoMorph\Bin2Data\Rabs';
%     'F:\Projects\Proteinlocalization\PseudoMorph\Bin2Data\SVPM-Lamp1';
    };
opFilePrefix = {'MITO-MET-PSS1-ER'};

featureReduction = false;
if(featureReduction)
    featStatus = 'True';
    numFeatures = 30;
else
    featStatus = 'False';
    numFeatures = 160;
end
% numFeatures = 60;
columnForControls = 9;
columnForOrganelle = 10;

fprintf('Feature reduction: %s\n',featStatus);
fprintf('---Number Feature: %i\n',numFeatures);
fprintf('Control column: %i\n',columnForControls);
for iDir = 1:size(allPth,1)
    pth = allPth{iDir,:};
    fprintf('Path: %s\n',pth);
    load(fullfile(pth,'parameters.mat'));% Load parameter file
    param.rootpath = pth;
    intensityFeature = 'Ch2_INT_Cell_intensity';
    intFeat = strcmpi(intensityFeature,param.datahdr);
    nucAreaFeat = strcmpi('Ch1_MOR_Nucleus_area',param.datahdr);
    cellAreaFeat = strcmpi('Ch1_MOR_Cytoplasm_area',param.datahdr);
    filePrefix = '.txt';
    fNames = dir(pth);
    
    
    % Module 3: Read & Load data after filtering
    fprintf('Module 3.......\n');
    mxRw = 1000000;
    allD = zeros(mxRw,sum(param.datafeat));
    allInten = zeros(mxRw,1);
    allMorRatio = zeros(mxRw,1);
    allTxt = cell(mxRw,1);
    allTxtValues = cell(mxRw,17);
    allTxtOrg = cell(mxRw,1);
    cnt = 1;
    fprintf('Completed Reading................');
    for iFiles = 3:size(fNames,1)
        fprintf('\b\b\b\b\b\b\b\b\b%8.3f%%',iFiles*100./size(fNames,1));
        if(fNames(iFiles).isdir)
            continue;
        end
        tok = regexpi(fNames(iFiles).name,filePrefix,'match');
        if(isempty(tok))
            continue;
        else
            D = readfiles(cellstr(fNames(iFiles).name),param);
        end
        %     Remove cells out of focus
        focus = getFocusFilteredData(D.data,param);
        D.data = D.data(focus,:);
        D.textdata = D.textdata(focus,:);
        ii = (D.data(:,strcmpi('Ch1_INT_Nucleus_intensity',param.datahdr))./...
            D.data(:,strcmpi('Ch1_INT_Cytoplasm_intensity',param.datahdr)))>3.5;
        jj = (D.data(:,strcmpi('Ch1_INT_Nucleus_intensity_stddev',param.datahdr))./...
            D.data(:,strcmpi('Ch1_INT_Cytoplasm_intensity_stddev',param.datahdr)))>3.5;
        ii = and(ii,jj);
        
        D.data = D.data(ii,:);
        D.textdata = D.textdata(ii,:);
        allInten(cnt:cnt+size(D.data,1)-1,:) = D.data(:,intFeat);
        %     allMorIntensity(cnt:cnt+size(D.data,1)-1,:) = D.data(:,roiIntFeat);
        allMorRatio(cnt:cnt+size(D.data,1)-1,:) = D.data(:,nucAreaFeat)./...
            (D.data(:,cellAreaFeat)+D.data(:,nucAreaFeat));
        allD(cnt:cnt+size(D.data,1)-1,:) = D.data(:,param.datafeat);
        allTxt(cnt:cnt+size(D.data,1)-1,:)= D.textdata(:,columnForControls);
        allTxtValues(cnt:cnt+size(D.data,1)-1,:) = D.textdata(:,1:17);
        %     allTxt(cnt:cnt+size(D.data,1)-1,:)= D.textdata(:,:);
        allTxtOrg(cnt:cnt+size(D.data,1)-1,:)= D.textdata(:,columnForOrganelle);
        cnt = cnt+size(D.data,1);
    end
    if(cnt<mxRw)
        allD = allD(1:cnt-1,:);
        allInten = allInten(1:cnt-1,:);
        allTxt = allTxt(1:cnt-1,:);
        allMorRatio = allMorRatio(1:cnt-1,:);
        allTxtValues = allTxtValues(1:cnt-1,:);
        %     allMorIntensity = allMorIntensity(1:cnt-1,:);
        allTxtOrg = allTxtOrg(1:cnt-1,:);
    end
    fprintf('\n');
    %% Remove Artifacts and noise
    
    % Remove NaN entries
    ii = sum(isnan(allD),2) ==0;
    allD = allD(ii,:);
    allInten = allInten(ii,:);
    allTxt = allTxt(ii,:);
    allMorRatio = allMorRatio(ii,:);
    allTxtValues = allTxtValues(ii,:);
    % allMorIntensity = allMorIntensity(ii,:);
    allTxtOrg= allTxtOrg(ii,:);
    fprintf('\nRemoved NAN %i\n',sum(~ii));
    
    % Remove incorrectly segmented & low intensity Objects
    ii = allMorRatio <= .5 & allMorRatio >= .2; % Value of this needs optimization
    allD = allD(ii,:);
    allTxt = allTxt(ii,:);
    allTxtOrg = allTxtOrg(ii,:);
    allInten = allInten(ii,:);
    allTxtValues = allTxtValues(ii,:);
    % allMorRatio = allMorRatio(ii,:);
    % allMorIntensity = allMorIntensity(ii,:);
    fprintf('#Cells Removed 4 Morphology %i of %i\n',sum(~ii),numel(ii));
    
    
    % Remove cells with low intensity
    ii = allInten > 100;
    allD = allD(ii,:);
    allTxt = allTxt(ii,:);
    allTxtOrg = allTxtOrg(ii,:);
    allInten = allInten(ii,:);
    allTxtValues = allTxtValues(ii,:);
    fprintf('#Cells Removed 4 Intensity %i of %\n',sum(~ii));
    
    % Remove Lower 5% and upper 5% data for each control
    uControls = unique(allTxt);
    jj = false(size(allTxt,1),1);
    for i = 1:numel(uControls)
        ii = find(strcmpi(uControls{i,:},allTxt));
        kk = allInten(ii,1)>quantile(allInten(ii,1),.05) &...
            allInten(ii,1)<quantile(allInten(ii,:),.95);
        jj(ii(kk)) = true;
    end
    allD = allD(jj,:);
    allTxt = allTxt(jj,:);
    allTxtOrg = allTxtOrg(jj,:);
    allInten = allInten(jj,:);
    allTxtValues = allTxtValues(jj,:);
    % param.meaninc = mean(allD);
    % param.varinc = var(allD);
    fprintf('#Cells removed by lower-upper quartile %i\n',sum(~jj));
    
    
    % Remove intensity correlated features
    % rho = corr(allD,allInten);
    newHeader = param.datahdr(1,param.datafeat);
    % ii = find(param.datafeat);
    % corrFeat = rho>-.5 & rho < .5;% Retain columns between -.5 & 0,5
    % param.datafeat(1,ii(~corrFeat)) = false;
    % allD = allD(:,corrFeat);
    % fprintf('#Features removed due to correlation %i\n',sum(~corrFeat));
    % fprintf('%s\n',newHeader{1,~corrFeat});
    % newHeader = newHeader(1,corrFeat);
    
    
    % Remove features having 75% same data
    % [~,F] = mode(allD,1);
    % F= F./size(allD,1);
    % jj = F<.75;
    % ii = find(param.datafeat);
    % param.datafeat(1,ii(~jj)) = false;
    %
    % newHeader = newHeader(1,jj);
    % allD = allD(:,jj);
    % Feature Selection/Reduction
    % newHeader = param.datahdr(1,param.datafeat);
    
    
    if(numel(newHeader)<=numFeatures)
        featureReduction = false;
        fprintf('TURNED OFF FEATURE REDUCTION\n');
    end
    if(featureReduction)
        %     redFeatures = unsupervisedGreedyFS(allD,numFeatures);
        [redFeatures,scores] = unsupervisedPCASelect( allD,numFeatures );
    else
        redFeatures = true(1,size(allD,2));
    end
    
    ii = find(param.datafeat);
    param.datafeat(1,ii(~redFeatures)) = false;
    fprintf('# Number of features %i\n',sum(redFeatures));
    fprintf('Features Chosen\n')
    fprintf('%s\n',newHeader{1,redFeatures});
    % [cf]= princomp(allD(:,redFeatures));
    allD = allD(:,redFeatures);
    % Print number of cells per control
    for i = 1:numel(uControls)
        ii = (strcmpi(uControls{i,:},allTxt));
        fprintf('%s\t: %d\n',uControls{i,:},sum(ii));
    end
    
    % Normalization
    meanD = mean(allD);
    stdD = std(allD);
    allD = zscore(allD);
%     allD = bsxfun(@minus,allD,param.meanD);
%     allD = bsxfun(@rdivide,allD,param.stdD);
    
    clear D focus cnt tok iFiles mxRw
    clear allMorRatio
    clear ii jj kk rho mxRw
    clear intensityFeature roiIntFeat
    clear fNames filePrefix randPrc
    % clear allInten
    
    % Create an RF classifier to remove cells classidi
    %% RUN RF on TACB5D Low + HIGH and remove cells classified as low
    % gps = getGroupIndices(allTxt,unique(allTxt));
    % controlName = 'TACB5';
    % controlIndex = strcmpi(uControls,controlName);
    % if(sum(controlIndex)>0)
    %     controlIndex = find(gps == find(strcmpi(uControls,controlName)));
    %     medInten = median(allInten(controlIndex));
    %     ii = allInten(controlIndex)< medInten;
    %     gps(controlIndex(ii)) = max(gps)+1;
    %
    %     % Create
    %     minSamplePerControl = 20000;
    %     for i = 1:max(gps)
    %         minSamplePerControl = min(minSamplePerControl,sum(gps ==i ));
    %     end
    %     dataPar = equalTrainingSamplePartition(gps,minSamplePerControl)';
    %     mdl = classRF_train(allD(dataPar.training,:),gps(dataPar.training),100,...
    %                 floor(sqrt(size(allD,2))));
    %     lbl = classRF_predict(allD,mdl);
    %     ii = lbl == max(gps);
    %     allD = allD(~ii,:);
    %     allTxt = allTxt(~ii,:);
    % %     gps = gps(~ii,:);
    %     ii = strcmpi(allTxt,controlName);
    %     allD = allD(~ii,:);
    %     allTxt = allTxt(~ii,:);
    % %     gps(ii) = 0;
    % end
    % disp('Done');
    %% Cluster data using Phenograph
    getEqualSamples  = false;
    gps = getGroupIndices(allTxt,unique(allTxt));
    numRpt = 1;
    samIndex = false(numel(gps),numRpt);
    minSamplePerControl = 20000;
    k = 5;
    graphType = 'jaccard';
    % Pick minimum set of samples
    for i = 1:max(gps)
        minSamplePerControl = min(minSamplePerControl,sum(gps ==i ));
    end
    minSamplePerControl = floor(.7*minSamplePerControl);
    fprintf('minimum samples per control %i\n',minSamplePerControl);
    mCent = nan(1000,size(allD,2));
    mGrp = nan(1000,1);
    mSet = nan(1000,1);
    mFraction = nan(1000,1);
    mText = cell(1000,17);
    cnt = 1;
    for iRpt = 1:numRpt
        fprintf('**********************************************\n');
        fprintf('*****REPEAT %i\n',iRpt);
        fprintf('**********************************************\n');
        for i = 1:max(gps)
            ii = find(gps == i);
            samIndex(ii(randperm(numel(ii),minSamplePerControl)),iRpt) = true;
        end
        % Cluster Samples data for high number of clusters
        
        if(getEqualSamples)
            nGps = gps(samIndex(:,iRpt));
            data4Clustering = allD(samIndex(:,iRpt),:);
        else
            nGps = gps;
        end
        for iControl = 1:max(nGps)
            ii = nGps==iControl;
            fprintf('%s\n - %d\n',uControls{iControl,:},sum(ii));
            if(getEqualSamples)
                grpData = data4Clustering(ii,:);
            else
                grpData = allD(ii,:);
            end
            grpTxtValues = allTxtValues(ii,:);
            indx = phenograph(grpData,k,'graphtype',graphType);
            uIndx = unique(indx);
            for i = 1:numel(uIndx)
                mCent(cnt,:) = mean(grpData(indx==uIndx(i),:));
                [knnIdx] = knnsearch(grpData(indx==uIndx(i),:),mCent(cnt,:),'K',1);
                mText(cnt,:) = grpTxtValues(knnIdx,:);
                mGrp(cnt,1) = iControl;
                mSet(cnt,1) = iRpt;
                mFraction(cnt,1) = sum(indx==uIndx(i))/numel(indx);
                cnt = cnt+1;
            end
        end
        %
    end
    ii = sum(isnan(mCent),2)==0;
    mCent = mCent(ii,:);
    mGrp  = mGrp(ii,:);
    mSet = mSet(ii,:);
    mText = mText(ii,:);
    mFraction = mFraction(ii,:);
    controlNames = unique(allTxt);
    dataFeat = param.datafeat;
    %
    opFilename = fullfile(pth,[opFilePrefix{iDir,:} '_centroidPerControl_Feat' num2str(size(mCent,2)) 'F_' num2str(k) 'K.mat']);
    save(opFilename,'mCent','mGrp','mSet',...
        'meanD','stdD','mFraction','controlNames',...
        'dataFeat','mText');
end
disp('Done');
clear grpData indx uIndx ii data4Clustering nGps;
return;
