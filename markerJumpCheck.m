function [noJump, jumpedMarkers] = markerJumpCheck(trackerData, TCM_LED_IDs, velocityThreshold)
% function [noJump, jumpedMarkers] = markerJumpCheck(trackerData, TCM_LED_IDs, velocityThreshold)
%
% Check whether tracker markers moved a larger distance than expected
% since this function was called last. Such overly fast movement usually
% indicates erroneous measurements, most commonly due to marker
% reflections. When called in a loop that obtains tracker data via VzGetDat
% the function detects when a marker jump occurs and in the subsequent
% calls keeps reporting marker jumps until the respective marker is again
% localized at a position where it could have moved from the position
% before the jump without exceeding velocityThreshold.
%
% Note that this function does not explicitly check for zero position data  
% (e.g., due to marker occlusion) in trackerData before performing the
% jump check. Thus, when zero data occurs in a given row, noJump will be
% set to false if the respective marker was far from the coordinate origin
% in the last call. If needed, perform an explicit check for zero data
% before calling this function, using zeroDataCheck.
%
% __Input__
%
% trackerData           Marker position matrix obtained from motion
%                       trackers via vzGetDat.
%
% TCM_LED_IDs           Optional; if this argument is not passed or if an
%                       empty array is passed ([]) all markers in
%                       trackerData are checked. Otherwise, pass an
%                       n-by-2 matrix, where n is the number of markers,
%                       column 1 holds TCMIDs for the markers of interest
%                       and column 2 holds their LEDIDs. 
%
% velocityThreshold     Scalar. Maximum velocity up to which marker
%                       movement is not considered a jump.
%
%
% __Output__
%
% noJump                true if no marker jumps were detected, false if at
%                       least one marker moved faster than the threshold.
%                       See notes.
%
% jumpedMarkers         Boolean mask vector that is 1 for rows in
%                       trackerData where the threshold was exceeded. This
%                       mask maps to trackerData as passed to the function,
%                       not taking into account TCM_LED_IDs. See notes.
%
%
% __Notes__
%
% When a marker jumps and exceeds threshold, the corresponding element in
% jumpedMarkers as well as noJump will become false. They will become true
% again when the marker "jumps back", that is, when it is detected at a
% position that could have been attained by moving from the position
% just before the jump to its new position without exceeding the velocity
% threshold.
%
% An issue may arise in settings where this function is called repeatedly
% but with intermittent periods where it is not called, for instance, when
% trajectories are monitored only during a part of a trial. In this case, 
% the position at the start of the next trial may be far from that at the
% end of the previous one, so that a marker jump is detected, since
% the movement in between could not be tracked by the function. This is
% unlikely in settings where a participant is seated in a fixed location.
% Should it be a problem, however, call markerJumpCheck('reset') once at
% the outset of each trial to reset the stored location from the previous
% call.
%
%
% See also ZERODATACHECK.

persistent lastNonJumpData % stores data for later calls where data is bad

% reset 
if nargin == 1 && strcmp(trackerData, 'reset')
    lastNonJumpData = [];
    return
end


% Get data

trackerData_raw = trackerData;

% by default check all markers
if isempty(TCM_LED_IDs)
    includeRows = 1:size(trackerData_raw, 1);
% else check only requested markers
else
    includeRows = markerIdsToRows(trackerData_raw, TCM_LED_IDs);
end

trackerData = trackerData_raw(includeRows, :);


if isempty(lastNonJumpData)
    
    % First call will never yield jump
    
    jumpedMarkers = false(size(trackerData, 1), 1);
    lastNonJumpData = nan(size(trackerData));
    
else
    
    % if not first call, compare to previous pos
    
    % get positions and time stamps
    pos_cur = trackerData(:, 3:5);
    t_cur = trackerData(:, 6);   
    pos_old = lastNonJumpData(:,3:5);
    t_old = lastNonJumpData(:,6);        
    
    % Compute distances moved since last good data
    if size(pos_cur, 1) ~= size(pos_old, 1)
        error(['Error in markerJumpCheck: Current tracker data '...
            'matrix has different number of rows than the one '...
            'stored from previous call. Try calling '...
            'markerJumpCheck(''reset'') first.']);        
    end
    d = sqrt(sum((pos_cur - pos_old).^2, 2));                
    t = t_cur - t_old;
    v = d./t;        
    
    % check against threshold, boolean mask of rows where jumps occurred
    jumpedMarkers = v > velocityThreshold;
    
end                   


% Update non-jump data points, keep old data where jumps occurred (this
% way, when a jump occurs, the last known marker position will be used as
% reference to determine velocity)
lastNonJumpData(~jumpedMarkers,:) = trackerData(~jumpedMarkers,:);

% set overall jump flag 
if any(jumpedMarkers)
    noJump = false;      
else
    noJump = true;    
end

% convert jumpedMarkers to address into raw tracker data (instead of
% addressing into reduced set of rows based on includeRows)
tmp = false(size(trackerData_raw, 1), 1);
tmp(includeRows(jumpedMarkers), 1) = true;
jumpedMarkers = tmp;



    
    
    
    


