function filteredData = filterTrackerData(fromVzGetDat, TCM_LED_IDs, posOnly)
% function filteredData = filterTrackerData(fromVzGetDat, TCM_LED_IDs)
%
% Pass in data matrix obtained directly from VzGetDat and list of
% TCM/LED IDs, get back only data rows of matching markers. 
%
% 
% __Input__
%
% fromVzGetDat  Matrix with tracker data obtained directly from VzGetDat.
%
% TCM_LED_IDs   n-by-2 matrix, first column is TCMID, second column is
%               LEDID, rows correspond to n different markers.
%
% posOnly       optional, default false. If true, only position data from
%               the respective rows is returned in filteredData.
%
% __Output__
%
% filteredData  Tracker data matrix containing only rows that hold markers
%               matching the requested TCM_LED_IDs.

[~, idcs] = ismember(TCM_LED_IDs, fromVzGetDat(:,1:2),'rows');

% Check that all requested markers exist:
if any(idcs==0)
    mis = '';
    for e = find(idcs==0)'
        mis = strcat(mis, [num2str(fromVzGetDat(e,1)), ' , ', ...
                           num2str(fromVzGetDat(e,2)), '\n']);        
    end
    %mis(end-1:end) = '. ';
    error(sprintf(['The following TCMID/LEDID combinations given in argument ', ...
        'TCM_LED_IDs do not exist in the tracker data:\n', mis]))
        
end
        
filteredData = fromVzGetDat(idcs, :);

if posOnly
    filteredData = filteredData(:,3:5);
end


end
        
        