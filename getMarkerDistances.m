function [distances, markerPairings] = getMarkerDistances(nGoodFrames, TCM_LED_IDs, pairings)
% function [distances, markerPairings] = getMarkerDistances(nGoodFrames, TCM_LED_IDs, pairings)
%
% Calls VzGetDat to obtain marker position data and computes distances 
% between markers for all possible marker pairings, or for a defined
% subset of pairings.
%
% The outputs of this function can be passed to the function
% markerDistanceCheck to check whether distances have changed in the
% meantime. When doing so, output argument distances must be passed as
% input argument expectedDistances, and markerPairings must be passed as
% markerPairings. In a setup where markers are mounted in fixed positions
% on a rigid body this can be used to detect erroneous marker jumps, e.g.,
% due to marker reflections.
%
% __Input__
%
% nGoodFrames   Number of frames from VzGetDat on which the distance
%               computation should be based. The final output are the mean
%               distances over all of those frames. Frames where there are
%               problems with the marker data are not counted and not
%               included in the mean (this includes frames where one or
%               more markers yield zero data and frames where the tracker
%               buffer is not fully updated; see function goodDataCheck).
%
% TCM_LED_IDs   Optional, by default all markers obtained through VzGetDat
%               are used. Otherwise, n-by-2 matrix, where n is the number
%               of markers, column 1 holds TCMIDs for the markers of
%               interest and column 2 holds their LEDIDs. By default, i.e.,
%               if argument pairings is not specified, distances for all
%               possible non-redundant combinations of these markers will
%               be returned. 
%
% pairings      Optional, by default distances will be computed between all
%               markers in the data from VzGetDat or between all markers
%               specified in TCM_LED_IDs. If pairings is defined, it must
%               be an m-by-2 matrix specifiying in each row a pair of
%               indices addressing into rows of TCM_LED_IDs. Distances will
%               then be computed only for those marker combinations.
%
% __Output__
%
% distances         Vector of distances for the requested marker pairings.
%
% markerPairings    m-by-4 matrix. Each row specifies one marker pairing,
%                   with columns giving: (1) the TCM ID of marker 1,
%                   (2) LED ID of marker 1, (3) TCM ID of marker 2, and
%                   (4) LED ID of marker 2. Row order corresponds to
%                   element order in output argument distances.
%
%               
% See also MARKERDISTANCECHECK, GOODDATACHECK.

tmpDat = VzGetDat;

% by default check all markers
if nargin < 2 
    includeRows = 1:size(tmpDat,1);
    TCM_LED_IDs = tmpDat(:,1:2);
% else check only requested markers
else
    includeRows = markerIdsToRows(tmpDat, TCM_LED_IDs);
end

% find non-redundant row pairings for which distances need to be
% computed (or use only those pairings specified by argument)
if nargin < 3
    confMat = ones(size(tmpDat,1));
    confMat = tril(confMat,-1);
    % Exclude unwanted rows
    exclude = arrayfun(@(x) all(x ~= includeRows), 1:size(tmpDat,1));
    confMat(exclude, :) = 0;
    confMat(:, exclude) = 0;
    % Get row index combination
    rowPairings = [];
    for k = find(confMat)'
        [rowPairings(end+1,1),rowPairings(end,2)] = ...
            ind2sub(size(confMat),k);
    end
else
    % Convert marker IDs in argument pairings to rows of VzGetDat data.
    rows1 = markerIdsToRows(tmpDat, TCM_LED_IDs(pairings(:,1),:));
    rows2 = markerIdsToRows(tmpDat, TCM_LED_IDs(pairings(:,2),:));        
    rowPairings = [rows1, rows2];       
end

% Get nGoodFrames frames of good data and compute mean distance over those.
goodFramesCollected = 0;
while goodFramesCollected <= nGoodFrames
        
    % Get data from trackers
    data = VzGetDat;    
     
    % If data ok, get distance between each combination of markers.
    if goodDataCheck(data, TCM_LED_IDs)
        
        goodFramesCollected = goodFramesCollected + 1;
        %disp(['gfc: ', num2str(goodFramesCollected)]);
        
        for c_num = 1:size(rowPairings,1)
            c = rowPairings(c_num,:);
            d(c_num) = dist3d(data(c(1), 3:5), data(c(2), 3:5));
        end
        
        % Store current distances in final matrix
        ds(:,:,goodFramesCollected) = d;
        
    end
    
end

% convert row pairings back to marker pairings for output
markerPairings = [tmpDat(rowPairings(:,1),1), ...
                  tmpDat(rowPairings(:,1),2), ...
                  tmpDat(rowPairings(:,2),1), ...
                  tmpDat(rowPairings(:,2),2)  ...
                  ];

% mean distances over recorded frames
distances = mean(ds,3)';

end