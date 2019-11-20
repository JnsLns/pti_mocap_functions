
% settings

pad_tipID = [3,1];
pad_IDs = [3,2; 3,3; 3,4];
pointer_IDs = [3,6; 3,7; 3,8];
coordinate_IDs = [3, 11; 3,10; 3,12]; % origin, pos x axis, x-y-plane


% for tip position
velThresh = 2000;
distThreshold = 5;

axLims = [-1500 1500];


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
    
    tmp = VzGetDat;
    if detectDuplicateRows(tmp)
        
        delete(hAx.Children)
        
        [tp, ~, dataGood, markerData] = transformedTipPosition(coordinate_IDs, ...
            TCM_LED_IDs, coeffs, velThresh, markerPairings, ...
            expectedDistances, distThreshold);
        
        if dataGood
            mColor = 'g';
        else
            mColor = 'r';
        end
        
        % Plot tip position
        [h_comp, h_axs] = drawCube(hAx, tp);
        plot3(hAx, tp(1), tp(2), tp(3), 'marker', 'o', 'color', mColor, ...
            'markerfacecolor', mColor, 'displayname', 'Tip position')
        text( tp(1), tp(2), tp(3), ...
            [num2str(tp(1)), '\n', num2str(tp(2)), '\n', num2str(tp(3)) ], ...
            'backgroundcolor', 'w');
        
        hold on
        
        % Plot & label coordinate frame markers
        cfMarkers = filterTrackerData(markerData, coordinate_IDs, 1);
        plot3(hAx, cfMarkers(:,1), cfMarkers(:,2), cfMarkers(:,3), ...
            'o', 'color', 'b', 'displayname', 'Coordinate frame markers');
        text( cfMarkers(1,1), cfMarkers(1,2), cfMarkers(1,3), ...
            ['   ID ' num2str(coordinate_IDs(1,:)) '  (origin)']);
        text( cfMarkers(2,1), cfMarkers(2,2), cfMarkers(2,3), ...
            ['   ID ' num2str(coordinate_IDs(2,:)) '  (x-axis)']);
        text( cfMarkers(3,1), cfMarkers(3,2), cfMarkers(3,3), ...
            ['   ID ' num2str(coordinate_IDs(3,:)) '  (x-y-plane)']);
        
        % Plot pointer markers
        ptrMarkers = filterTrackerData(markerData, pointer_IDs, 1);
        plot3( ptrMarkers(:,1), ptrMarkers(:,2), ptrMarkers(:,3), ...
            'o', 'color', 'g', 'displayname', 'Pointer markers');
        ptrMarkers_com = sum(ptrMarkers)/size(ptrMarkers,1);
        text( ptrMarkers_com(1), ptrMarkers_com(2), ptrMarkers_com(3), ...
            '   Ptr.');
        
        % Plot calibration pad markers
        calibMarkers = filterTrackerData(markerData, [pad_tipID; pad_IDs], 1);
        plot3( calibMarkers(:,1), calibMarkers(:,2), calibMarkers(:,3), ...
            'o', 'color', 'm', 'displayname', 'Calibration pad markers');
        calibMarkers_com = sum(calibMarkers)/size(calibMarkers,1);
        text( calibMarkers_com(1), calibMarkers_com(2), calibMarkers_com(3), ...
            '   Calib.');
        
        % Plot other markers (if any)
        doneRows = markerIdsToRows(markerData, ...
            [pad_tipID; pad_IDs; pointer_IDs; coordinate_IDs]);
        if size(markerData, 1) > numel(doneRows)
            otherMarkers = markerData(~ismember(1:size(markerData,1), doneRows), ...
                3:5);
            plot3(hAx, otherMarkers(:,1), otherMarkers(:,2), otherMarkers(:,3), ...
                'o', 'color', [.7 .7 .7], 'displayname', 'Other');
        end
        
        
        
        set(hAx, 'XLim', axLims, 'YLim', axLims, 'ZLim', axLims);
        xlabel('X'); ylabel('Y'); zlabel('Z')
        
        legend on;
        
        drawnow
        
        
    else
        
        disp('Skipped frame due to duplicate data rows');
        disp(tmp);
    end
    
    
    %disp(tp)
    
end
