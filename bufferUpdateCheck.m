function [bufferUpdated] = bufferUpdateCheck(trackerData, TCM_LED_IDs)
% function [bufferUpdated] = bufferUpdateCheck(trackerData, TCM_LED_IDs)
%
% Check whether marker position data obtained from VzGetDat differs (for
% all included markers) from the data obtained in the previous call to this
% function. If all data differs from the previous function call, this
% indicates that the tracker-sided hardware buffer has been fully updated. 
%
% Note that this function does not explicitly check for zero position data  
% (e.g., due to marker occlusion) in trackerData before performing the
% buffer update check. Thus, in the first call of this function where zero
% data occurs in a given row, bufferUpdated will be true if all other rows
% have changed as well. Zero position data present over multiple calls will
% trigger bufferUpdated to be zero, even if the other rows have been
% updated. If needed, perform an explicit check for zero data before
% calling this function, using zeroDataCheck.
% 
% __Input__
%
% trackerData       Marker position matrix obtained from motion trackers
%                   via vzGetDat.
%
% TCM_LED_IDs       optional, all markers are checked by default. 
%                   n-by-2 matrix, where n is the number of markers,
%                   column 1 holds TCMIDs for the markers of interest, and
%                   column 2 holds their LEDIDs. Only those markers are
%                   checked.
%
% __Output__
%
% bufferUpdated     false if any positions of the checked markers are
%                   *exactly* the same as in the last call to this
%                   function. (Even position data of seemingly static
%                   markers change somewhat from frame to frame, so the
%                   function will correctly recognize if they have been 
%                   updated.)
%
% __Note__
%
% What makes this function useful is an issue with the tracker-sided buffer
% from which VzGetDat obtains marker positions. This buffer is usually
% updated much less frequently than the iteration frequency of the MATLAB
% loops within which VzGetDat is typically called.
% This can lead to (1) fully identical data being returned in successive
% calls to VzGetDat, when the buffer hasn't been updated since the last
% call – this is spotted by this function; (2) marker data being passed
% in which only some of the markers have been updated, which happens when
% VzGetDat is called while a buffer update is in progress. When this occurs
% while markers are moving, new positions are obtained for some markes and
% old positions for the others. This can be a problem, for instance, when
% computing the position of a rigid body based on multiple markers mounted
% on it. This as well is detected by this function.
%
% See also ZERODATACHECK.



% by default check all markers
if nargin < 2
    includeRows = 1:size(trackerData,1);
% else only check only requested markers
else
    includeRows = markerIdsToRows(trackerData, TCM_LED_IDs);
end

trackerData = trackerData(includeRows, 3:5);

% this will store data until next call of this function
persistent lastData;

% in first call of function or if number of rows to check has changed since
% the last call, make lastData zero matrix of same size as trackerData.
if isempty(lastData) || any(size(lastData)~=size(trackerData))
    lastData = zeros(size(trackerData));
end
    
% Check for non-updated rows (skip in first call of this function)
bufferUpdated = true;
if any(all((trackerData-lastData)' == 0))
    bufferUpdated = false;
end

% Store trackerData for reference next time this function is called
lastData = trackerData;

end