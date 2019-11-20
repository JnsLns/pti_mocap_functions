function [noDuplicates] = detectDuplicateRows(trackerData, TCM_LED_IDs)

% Simple function that as a workaround to marker merge problem checks
% whether any position data in the matrix from VzGetDat appears more than
% once. If so, noDuplicate is false (this is bad), else it is true.
%
% TCM_LED_IDs is optional (else all markers are considered).
%
% This function disregards zero position rows!

if nargin > 1    
    posData = filterTrackerData(trackerData, TCM_LED_IDs);
    posData = posData(:, 3:5); 
else
    posData = trackerData(:, 3:5);
end
    
% Remove zero rows
posData(all(posData' == 0),:) = [];

noDuplicates = true;
for rowNum = 1:size(posData, 1)          
        
    %Number of times current row's values appears in data
    n = sum(ismember(posData, posData(rowNum,:),'rows'));
        
    if n > 1
        noDuplicates = false;
        break;
    end
    
end
    
    