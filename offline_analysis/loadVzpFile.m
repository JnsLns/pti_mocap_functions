function data = loadVzpFile(filename, dispProgress)
% function data = loadVzpFile(filename, dispProgress)
%
% Load motion tracking data from a *.vzp file (from VZSoft). This function
% requires mex-functions for interpreting vzp-files provided by PTI on the
% on the MATLAB path. Note that depending on the version of those functions
% these may run only on a 32 bit system.
%
% __Input__
%
% 'filename'    Full path and filename as a string.
%
% dispProgress  optional, default true. Print loading progress to MATLAB
%               command window. Set to false to suppress.    

if nargin < 2
    dispProgress = 1;
end

nTakes = VzpGetTakeCount(filename);

for t = 0:nTakes-1      
    
    % Get properties of this take    
    nMarkers = vzpGetTakeMarkers(filename, t);
    nFrames = vzpGetTakeFrames(filename, t);
    markerNames = {};
    markerIDs = []; 
    for m = 0:nMarkers-1
        markerNames{end+1} = vzpGetMarkerName(filename, t, m);
        markerIDs(end+1,:) = vzpgetmarkerID(filename, t, m);
    end            
                
    % Get frames
    frames = nan(nMarkers, 7, nFrames);
    for f = 0:nFrames-1    
        
        if dispProgress
            disp(['Processing take ', num2str(t+1), ' of ', num2str(nTakes), ...
                ', frame ', num2str(f+1), ' of ', num2str(nFrames), '.'])
        end
        
        frames(:,:,f+1) = vzpGetFrameData(filename, t, f);        
        
    end
    
    data(t+1).frameRate = vzpGetTakeFrameRate(filename, t);        
    data(t+1).nMarkers = nMarkers;    
    data(t+1).crf = vzpGetTakeCRF(filename, t);        
    data(t+1).markerNames = markerNames;
    data(t+1).markerIDs = markerIDs;
    data(t+1).nFrames = nFrames;
    data(t+1).frames = frames;            
    
end

