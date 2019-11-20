function [coeffs, expectedDistances, markerPairings, TCM_LED_IDs] = ...
    doCalibrationProcedure(pad_tipID, pad_IDs, pointer_IDs)
% function [coeffs, expectedDistances, markerPairings, TCM_LED_IDs] =
% doCalibrationProcedure(pad_tipID, pad_IDs, pointer_IDs)
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
%
% __Output__
%
% The output arguments are identical to the input arguments of tipPosition.
% See that function for documentation.
%
% See also TIPPOSITION.



waitfor(msgbox(['Place the calibration pad such that all markers on it are ' ...
       'visible to the trackers. Then click OK.'], 'Calibration'));

while ~zeroDataCheck(VzGetDat, [pad_tipID; pad_IDs])    
    waitfor(msgbox(['Not all pad markers visible. Reposition calibration pad ' ...
        'and press OK.'], 'Calibration', true));    
    pause(0.5);
end

pause(0.5);



% Calibrate the calibration pad itself

pad_coeffs = calibratePointer(pad_IDs, pad_tipID);
% Get distances between non-tip markers on the pad
[pad_ds, pad_mps] = getMarkerDistances(10, pad_IDs);

waitfor(msgbox(['Move the tip of the pointer onto the tip marker of ' ...
       'the calibration pad. Make sure the markers on the pointer are ' ...
       'visible to the trackers. Then click OK. '], 'Calibration'));
   

   
% Calibrate the pointer 
   
goodDataCheck(VzGetDat, [pad_IDs; pointer_IDs]); % initialize for buffer update

% Obtain data until all relevant markers (pad & pointer) yield good data
dataGood = false;
while ~dataGood
    data = VzGetDat;
    all_gd = goodDataCheck(data, [pad_IDs; pointer_IDs]);
    pad_md = markerDistanceCheck(data, pad_mps, pad_ds, 0.5);
    dataGood = pad_md & all_gd;
end

% Compute position of pad tip marker from the other markers
pad_data = filterTrackerData(data, pad_IDs, true);
pad_tipPos = posFrom3Points(pad_data(1,:), pad_data(2,:), pad_data(3,:), pad_coeffs);

% Use position of pad tip marker as pointer tip position to compute
% coeffcients for pointer
pointerData = filterTrackerData(data, pointer_IDs, true);
coeffs = calibratePointer(pointerData, pad_tipPos);

% Also get distances. 
[expectedDistances, markerPairings] = getMarkerDistances(10, pointer_IDs);

TCM_LED_IDs = pointer_IDs;



waitfor(msgbox('Calibration complete.', 'Calibration'));









