
% settings

pad_tipID = [3,1];
pad_IDs = [3,2; 3,3; 3,4];
pointer_IDs = [3,6; 3,7; 3,8];

% for tip position
velThresh = 2000;
distThreshold = 10;

axLims = [-2000 2000];


[coeffs, expectedDistances, markerPairings, TCM_LED_IDs] = ...
    doCalibrationProcedure(pad_tipID, pad_IDs, pointer_IDs);


quit = false;
hFig = figure('units','normalized','outerposition',[0.1 0.1 0.7 0.7]);
hAx = axes();
axis equal
plot3(hAx, 0,0,0)
hold on
grid on
goodDataCounter = 0;
iterationCounter = 0;
goodDataFrameRates = [];
iterationFrameRates = [];
tic
while ~quit

    if toc >= 1        
        %disp(['Loop iteration rate (last second): ', ...
        %    num2str(iterationCounter)]);          
        %disp(['Good data frame rate (last second): ', ...
        %    num2str(goodDataCounter)]);          
        goodDataFrameRates(end+1) = goodDataCounter;
        iterationFrameRates(end+1) = iterationCounter;
        goodDataCounter = 0;
        iterationCounter = 0;
        tic    
    end
        
    %disp('loop running')
    
    %delete(hAx.Children)        
        
    %if detectDuplicateRows(VzGetDat)
        
        [tp, trackerTime, dataGood] = tipPosition(TCM_LED_IDs, coeffs, velThresh, ...
                         markerPairings, expectedDistances, distThreshold);     

        if dataGood 
            mColor = 'g';
            goodDataCounter = goodDataCounter + 1;
        else
            mColor = 'r';
        end

%         [h_comp, h_axs] = drawCube(hAx, tp);
%         plot3(tp(1), tp(2), tp(3), 'marker', 'o', 'color', mColor, 'markerfacecolor', mColor)
% 
%         set(hAx, 'XLim', axLims, 'YLim', axLims, 'ZLim', axLims);                 
%         drawnow
    
    %else
        
        %disp('Skipped frame due to duplicate data rows');
        
    %end
    
    iterationCounter = iterationCounter + 1;
    
end
