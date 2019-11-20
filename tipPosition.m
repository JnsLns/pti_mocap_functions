function [tipPos, trackerTime, dataGood, vzData] = tipPosition(TCM_LED_IDs, coeffs, velocityThreshold, markerPairings, expectedDistances, distThreshold)
% function [tipPos, trackerTime, dataGood, vzData] = tipPosition(TCM_LED_IDs, coeffs, velocityThreshold, markerPairings, expectedDistances, distThreshold)
%
% Computes tip location of a pointer equipped with three tracker markers
% based on data obtained via VzGetDat. The computation relies on 
% coefficients obtained during pointer calibration using the function
% calibratePointer. If this function is called multiple times and there are
% issues with the data obtained from VzGetDat in a call (zero data,
% non-updated buffer, optionally unexpected marker distances and/or jumps),
% the tip position from the last function call without such issues is
% returned.
%
% __Input__
%
% TCM_LED_IDs   3-by-2 matrix, each row holding the TCMID and LEDID of one
%               marker mounted on the pointer device. Note that the order
%               of markers in the rows of this matrix must be identical to
%               the one used when calling calibratePointer.
%
% coeffs        Three-element vector holding coefficients that relate the
%               markers on the pointer to its tip; these can be obtained
%               using the function pointerCalibration.
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
%
% markerPairings    3-by-2 matrix. Each row defines one marker pairing for
%                   which it will be checked whether the marker distance is
%                   within some threshold of the expected distance.
%                   This argument should be obtained from the function 
%                   getMarkerDistances (output argument markerPairings).
%
% expectedDistances Three-element vector holding expected distances for the
%                   marker pairings defined in markerPairings. This
%                   argument should be obtained from getMarkerDistances
%                   (output argument distances).
%
% distThreshold     Scalar, threshold for difference between current marker
%                   distances and expectedDistances. If any difference
%                   exceeds this threshold, data is considered bad.
%
%
% __Output__
%
% tipPos            Three-element row vector giving x,y,z coordinates of
%                   the pointer tip. In case of bad data, the tip position
%                   is based on the last encountered good data (from a pre-
%                   vious call of this function).
%
% trackerTime       Time stamp of the pointer marker that was queried most
%                   recently (i.e., the marker in TCM_LED_IDs that occurs
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
%                   pointer).
%
% See also MARKERJUMPCHECK, GETMARKERDISTANCES, CALIBRATEPOINTER

debug_output = false; % enable to get console output about data quality

persistent lastGoodData

allData = VzGetDat;

% Data rows holding the three pointer markers
data = allData(markerIdsToRows(allData, TCM_LED_IDs),:);
trackerTime = data(end, 6);

% Check zero data and buffer update
zd_ok = zeroDataCheck(data);
bu_ok = bufferUpdateCheck(data);

% marker jump check (optional)
if nargin >= 3 && ~isempty(velocityThreshold)
    mj_ok = markerJumpCheck(data, [], velocityThreshold);
else
    mj_ok = true;
end

% marker distance check, optional
if nargin >=6
    md_ok = markerDistanceCheck(allData, markerPairings, ...
                                expectedDistances, distThreshold);
else
    md_ok = true;
end

% Compute tip position
% (if bad data, instead return outcome of last function call where data
% was good)
if zd_ok && bu_ok && mj_ok && md_ok
        
    dataGood = true;
    
    % compute tip position from p1, p2, and p3
    p1 = data(1, 3:5); p2 = data(2, 3:5); p3 = data(3, 3:5);
    tipPos = posFrom3Points(p1, p2, p3, coeffs);
            
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

if nargout >= 4
    vzData = allData;
end

end




