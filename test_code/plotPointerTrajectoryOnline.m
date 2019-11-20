
% settings

pad_tipID = [1,1];
pad_IDs = [1,2; 1,3; 1,4];
pointer_IDs = [1,6; 1,7; 1,8];

% for tip position
velThresh = 500;
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
while ~quit
    
    disp('loop running')
    
    delete(hAx.Children)        
        
    [tp, ~, dataGood] = tipPosition(TCM_LED_IDs, coeffs, velThresh, ...
                     markerPairings, expectedDistances, distThreshold);     

    if dataGood 
        mColor = 'g';
    else
        mColor = 'r';
    end
                 
    [h_comp, h_axs] = drawCube(hAx, tp);
    plot3(tp(1), tp(2), tp(3), 'marker', 'o', 'color', mColor, 'markerfacecolor', mColor)
    
    set(hAx, 'XLim', axLims, 'YLim', axLims, 'ZLim', axLims);                 
    drawnow
    
end
