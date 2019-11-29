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
% Message boxes will lead the user through the calibration process.
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


if nargin < 4 || isempty(desiredPrecision)
    desiredPrecision = 1;
end
if nargin < 5
    distTolerance = 0.25; 
end


calibrationSuccessful = 0;
while ~calibrationSuccessful
    
    %%%% Make sure pad markers are visible
    
    waitfor(msgbox(['Place the calibration pad such that all markers on it are ' ...
        'visible to the trackers. Then click OK.'], 'Calibration'));
    
    while ~zeroDataCheck(VzGetDat, [pad_tipID; pad_IDs])
        waitfor(msgbox(['Not all pad markers visible. Reposition calibration pad ' ...
            'and press OK.'], 'Calibration', true));
        pause(0.5);
    end
    
    pause(0.5);
    
    
    
    %%%% Calibrate the calibration pad itself
    
    tryForNGoodDataSteps = 100;
    waitForNDistanceOKSteps = 20;
    done = 0;
    goodDataCheck(VzGetDat, [pad_IDs; pad_tipID]); % initialize for buffer update
    while ~done
        
        % Get distances between all pad markers
        [fullPad_ds, fullPad_mps] = getMarkerDistances(10, [pad_IDs; pad_tipID]);
        
        % Wait till distances have been stable for 20 CONSECUTIVE steps; if
        % that does not happen within 100 steps of good data steps,
        % reassess marker distances. This serves as a double check that the
        % data is ok for calibration.
        nGoodDataSteps = 0;
        nDistanceOKSteps = 0;
        while nGoodDataSteps <= tryForNGoodDataSteps
            
            data = VzGetDat;
            
            % if data good check distances and increase good data counter
            if goodDataCheck(data, [pad_IDs; pad_tipID])
                
                nGoodDataSteps = nGoodDataSteps + 1;
                
                % check distances and if ok increment counter
                if markerDistanceCheck(data, fullPad_mps, fullPad_ds, distTolerance)
                    nDistanceOKSteps = nDistanceOKSteps + 1;
                else
                    nDistanceOKSteps = 0; % reset if distances not ok
                end
                
                if nDistanceOKSteps == waitForNDistanceOKSteps
                    done = 1;
                    break;
                end
                
            end
            
        end
        
    end
    
    % Calibrate the pad with the most recent good data
    pad_data = filterTrackerData(data, pad_IDs, true);
    pad_tip_data = filterTrackerData(data, pad_tipID, true);
    pad_coeffs = calibratePointer(pad_data, pad_tip_data);
    
    % From the distances of pad markers above (which according to the checks
    % are apparently fine), extract those between all but the pad "tip" marker.
    pad_markers_rows = ismember(fullPad_mps(:,1:2), pad_IDs, 'rows') & ...
        ismember(fullPad_mps(:,3:4), pad_IDs, 'rows');
    pad_mps = fullPad_mps(pad_markers_rows,:); % pad marker pairings, without tip
    pad_ds = fullPad_ds(pad_markers_rows,:); % pad marker distances, without tip
    
    
    
    %%%% Calibrate the pointer
    
    waitfor(msgbox(['Move the tip of the pointer onto the tip marker of ' ...
        'the calibration pad. Make sure the markers on the pointer are ' ...
        'visible to the trackers. Then click OK. '], 'Calibration'));
    
    tryForNGoodDataSteps = 100;
    waitForNDistanceOKSteps = 20;
    done = 0;
    goodDataCheck(VzGetDat, [pad_IDs; pointer_IDs]); % initialize for buffer update
    while ~done
        
        % Get pointer marker distances
        [pointer_ds, pointer_mps] = getMarkerDistances(10, pointer_IDs);
        
        % Wait till distances have been stable for 20 CONSECUTIVE steps; if
        % that does not happen within 100 steps of good data steps,
        % reassess marker distances. This serves as a double check that the
        % data is ok for calibration.
        nGoodDataSteps = 0;
        nDistanceOKSteps = 0;
        while nGoodDataSteps <= tryForNGoodDataSteps
            
            data = VzGetDat;
            
            % if data good and pad distances are ok, check pointer distances
            % and increase good data counter
            if goodDataCheck(data, [pad_IDs; pointer_IDs]) && ...
                    markerDistanceCheck(data, pad_mps, pad_ds, distTolerance)
                
                nGoodDataSteps = nGoodDataSteps + 1;
                
                % check distances and if ok increment counter
                if markerDistanceCheck(data, pointer_mps, pointer_ds, distTolerance)
                    nDistanceOKSteps = nDistanceOKSteps + 1;
                else
                    nDistanceOKSteps = 0; % reset if distances not ok
                end
                
                if nDistanceOKSteps == waitForNDistanceOKSteps
                    done = 1;
                    break;
                end
                
            end
            
        end
        
    end
    
    % On the basis of the most recent good data:
    % Calibrate the pointer with the most recent good data (use position of
    % pad tip marker computed from the other pad markers as pointer tip
    % position to compute coeffIcients for pointer)
    pad_data = filterTrackerData(data, pad_IDs, true);
    pad_tipPos = posFrom3Points(pad_data(1,:), pad_data(2,:), pad_data(3,:), pad_coeffs);
    pointer_data = filterTrackerData(data, pointer_IDs, true);
    pointer_coeffs = calibratePointer(pointer_data, pad_tipPos);
    
    
    
    %%%% Test calibration by comparing position of pointer tip and tip marker
       
    waitfor(msgbox(['Remove the pointer tip from the pad and move the pad ', ...
        'around a little. Then move the pointer tip back onto ', ...
        'the pad tip marker and click OK.'], 'Calibration'));
    
    while ~zeroDataCheck(VzGetDat, [pad_IDs])
        waitfor(msgbox(['Not all pad markers visible. Reposition calibration pad, ' ...
            'move pointer on the tip marker and press OK.'], 'Calibration', true));
        pause(0.5);
    end
    
    calibrationSuccessful = 0;
    firstTestFailed = 0;
    tic
    while 1
        
        [pad_tipPos,~,gd_tip,~] = ...
            tipPosition(pad_IDs, pad_coeffs, [], pad_mps, pad_ds, distTolerance);
        [pointerPos,~,gd_poi,~] = ...
            tipPosition(pointer_IDs, pointer_coeffs, [], pointer_mps, pointer_ds, distTolerance);
        
        if gd_tip && gd_poi
            if dist3d(pad_tipPos,pointerPos) < desiredPrecision
                calibrationSuccessful = 1;
                break;
            end
        end
        
        if toc > 3
            if firstTestFailed
            waitfor(msgbox('Calibration failed. Click OK to start over.', ...
                'Calibration'));    
                break
            end            
            waitfor(msgbox(['Are you sure the trackers can see all markers ? ', ...
                'Check that, place pointer tip on tip marker again and press ', ...
                'OK.'], 'Calibration'));
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

waitfor(msgbox('Calibration successful.', 'Calibration'));









