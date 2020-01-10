function [coeffs, expectedDistances, markerPairings, TCM_LED_IDs] = ...
    doCalibrationProcedure(pad_tipID, pad_IDs, pointer_IDs, desiredPrecision, distTolerance)
% function [coeffs, expectedDistances, markerPairings, TCM_LED_IDs] = ...
% doCalibrationProcedure(pad_tipID, pad_IDs, pointer_IDs, desiredPrecision, distTolerance)
%
% Obtain coefficients that relate tracker markers on a pointer device to
% the device's tip. These can then be supplied to the function tipPosition
% to compute tip position from these marker's positions. Calibration
% requires a pointer with three markers and a calibration pad with four
% markers (one is used to get the pointer tip position, i.e., the pointer
% tip has to be moved onto it, the others are used to infer that marker's
% position once it is occluded by the pointer tip).
% Text displayed in the MATLAB prompt will lead the user through the
% calibration process. Note that there's a setting to display debug
% information at the outset of the function.
%
% To use tipPosition with the outputs of the current function, pass this
% function's outputs to the input arguments of the same name.
%
%
% __Input__
%
% pad_tipID     Two-element row vector. First element is the TCM ID of the
%               marker on the calibration pad that marks the position
%               where the pointer tip will later be placed, second element
%               is the LED ID.
%
% pad_IDs       3-by-2 matrix. TCM IDs (first column) and LED IDs (second
%               column) of the three other markers on the calibration pad.
%
% pointer_IDs   3-by-2 matrix. TCM IDs (first column) and LED IDs (second
%               column) of the three markers on the pointer device.
%
% desiredPrecision  Optional, default 1 mm. Maximum distance of computed
%                   pointer tip position to computed position of pad tip
%                   marker [mm] during final calibration test. If this
%                   value is exceeded, calibration starts over. Can be left
%                   empty [] to use default.
%
% distTolerance     Optional, default 0.25 mm. Tolerance for
%                   markerDistanceCheck, which is used multiple times
%                   during calibration to ensure that the distances between
%                   markers mounted in fixed positions on the same rigid
%                   body (pointer or calibration pad) are stable, to pre-
%                   clude mislocalizations. If the marker distances are
%                   within +/- this value, then the checks are considered
%                   successful.
%
% __Output__
%
% The output arguments are identical to the input arguments of tipPosition.
% See that function for documentation.
%
% See also TIPPOSITION, MARKERDISTANCECHECK.


showDebugInfo = 0; % enable debug info to be displayed during calibration

nStepsForMarkerDistance = 100; % number of good data steps based on which
                               % marker distances are computed later.
                               
dispInterval = 1; % time interval [s] in which status text is printed to prompt
                  % during loops. Note that showDebugInfo overrides this if
                  % active so that debug info is updated frequently.
                  

if nargin < 4 || isempty(desiredPrecision)
    desiredPrecision = 1;
end
if nargin < 5 || isempty(distTolerance)
    distTolerance = 0.25; 
end


calibrationSuccessful = 0;
while ~calibrationSuccessful
    
    pause(0.3)
    
    %%%% Wait for pad markers to be visible to trackers, proceed on keypress
    
    curText = ...
        ['\n-- Calibration --\n\n', ...
        'Place the calibration pad such that all its markers\n',...
        'are in sight of the trackers. Then press any key.\n'];
    showTextWaitForKey(curText);
    waitForVisiblePad(pad_tipID, pad_IDs);          
    fprintf('\n');
    
    %%%% Calibrate the calibration pad itself
    
    strCalibrating = 'Calibrating the pad.';
    disp(strCalibrating);
        
    tryForNGoodDataSteps = 100;
    waitForNDistanceOKSteps = 20;
    done = 0;
    nTotalIterations = 0;
    goodDataCheck(VzGetDat, [pad_IDs; pad_tipID]); % initialize for buffer update            
    firstIteration = 1;
    while ~done                               
                        
        % Get distances between all pad markers
        [fullPad_ds, fullPad_mps] = ...
            getMarkerDistances(nStepsForMarkerDistance, [pad_IDs; pad_tipID]);                
        
        % Wait till distances have been stable for 20 CONSECUTIVE steps; if
        % that does not happen within 100 steps of good data steps,
        % reassess marker distances. This serves as a double check that the
        % data is ok for calibration.    
        nGoodDataSteps = 0;
        nDistanceOKSteps = 0;
        accumulatedGoodFrames = [];
        while nGoodDataSteps <= tryForNGoodDataSteps                        
            
            nTotalIterations = nTotalIterations + 1;
            
            data = VzGetDat;
            
            % if data good check distances and increase good data counter
            if goodDataCheck(data, [pad_IDs; pad_tipID])
                
                nGoodDataSteps = nGoodDataSteps + 1;
                
                % check distances and if ok increment counter
                if markerDistanceCheck(data, fullPad_mps, fullPad_ds, distTolerance)
                    nDistanceOKSteps = nDistanceOKSteps + 1;
                    accumulatedGoodFrames(:,:,nDistanceOKSteps) = data;
                else
                    nDistanceOKSteps = 0; % reset if distances not ok
                end
                
                if nDistanceOKSteps == waitForNDistanceOKSteps
                    done = 1;
                    break;
                end
                
            end                                    
            
            % Debug info string
            if showDebugInfo
                debugStr = ...
                    ['\n# Good data: ', num2str(nGoodDataSteps), ...
                    ' / ', num2str(tryForNGoodDataSteps), ...
                    '\n# Dist ok (pad): ', num2str(nDistanceOKSteps), ...
                    ' / ', num2str(nDistanceOKSteps), ...
                    '\n# Total iterations: ', num2str(nTotalIterations)];
            else
                debugStr = '';
            end                       
            % disp after every dispInterval seconds, on first iter, or if
            % debug info is desired (in this case update on each iteration)
            if firstIteration || showDebugInfo || toc(clockTic) >= dispInterval
                fprintf([strCalibrating, debugStr, '\n']);                
                firstIteration = 0;
                clockTic = tic;
            end
                        
        end
        
    end
    
    % Calibrate the calibration pad itself, i.e. compute coefficients that 
    % allow inferring the position of the pad tip marker as a linear
    % combination of the vectors between the other pad markers.
    % Use the mean of the coefficients computed from the multiple frames of
    % good data collected above.
    pad_coeffs = [];
    for curDataNum = 1:size(accumulatedGoodFrames,3)
        data = accumulatedGoodFrames(:,:,curDataNum);    
        % Calibrate the pad with the most recent good data
        pad_data = filterTrackerData(data, pad_IDs, true);
        pad_tip_data = filterTrackerData(data, pad_tipID, true);
        pad_coeffs(curDataNum,:) = calibratePointer(pad_data, pad_tip_data);                                
    end
    pad_coeffs = mean(pad_coeffs);
            
    % From the distances between pad markers acquired above, extract all
    % those that do not include the pad tip marker.
    pad_markers_rows = ismember(fullPad_mps(:,1:2), pad_IDs, 'rows') & ...
        ismember(fullPad_mps(:,3:4), pad_IDs, 'rows');
    pad_mps = fullPad_mps(pad_markers_rows,:); % pad marker pairings, without tip
    pad_ds = fullPad_ds(pad_markers_rows,:); % pad marker distances, without tip            
    
    
    %%%% Calibrate the pointer
    
    curText = ['\nMove the pointer tip onto the tip marker of the \n' ...
                   'calibration pad. Make sure markers on the pointer \n' ...
                   'are visible to the trackers.'];
    showTextWaitForKey([curText, 'Then press any key,\nnot moving the pointer off the pad.']);
    pause(0.3)
    fprintf('\n')
    
    strCalibrating = 'Calibrating the pointer (keep it on the pad!).';
    disp(strCalibrating);
    
    tryForNGoodDataSteps = 100;
    waitForNDistanceOKSteps = 20;
    done = 0;
    nTotalIterations = 0;
    goodDataCheck(VzGetDat, [pad_IDs; pointer_IDs]); % initialize for buffer update
    firstIteration = 1;         
    while ~done
        
        % Get pointer marker distances
        [pointer_ds, pointer_mps] = ...
            getMarkerDistances(nStepsForMarkerDistance, pointer_IDs);
        
        % Wait till distances have been stable for 20 CONSECUTIVE steps; if
        % that does not happen within 100 steps of good data steps,
        % reassess marker distances. This serves as a double check that the
        % data is ok for calibration.
        nGoodDataSteps = 0;
        nDistanceOKSteps = 0;
        accumulatedGoodFrames = [];
        while nGoodDataSteps <= tryForNGoodDataSteps
            
            nTotalIterations = nTotalIterations + 1;
            
            data = VzGetDat;
            
            % if data good and pad distances are ok, check pointer distances
            % and increase good data counter
            if goodDataCheck(data, [pad_IDs; pointer_IDs]) && ...
                    markerDistanceCheck(data, pad_mps, pad_ds, distTolerance)
                
                nGoodDataSteps = nGoodDataSteps + 1;
                
                % check distances and if ok increment counter
                if markerDistanceCheck(data, pointer_mps, pointer_ds, distTolerance)
                    nDistanceOKSteps = nDistanceOKSteps + 1;
                    accumulatedGoodFrames(:,:,nDistanceOKSteps) = data;
                else
                    nDistanceOKSteps = 0; % reset if distances not ok
                end
                
                if nDistanceOKSteps == waitForNDistanceOKSteps
                    done = 1;
                    break;
                end
                
            end                        
            
            % Debug info string  
            if showDebugInfo
                debugStr = ...
                    ['\n# Good data: ', num2str(nGoodDataSteps), ...
                    ' / ', num2str(tryForNGoodDataSteps), ...
                    '\n# Dist ok (pointer): ', num2str(nDistanceOKSteps), ...
                    ' / ', num2str(nDistanceOKSteps), ...
                    '\n# Total iterations: ', num2str(nTotalIterations)];
            else
                debugStr = '';
            end
            % disp after every dispInterval seconds, on first iter, or if
            % debug info is desired (in this case update on each iteration)
            if firstIteration || showDebugInfo || toc(clockTic) >= dispInterval
                fprintf([strCalibrating, debugStr, '\n']);
                firstIteration = 0;
                clockTic = tic;
            end                        
            
        end
        
    end
    
    % Calibrate the pointer (i.e., use position of pad tip marker computed
    % from the other pad markers as pointer tip position to compute
    % coefficients for pointer) as mean of the coefficients computed
    % from all the good data frames acquired in the above loop.    
    pointer_coeffs = [];
    for curDataNum = 1:size(accumulatedGoodFrames,3)        
        data = accumulatedGoodFrames(:,:,curDataNum);        
        pad_data = filterTrackerData(data, pad_IDs, true);
        pad_tipPos = posFrom3Points(pad_data(1,:), pad_data(2,:), pad_data(3,:), pad_coeffs);
        pointer_data = filterTrackerData(data, pointer_IDs, true);
        pointer_coeffs(curDataNum,:) = calibratePointer(pointer_data, pad_tipPos);        
    end    
    pointer_coeffs = mean(pointer_coeffs);        
    
    
    %%%% Test calibration by comparing position of pointer tip and tip marker
       
    showTextWaitForKey(['\nDone. To test the calibration, remove the pointer\n',...
                        'tip from the pad, then move it back onto the pad tip\n',... 
                        'marker. Then press any key, keeping the pointer on\n', ...
                        'the pad.']);    
    
    % In case pad is not visible anymore, prompt user to move it.
    while ~zeroDataCheck(VzGetDat, pad_IDs)        
        showTextWaitForKey(...
                       ['\nThe trackers do not see some of the required pad\n', ...
                       'pad markers.  Press any key and then move the pad\n', ...
                       'until they are detected.']);    
        waitForVisiblePad([], pad_IDs, showTextAndReturn)
        if zeroDataCheck(VzGetDat, pad_IDs)        
            showTextWaitForKey(...
                       ['Move the pointer onto the tip marker of the pad.\n', ...
                        'Then press any key and keep the tip on the pad.']);            
            break
        end
    end
       
    fprintf('\n');
    pause(0.3);            
    
    % See whether pointer is localized to the computed position of the pad
    % tip marker. If this fails on two tries, start over.
    calibrationSuccessful = 0;
    firstTestFailed = 0;
    tic
    firstIteration = 1;
    while 1
        
        if firstIteration || toc(clockTic) >= dispInterval
            disp('Testing Calibration (keep pointer on pad).');            
            firstIteration = 0;
            clockTic = tic;
        end                                           
            
        % Compute pad tip pos and pointer pos
        [pad_tipPos,~,gd_tip,~] = ...
            tipPosition(pad_IDs, pad_coeffs, [], pad_mps, pad_ds, distTolerance);
        [pointerPos,~,gd_poi,~] = ...
            tipPosition(pointer_IDs, pointer_coeffs, [], pointer_mps, pointer_ds, distTolerance);
        
        % If good data, compare positions, with tolerance
        if gd_tip && gd_poi
            if dist3d(pad_tipPos,pointerPos) < desiredPrecision
                calibrationSuccessful = 1;
                break;
            end
        end
        
        % If unsuccessful, after a time do one additional try; start over
        % if that one fails as well. Else proceed.
        if toc > 3
            if firstTestFailed
            showTextWaitForKey('\nCalibration failed.\nPress any key to start over.');                    
                break
            end            
            showTextWaitForKey(['\nAre you sure the trackers can see all markers?\n', ...
                'Check that, place pointer tip on tip marker again.\n', ...
                'Then press any key.\n    ']);
            pause(0.3);
            firstTestFailed = 1;
            tic
        end
        
    end
    
end

% Assign to output arguments
coeffs = pointer_coeffs;
expectedDistances = pointer_ds;
markerPairings = pointer_mps;
TCM_LED_IDs = pointer_IDs;

showTextWaitForKey('\nCalibration successful.\nPress any key.');
pause(0.3);


end



function showTextWaitForKey(text)
% display a text panel and wait for keypress (wait 0.5 secs after keypress)
    fprintf([text, '\n']);
    KbWait;
    WaitSecs(0.3);
end


function waitForVisiblePad(pad_tipID, pad_IDs)
% Accessory function to call when waiting for the calibration pad to be
% visible (i.e., no zero data on calib pad markers).
dispInterval = 1;
firstIter = 1;
clockTic = tic;
while 1
    if zeroDataCheck(VzGetDat, [pad_tipID; pad_IDs])
        if toc(clockTic) > dispInterval || firstIter
            disp('Pad visible. Press any key to proceed.');
            clockTic = tic;
        end
        if KbCheck
            KbReleaseWait;
            if zeroDataCheck(VzGetDat, [pad_tipID; pad_IDs])
                break
            end
        end
    else        
        if toc(clockTic) > dispInterval || firstIter
            disp('Looking for pad (move it around!).');
            clockTic = tic;
        end
    end
    firstIter = 0;
end
end






