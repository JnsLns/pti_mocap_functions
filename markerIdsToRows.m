function rows = markerIdsToRows(trackerData, TCM_LED_IDs)
% function rows = markerIdsToRows(trackerData, TCM_LED_IDs)
%
% Determine which rows in a matrix of tracker data correspond to specified
% markers.
%
% __Input__
%
% trackerData   Matrix of motion tracker data obtained from VzGetDat.
%
% TCM_LED_IDs   n-by-2 matrix, where n is the number of markers, column 1
%               holds TCMIDs for the markers of interest, and column 2
%               holds their LEDIDs.
% 
% __Output__
%
% rows          Row indices where the markers of interest are found in
%               trackerData, ordered according to TCM_LED_IDs.

[ismem, rows] = ismember(TCM_LED_IDs, trackerData(:,1:2), 'rows');

if ~all(ismem)
    error('Requested marker ID not present in the data.')
end

end