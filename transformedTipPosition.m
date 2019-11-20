function [tipPos, trackerTime, dataGood, vzData] = ...
    transformedTipPosition(TCM_LED_IDs_cf, TCM_LED_IDs_p, coeffs, ...
    velocityThreshold, markerPairings_p, expectedDistances_p, distThreshold_p)
% function [tipPos, trackerTime, dataGood, vzData] = ...
%       transformedTipPosition(TCM_LED_IDs_cf, TCM_LED_IDs_p, coeffs, ...
%       velocityThreshold, markerPairings_p, expectedDistances_p, ...
%       distThreshold_p)
%
% Like tipPosition, this function computes tip location of a pointer
% equipped with three tracker markers, based on data obtained via VzGetDat.
% In addition, however, this function transforms the computed tipPosition
% into a new coordinate frame that is itself defined by three markers, one
% located at the frame's origin, one on the x-axis, and one in the
% positive x-y-plane. These markers' positions are assessed each time the
% function is called, so that the coordinate frame may move with the
% markers when the function is called in a loop. This can be used, for
% instance, to obtain tip position data in a coordinate frame relative to
% a screen on which three markers are mounted.
%
% The computation of the tip position relies on coefficients obtained
% during pointer calibration using the function calibratePointer.
%
% If the function is called multiple times in a loop and there are issues
% with the data obtained from VzGetDat in one call (zero data, non-updated
% buffer, optionally unexpected marker distances and/or jumps), the tip
% position from the last function call without such issues is returned.
%
% __Input__
%
% TCM_LED_IDs_cf    3-by-2 matrix, each row holding the TCMID and LEDID of
%                   one marker. The first marker will be the origin of the
%                   new coordinate frame, the second one lies on the
%                   positive x-axis, and the third one lies in the
%                   positive x-y-plane. The y-axis increases along the
%                   perpendicular from the x-axis to the second marker.
%                   The z-axis is defined as in a usual right-handed
%                   coordinate system.
%
% TCM_LED_IDs_p     3-by-2 matrix, each row holding the TCMID and LEDID of
%                   one marker mounted on the pointer device. Note that the
%                   order of markers in this matrices row must be identical
%                   to that used when calling calibratePointer.
%
% coeffs            Three-element vector holding coefficients that relate
%                   the markers on the pointer to its tip; these can be
%                   obtained using the function pointerCalibration.
%
% velocityThreshold Optional. Threshold for marker jump checks. Omit or
%                   pass empty array [] in order to omit marker jump
%                   checks. Otherwise, this is a scalar giving marker
%                   movement velocity beyond which marker movement will be
%                   considered erroneous jumps and thus bad data.
%
%
% Note: The next three arguments are optional. If all of them are passed,
% distances between pointer markers will be computed and compared to
% expected values. Data will be considered bad if deviation is large.
% IMPORTANT: This includes only the pointer markers, not those
% defining the coordinate frame (as distance of the pointer to those will
% change. The distance check is not implemented for the coordinate frame
% markers since it is assumed that those are thoroughly fixed on a rigid 
% body and are less likely to shift position relative to each other
% during a recording session).
%
% markerPairings_p  3-by-2 matrix. Each row defines one marker pairing for
%                   which it will be checked whether the marker distance is
%                   within some threshold of the expected distance.
%                   This argument should be obtained from the function 
%                   getMarkerDistances (output argument markerPairings_p).
%
% expectedDistances_p Three-element vector holding expected distances for the
%                   marker pairings defined in markerPairings_p. This
%                   argument should be obtained from getMarkerDistances
%                   (output argument distances).
%
% distThreshold_p   Scalar, threshold for difference between current marker
%                   distances and expectedDistances_p. If any difference
%                   exceeds this threshold, data is considered bad.
%
% __Output__
%
% tipPos            Three-element row vector giving x,y,z coordinates of
%                   the pointer tip. In case of bad data, the tip position
%                   is based on the last encountered good data (from a pre-
%                   vious call of this function).
%
% trackerTime       Time stamp of the pointer marker that was queried most
%                   recently (i.e., the marker in TCM_LED_IDs_p that occurs
%                   last in the data from VzGetDat). In the case of bad
%                   data, the time stamp of the last good data is returned.
%
% dataGood          true if returned tipPos and trackerTime were computed
%                   from the data obtained by VzGetDat in the current
%                   function call, false if the returned values are from
%                   a previous function call (due to current data being
%                   bad).
%
% vzData            full data matrix obtained from vzGetDat in the function
%                   call, containing all markers (not only those of the
%                   pointer), with position data transformed to the new
%                   coordinate frame. 
%
% See also TIPPOSITION, CHANGEOFBASIS, MARKERJUMPCHECK, GETMARKERDISTANCES,
% CALIBRATEPOINTER.


debug_output = false; % enable to get console output about data quality


persistent lastGoodData

allData = VzGetDat;

% Data rows holding the three pointer markers and the three coordinate
% frame markers (this will be used to test for zero data etc.)
data = allData(markerIdsToRows(allData, [TCM_LED_IDs_p; TCM_LED_IDs_cf]),:);

% Check zero data and buffer update
zd_ok = zeroDataCheck(data);
bu_ok = bufferUpdateCheck(data);

% marker jump check (optional)
if nargin >= 4 && ~isempty(velocityThreshold)
    mj_ok = markerJumpCheck(data, [], velocityThreshold);
else
    mj_ok = true;
end

% marker distance check, optional (only for pointer markers)
if nargin >=7
    md_ok = markerDistanceCheck(allData, markerPairings_p, ...
                                expectedDistances_p, distThreshold_p);
else
    md_ok = true;
end


% Data rows holding pointer markers
p_data = data(1:3,:);
% Data rows holding coordinate frame markers (origin, x, y))
cf_data = data(4:6,:);
% Get data time stamp as pointer marker sampled last
trackerTime = p_data(end, 6);


% Compute tip position & transform (if bad data, instead return outcome of
% last function call where data was good)

if zd_ok && bu_ok && mj_ok && md_ok
    
    dataGood = true;
    
    % compute tip position from pointer markers
    tipPos = posFrom3Points(p_data(1, 3:5), ...
                            p_data(2, 3:5), ...
                            p_data(3, 3:5), ...
                            coeffs);
    
    % Transform to marker-based coordinate frame
    tipPos = changeOfBasis(tipPos', ...
                           cf_data(1, 3:5)', ...
                           cf_data(2, 3:5)', ...
                           cf_data(3, 3:5)')';       
    
    lastGoodData = [tipPos, trackerTime];
    
else
    
    dataGood = false;
    
    if ~isempty(lastGoodData)
        tipPos = lastGoodData(1:3);
        trackerTime = lastGoodData(4);
    else
        tipPos = [9999, 9999, 9999];
    end
    
end


% Debug output
if debug_output    
    disp('#### In function tipPosition() ###');
    disp('Data from VzGetDat (pointer markers): ');
    disp(data);    
    disp('Data quality (1 = good): ');
    disp(['zero data:       ', num2str(zd_ok)]);    
    disp(['buffer update :  ', num2str(bu_ok)]);    
    disp(['marker jump:     ', num2str(mj_ok)]);       
    disp(['marker distance: ', num2str(md_ok)]);    
    disp('---');
    if dataGood
        disp(['data GOOD. New tip position: ', num2str(tipPos)])
    else
        disp(['data BAD. last good tip position: ', num2str(tipPos)])
    end
    disp('##################################');
end

% in case vzData output is desired
if nargout >= 4

    vzData = allData;
    
    % Transform all data according to new reference frame     
    for r = 1:size(vzData,1)
        vzData(r,3:5) = changeOfBasis(allData(r,3:5)', ...
                           cf_data(1,3:5)', ...
                           cf_data(2,3:5)', ...
                           cf_data(3,3:5)')';   
    end
        
end


end




