function data = loadVzpFile(filename)

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

