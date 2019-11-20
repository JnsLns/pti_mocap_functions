function [dataGood] = goodDataCheck(trackerData, TCM_LED_IDs)
% function [dataGood] = goodDataCheck(trackerData, TCM_LED_IDs)
%
% Checks that data from motion trackers obtained through VzGetDat are
% (1) free of zero data and (2) that the tracker buffer has been fully
% updated since the previous call of this function. (goodDataCheck simply
% wraps zeroDataCheck and bufferUpdateCheck.)
%
% __Output__
%
% dataGood      true if no zero data and buffer has been fully updated
%               since last call, false otherwise.
%
% __Input__
%
% trackerData   Marker position matrix obtained from motion trackers
%               via vzGetDat.
%
% TCM_LED_IDs  optional, default is to check all markers in trackerData. 
%              Else, n-by-2 matrix, where n is the number of markers,
%              column 1 holds TCMIDs for the markers of interest, and
%              column 2 holds their LEDIDs. Only those markers are
%              checked.
%
% See also ZERODATACHECK, BUFFERUPDATECHECK


% by default check all markers, else use only desired ones
if nargin > 1
    trackerData = ...
        trackerData(markerIdsToRows(trackerData, TCM_LED_IDs), :);
end

dataGood = bufferUpdateCheck(trackerData) & zeroDataCheck(trackerData);

end