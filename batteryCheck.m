function [batteryEmpty, emptyMarkers] = batteryCheck(TCM_LED_IDs, reqOneFull, tThresh)
% function [batteryEmpty emptyMarkers] = batteryCheck(TCM_LED_IDs, reqOneFull, tThresh)
%
% Call VzGetDat and check for zero data for all markers or a specified
% subset of markers to determine battery status. Since zero data indicates
% either empty marker batteries or marker occlusion, marker occlusion may
% be misinterpreted as empty batteries; set reqOneFull and tThresh
% appropriately to counteract this (see below).
%
% __Input__
%
% TCM_LED_IDs   Optional, if this argument is not passed or if an empty
%               array is passed ([]) all markers obtained through VzGetDat
%               are checked. Otherwise, pass an n-by-2 matrix, where n is
%               the number of markers, column 1 holds TCMIDs for the
%               markers of interest and column 2 holds their LEDIDs. 
%
% reqOneFull    Optional, default true. If reqOneFull is true, batteryEmpty
%               will be true only if at least one of the specified markers
%               returned non-zero data. This way, it can be avoided to
%               interpret occlusion of all markers as a battery problem.
%               If reqOneFull is false, batteryEmpty will be true even if
%               all markers return zero data.
%
% tThresh       Optional, default 1 second. Defines how many consecutive
%               seconds the criterion set by reqOneFull needs to be met
%               before batteryEmpty becomes true. Should be set according
%               to the expected marker movement speed. Note that the clock
%               is reset once an empty battery has been detected, so that
%               the function will never return true (empty) again sooner
%               than tThresh seconds later. 
%               The rationale is that occlusion of all markers is usually
%               preceded by a short period where only a subset of markers
%               is occluded (e.g., when a rigid body equipped with several
%               markers moves behind an obstacle). Without a time threshold
%               the function would thus trigger erroneously in many
%               situations even when reqOneFull is true. 
%
% __Output__
%
% batteryEmpty  true if at least one marker battery is empty, false
%               otherwise. Note that after the function has returned true,
%               it will not return true for a period of tThresh seconds,
%               even if markers continue to return zero data.
%
% emptyMarkers  n-by-2 matrix holding the IDs of the markers whose
%               batteries are empty (first row TCM ID, second row LED ID).
% 
% See also ZERODATACHECK


% Variable to store zero data onset time over calls of the function
persistent tZeroDataOnset;
    
% Get tracker data
data = VzGetDat;

% by default check all markers
if nargin < 1 || isempty(TCM_LED_IDs)
    includeRows = 1:size(data,1);
% else check only requested markers
else
    includeRows = markerIdsToRows(data, TCM_LED_IDs);
end

if nargin < 2
    reqOneFull = true;
end

if nargin < 3
    tThresh = 1;
end

% By default assume none of the batteries are depleted
batteryEmpty = false;
emptyMarkers = [];

% Perform checks & count time
if any(any(data(includeRows,3:5) == 0)) % at least one bat empty
    
    % set batteryEmpty to true if criterion is met, which for
    % reqOneFull==true is "at least one marker returns zero data", and for
    % reqOneFull==false "at least one but not all markers return zero data".
    if ~reqOneFull 
        batteryEmpty = true;        
    elseif reqOneFull && ...
            (sum(any(data(includeRows,3:5)' == 0)) < numel(includeRows)) 
        batteryEmpty = true;
    end
    
    % in case of empty battery: If criterion has been met for the first
    % time, start counter but do not return 1 yet; if criterion was already
    % met in last call, check whether temporal threshold is reached and, if
    % so, return true. Else set batteryEmpty back to false.
    if batteryEmpty 
        if isempty(tZeroDataOnset) && tThresh ~= 0
            tZeroDataOnset = tic;
            batteryEmpty = false;
        elseif tThresh == 0 || toc(tZeroDataOnset) > tThresh
            batteryEmpty = true;
            % as soon as emptiness detected once, reset the counter
            tZeroDataOnset = []; 
            relevantDataRows = data(includeRows,:);  
            emptyMarkers = ...
                relevantDataRows(any((relevantDataRows(:,3:5) == 0)')',1:2);
        else
            batteryEmpty = false;
        end
    end
    
% if all bats full but at least one marker was silent in last call, reset
% time counter
elseif ~isempty(tZeroDataOnset) 
     
    tZeroDataOnset = []; 
    
end

end

