function [noZeroData, zeroRows] = zeroDataCheck(trackerData, TCM_LED_IDs)
% function [noZeroData] = zeroDataCheck(trackerData, TCM_LED_IDs)
%
% Check whether marker coordinate data obtained from VzGetDat is free of
% zero rows. This may be caused by marker occlusion, empty batteries on
% wireless markers, and similar things. (Notes: Use batteryCheck.m to
% explicitly check for depleted batteries.)
%
% __Output__
%
% noZeroData    true if there is no zero data, false if for at least
%               one of the markers specified in TCM_LED_IDs all coordinates
%               are exactly zero.
%
% zeroRows      Row indices of rows in trackerData where position data is
%               zero. Note that this considers only those rows that contain
%               the markers specified in TCM_LED_IDs (e.g., if only two
%               markers are specified in TCM_LED_IDs, then zeroRows will
%               have at most two elements, regardless of whether other rows
%               in trackerData contain zero position data).
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
% See also BATTERYCHECK

% by default check all markers, else use only desired ones
if nargin > 1    
    useRows = markerIdsToRows(trackerData, TCM_LED_IDs);    
else
    useRows = 1:size(trackerData,1);
end

useData = trackerData(useRows, 3:5);

% Check for zero data
noZeroData = ~any(all(useData'==0));

% Get zero row indices in tracker Data (only consider rows specified in
% useRows)
if nargout > 1
    zeroRows = find(all(trackerData(:,3:5)'==0));
    zeroRows = intersect(zeroRows, useRows);
end

end