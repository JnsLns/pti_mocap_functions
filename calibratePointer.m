function [coeffs] = calibratePointer(pointerMarkers, tip, offset)
% function [coeffs] = calibratePointer(pointerMarkers, tip, offset)
%
% Compute coefficients that allow inferring the tip position of a pointer
% equipped with three tracker markers. Before calling this function, move
% the pointer tip to a known position (e.g., the origin). When called, the
% function takes a snapshot of the marker positions and computes the three
% coefficients on that basis. Use the function tipPosition to later compute
% tip position from the marker positions (marker locations on the pointer
% and argument pointerMarkers must be identical to those used when calling
% calibratePointer). Also performs checks for data quality before using the
% data for calibration.
%
% __Input__
%
% pointerMarkers    3-by-2 matrix, each row holding the TCMID and LEDID of
%                   one marker mounted on the pointer device.
%                   Alternatively this may be a 3-by-3 matrix holding
%                   spatial positions of the three markers (in this case,
%                   no data checks are performed), each row holds one
%                   marker (x,y,z).
%               
% tip           Either (a) a three-element row vector holding the current
%               tip position (x,y,z) or (b) a two-element row vector with
%               tip(1) giving the TCMID and tip(2) the LEDID of a marker
%               located at the position of the pointer tip.
%
% offset        Optional, default [0, 0 ,0]. Three-element row vector
%               (x,y,z) giving an offset of the actual tip position from
%               the position of the marker provided in argument tip.
%
% __Output__
%
% coeffs        Three-element row vector holding coefficients that can
%               be used for computing the position of the pointer tip from
%               the location of the three markers given in pointerMarkers
%               (using the function tipPosition).
%
% See also TIPPOSITION.


% Check whether marker data or IDs have been passed for pointer and tip

if size(pointerMarkers, 2) == 2 % pointer marker IDs passed
   m_ids = true;
   allIDs = pointerMarkers;
elseif size(pointerMarkers, 2) == 3 % pointer marker position data passed
   m_ids = false;
   allIDs = [];
end
    
t_id = false;
if numel(tip) == 2
    allIDs = [allIDs; tip];
    t_id = true;
end


% get marker positions from tracker if IDs were passed

if m_ids || t_id

    % initialize with first data
    goodDataCheck(VzGetDat, allIDs)

    % then wait for full buffer update and no zero data
    goodData = false;
    while ~goodData
        data = VzGetDat;
        goodData = goodDataCheck(data, allIDs);        
    end

end


% determine tip coordinates from marker or use passed values

if t_id
    ptip = data(markerIdsToRows(data, tip) ,3:5)';
elseif ~t_id
    ptip = tip';
else
    error('tip must be either a two- or three-element row vector');
end

% apply offset (zero if not provided explicitly)
if nargin < 3
    offset = [0 0 0];
end
ptip = ptip + offset';


% get pointer marker positions or use passed values

if m_ids

    % Data rows holding the three pointer markers
    pointerMarkersPos = markerIdsToRows(data, pointerMarkers);
    pointerMarkersPos = data(pointerMarkersPos, 3:5);

elseif ~m_ids

    pointerMarkersPos = pointerMarkers;
    
end


% compute coefficients

p1 = pointerMarkersPos(1,:)';
p2 = pointerMarkersPos(2,:)';
p3 = pointerMarkersPos(3,:)';

u1 = p2-p1;
u1 = u1/norm(u1);
u2 = p3-p1;
u2 = u2 - u1 * dot(u2,u1);  % adjust u2 to be orthogonal to u1
u2 = u2/norm(u2);
u3 = cross(u1,u2);          % 3rd directional vector is normal of plane u1u2
u3 = u3/norm(u3);
coeffs = [dot(ptip-p1,u1), dot(ptip-p1,u2), dot(ptip-p1,u3)];

end


