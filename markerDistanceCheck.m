function [withinThreshold] = markerDistanceCheck(trackerData, markerPairings, expectedDistances, threshold)
% function [withinThreshold] = markerDistanceCheck(trackerData, markerPairings, expectedDistances, threshold)
%
% Computes distances between tracker markers for a set of marker pairings,
% compares them to a set of expected distances, and checks whether any of
% the differences exceeds a threshold value. Can be used to detect
% erroneous marker localizations (e.g., due to reflections) in setups where
% multiple markers are mounted at fixed positions on a rigid body so that
% their distances should usually remain constant.
%
% Input for the arguments markerPairings and expectedDistances can be
% obtained using the function getMarkerDistances (for instance, at the 
% outset of the recording session).
%
% Note that this function does not explicitly check for zero position data  
% (e.g., due to marker occlusion) in trackerData before performing the
% distance check. Thus, any zero position data will usually lead to
% withinThrehold being false. If needed, perform an explicit check for zero
% data before calling this function, using zeroDataCheck.
% 
%
% __Input__
%
% trackerData       Marker position matrix obtained from motion trackers
%                   via vzGetDat.
%
% markerPairings    m-by-4 matrix. Each row specifies one marker pairing,
%                   with columns giving: (1) the TCM ID of marker 1,
%                   (2) LED ID of marker 1, (3) TCM ID of marker 2, and
%                   (4) LED ID of marker 2. Row order must correspond to
%                   element order in argument expectedDistances.
%
% expectedDistances Vector of distances expected for each of the marker
%                   pairings specified in markerPairings.
%
% threshold         Scalar that specifies the difference in current marker
%                   distances and expected distances beyond which
%                   withinThreshold will be false.
%
% __Output__
%
% withinThreshold   true if all distance differences are within threshold,
%                   false if threshold is exceeded for any pairing.
%
% See also GETMARKERDISTANCES, ZERODATACHECK.

withinThreshold = true;

% Convert marker ID pairings to pairings of trackerData rows
rowPairings = [markerIdsToRows(trackerData, markerPairings(:,1:2)), ...
               markerIdsToRows(trackerData, markerPairings(:,3:4))];
           
% Check difference for all pairings
for p = 1:size(rowPairings,1)
                
    %  Get distance for current pairing
    m1 = rowPairings(p, 1);
    m2 = rowPairings(p, 2);    
    dist = dist3d(trackerData(m1, 3:5), trackerData(m2, 3:5));
    
    % Compare to expected distances;
    % break on first occasion where threshold is exceeded
    if abs(dist - expectedDistances(p)) > threshold
        withinThreshold = false;
        break                
    end
            
end
   

end


