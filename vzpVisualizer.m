function vzpVisualizer()
% function vzpVisualizer()
%
% Jonas Lins, December 2019.
%
% Visualization tool for motion capture data from PTI motion trackers. No
% arguments required. Allows streaming from trackers in realtime as well as
% loading vzp or mat file (as obtained from function loadVzpFile).
%
% Note that MEX-files obtained from PTI are required (see startup message).

% NOTE: To debug streaming without a tracker connection uncomment the
% VzGetDat function replacement at the bottom of this file, which will
% "stream" random data points.

% TODO: Make figure user data and store there things like speed, speeds,
% take etc. to make it accessible to callbacks. Then move all logic
% including these to callbacks. This should tidy up this code.

% Set up GUI etc.

secsPerDegreeRotation = 0.01; % rotation speed
histLen = 500; % initial history length in frames (plotted lines)
speeds = [0.1, 0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 4, 8, 16, 32];
markerBaseLineWidth = 0.5;
waitSecsForBufferUpdate = 0.1; % how long to wait for buffer update when
                               % getting data. After that the old data is
                               % returned. (and a flag is set).

% Check existence of PTI functions required for streaming and loading vzp
% files. Warn if not existent.

reqMex = mexext;
sysType = computer;
if strfind(sysType, 'PCWIN')
    os = 'MS Windows';
elseif strfind(sysType, 'GLNX')
    os = 'Linux';
else
    os = 'unknown';
end
if strfind(sysType, '64')
    bit = '64 bits';
else 
    bit = '32 bits';
end
sysNote = ['Note that the current system is ', os, ' ', bit, '. MEX-files for this ', ...
 'system have the extension *.', reqMex, '.'];
% required function names
reqFuns = ...
{'VzGetDat', ...  
'VzpGetTakeCount', ...
'vzpGetTakeMarkers', ...
'vzpGetTakeFrames', ...
'vzpGetMarkerName', ...
'vzpgetmarkerID', ...
'vzpGetFrameData', ...
'vzpGetTakeFrameRate', ...
'vzpGetTakeCRF'};
reqFunsExt = ...
    cellfun(@(nameStr) [nameStr, '.', reqMex], reqFuns, 'uniformoutput', 0);
% Check existence of functions
funFound = [];
for funName = reqFunsExt
    funFound(end+1) = exist(funName{1});        
end
funFound = funFound == 2;
% Construct strings
fnfStr = {'not found', 'found'};
streamStr = ...
['To stream data from the trackers you need the following MEX-file ', ...
 'on your MATLAB path (letter case intentional):\n\n', ...
 reqFuns{1}, '   (', fnfStr{funFound(1)+1}, ')', '\n\n'];
loadVzpStr = ...
['To load data from a *.vzp file you need the following MEX-files ', ...
 'on your MATLAB path (letter case intentional):\n\n', ...
  cell2mat(cellfun(@(n,f) cell2mat([n, '   (', fnfStr(f), ')\n']), ...
  reqFuns(2:end), num2cell(funFound(2:end)+1), 'uniformoutput', 0)), '\n'];
% Warn if any missing
introStr = ['Some of the functions required for online-streaming or for loading *.vzp ', ...
    'files are missing. These can be obtained directly from Phoenix ', ...
    'Technology. Without these functions, you will still be able to ', ...
    'load tracking data from *.mat files.\n\n'];
if any(~funFound)
    waitfor(...
    warndlg(sprintf([introStr, streamStr, loadVzpStr, sysNote]), ...
        'Required functions not found'));    
end
              

% set marker colors (in order as they appear in data). Use strings or
% RGB vectors. Can be commented out to cycle through color palette.
% colors = {'g','g','g','g','r','r','r','b','b','b'};

hFig = figure('SizeChangedFcn', @fig_size_cb, 'visible', 'off', ...
    'position', [300, 200, 1200, 750], ...
    'windowbuttonupfcn', @fig_buttonUp_cb, 'UserData', ...
    struct('buttonUp',0), 'name', 'Vzp Data Visualizer', 'numbertitle', ...
    'off');
               
% UI control elements 

hBorder = 20;
vBorder = 80;
vSliderBorder = 20;
sep = 5;
height = 20;
fullWidth = (hFig.Position(3) - hBorder*2);
width = (fullWidth-7*sep) / 8;
% use this to get positions for the elements
% h is horizontal grid pos, left to right
% v is vertical grid pos, bottom to top
% hb is horizontal border used (added once to move left from left fig border)
% hb is horizontal border used (added once to move up from lower fig border)
uiPos = @(h,v,hb,vb) [hb+width*(h-1)+sep*(h-1), ...
    vb+height*(v-1)+sep*(v-1), ...
    width, height];

hFrameSlider = ...
    uicontrol(hFig, 'style','slider','units','pixels', ...
    'position', uiPos(1,1,hBorder,vSliderBorder), ...
    'min', 1, 'max', 1000, 'value', 1, 'tag', 'frameSlider');
addlistener(hFrameSlider,'Value','PreSet',@frameSlider_preSet_cb);

hFrameText = ...
    uicontrol(hFig, 'style', 'text', 'units', 'pixels', ...
    'position', [hBorder, vSliderBorder+height, fullWidth, height], ...
    'string', 'Frame n/a of n/a | n/a of n/a s | n/a fps', ...
    'horizontalAlignment', 'center', 'tooltip', ...
    ['fps are obtained from loaded file or as streaming average. ', ...
    '''trackers queried @'' gives a hard limit due to MATLAB loop round time.']);
    hFrameText.Units = 'normalized';

hPauseButton = ...
    uicontrol(hFig, 'style', 'pushbutton', 'units', 'pixels', ...
    'position', uiPos(1,1,hBorder,vSliderBorder+height+sep), ...
    'string', 'Pause', 'callback', @pause_cb, 'UserData', 0, 'tag', ...
    'pauseButton', 'Enable', 'off');

hHistLenEdit = ...
    uicontrol(hFig, 'style', 'edit', 'units', 'pixels', ...
    'position', uiPos(1,3,hBorder,vBorder)./[1 1 3 1], ...
    'string', ...
    num2str(histLen));

hHistLenText = ...
    uicontrol(hFig, 'style', 'text', 'units', 'pixels', ...
    'position', uiPos(2,3,hBorder,vBorder)./[3 1 1.5 1]+[sep*3 0 0 0], ...
    'string', 'History steps', 'horizontalAlignment', 'left');

hSpeedMenu = ...
    uicontrol(hFig, 'style', 'popupmenu', 'units', 'pixels', ...
    'position', uiPos(1,4,hBorder,vBorder)./[1 1 3 1], ...
    'string', strsplit(num2str(speeds)), 'Value', find(speeds==1), 'tag', ...
    'speedMenu');

hSpeedText = ...
    uicontrol(hFig, 'style', 'text', 'units', 'pixels', ...
    'position', uiPos(2,4,hBorder,vBorder)./[3 1 1.5 1]+[sep*3 0 0 0], ...
    'string', 'Speed', 'horizontalAlignment', 'left');

hLabelCheckbox = ...
    uicontrol(hFig, 'style', 'checkbox', 'units', 'pixels', ...
    'position', uiPos(1,6,hBorder,vBorder), 'String', 'Show labels');

hRotateCheckbox = ...
    uicontrol(hFig, 'style', 'checkbox', 'units', 'pixels', ...
    'position', uiPos(1,7,hBorder,vBorder), 'String', 'Rotation');

hFitAxesToMarkersCheckbox = ...
    uicontrol(hFig, 'style', 'checkbox', 'units', 'pixels', ...
    'position', uiPos(1,9,hBorder,vBorder), 'String', 'Always fit to frame ', ...
    'callback', @fitAxesToMarkersCheckbox_cb, 'tag', 'fitToMarkersCheckbox', ...
    'tooltip', ['Continuously adjust axes limits to show all marker ', ...
    'positions in current frame (disregarding zero data)']);

hFitAxesToMarkersButton = ...
    uicontrol(hFig, 'style', 'pushbutton', 'units', 'pixels', ...
    'position', uiPos(1,10,hBorder,vBorder), ...
    'string', 'Fit axes to frame', 'UserData', struct('clicked', 0), ...
    'callback', @fitAxesToMarkersButton_cb, 'tooltip', ...
    ['Adjust axes limits to show all marker ', ...
    'positions in current frame (disregarding zero data)']);

hFitAxesToHistCheckbox = ...
    uicontrol(hFig, 'style', 'checkbox', 'units', 'pixels', ...
    'position', uiPos(1,11,hBorder,vBorder), 'String', 'Always fit to history', ...
    'callback', @fitAxesToHistCheckbox_cb, 'tag', 'fitToHistCheckbox', ...
    'tooltip', ...
    ['Continuously adjust axes limits to show data in all history frames ', ...
    ' (disregarding zero data)']);

hFitAxesToHistButton = ...
    uicontrol(hFig, 'style', 'pushbutton', 'units', 'pixels', ...
    'position', uiPos(1,12,hBorder,vBorder), ...
    'string', 'Fit axes to history', 'UserData', struct('clicked', 0), ...
    'callback', @fitAxesToHistButton_cb, ...
    'tooltip', ...
    ['Adjust axes limits to show data in all history frames ', ...
    ' (disregarding zero data)']);

hFitAxesToTakeDataButton = ...
    uicontrol(hFig, 'style', 'pushbutton', 'units', 'pixels', ...
    'position', uiPos(1,13,hBorder,vBorder), ...
    'string', 'Fit axes to all data in take', 'UserData', struct('clicked', 0), ...
    'callback', @fitAxesToTakeDataButton_cb, ...
    'tooltip', ...
    ['Adjust axes limits to include all data points in the take ', ...
    ' (disregarding zero data)']);

hExcludeOutliersCheckbox = ...
    uicontrol(hFig, 'style', 'checkbox', 'units', 'pixels', ...
    'position', uiPos(1,14,hBorder,vBorder), 'String', 'Omit outliers for fit', ...
    'callback', @fitAxesToHistCheckbox_cb, 'tooltip', ...
    ['When fitting axes limits to take or history data, use only absolute values ', ...
    'below 99th percentile.']);

hTakeMenu = ...
    uicontrol(hFig, 'style', 'popupmenu', 'units', 'pixels', ...
    'position', uiPos(1,16,hBorder,vBorder)./[1 1 3 1], ...
    'string', ' ', 'tag', 'takeMenu');

hTakeText = ...
    uicontrol(hFig, 'style', 'text', 'units', 'pixels', ...
    'position', uiPos(2,16,hBorder,vBorder)./[3 1 1.5 1]+[sep*3 0 0 0], ...
    'string', 'Take', 'horizontalAlignment', 'left');

hLoadButton = ...
    uicontrol(hFig, 'style', 'pushbutton', 'units', 'pixels', ...
    'position', uiPos(1,17,hBorder,vBorder), ...
    'string', 'Load data file', 'callback', @load_cb, 'tooltip', ...
    ['Load *.vzp or *.mat file (the latter must contain data ', ...
    'in the format returned by loadVzpFile()).'], 'tag', ...
    'loadButton');
hLoadButton.UserData.data = [];
hLoadButton.UserData.newFileLoaded = 0;


hSaveStreamingButton = ...
    uicontrol(hFig, 'style', 'pushbutton', 'units', 'pixels', ...
    'position', uiPos(1,19,hBorder,vBorder), ...
    'string', 'Save to file', 'callback', @streamingSave_cb, ...
    'UserData', struct('wasClicked', 0), 'tag', ...
    'hSaveStreamingButton', 'Enable', 'off', 'tooltip', ...
    'Save streamed data to *.mat file.');

hStreamingDiscardButton = ...
    uicontrol(hFig, 'style', 'pushbutton', 'units', 'pixels', ...
    'position', uiPos(1,20,hBorder,vBorder), ...
    'string', 'Restart recording', 'callback', @streamingDiscard_cb, ...
    'UserData', struct('wasClicked', 0), 'tag', ...
    'StreamingDiscardButton', 'Enable', 'off' , 'tooltip', ...
    'Discard data streamed so far and start new data recording.');

hStreamingUpdateButton = ...
    uicontrol(hFig, 'style', 'pushbutton', 'units', 'pixels', ...
    'position', uiPos(1,21,hBorder,vBorder), ...
    'string', 'Update streamed data', 'callback', @streamingUpdate_cb, ...
    'UserData', struct('wasClicked', 0), 'tag', 'StreamingUpdateButton', ...
    'Enable', 'off', 'tooltip', ['Do not resume the live plotting, but ', ...
    'add data captured in the meantime to the plot.']);

hStreamingPauseButton = ...
    uicontrol(hFig, 'style', 'pushbutton', 'units', 'pixels', ...
    'position', uiPos(1,22,hBorder,vBorder), ...
    'string', 'Pause live plot', 'callback', @streamingPause_cb, 'UserData', ...
    struct('active',0,'justEnabled',0,'justDisabled',0), 'tag', ...
    'StreamingPauseButton', 'Enable', 'off', 'tooltip', ...
    ['Stop the live plot, enabling to inspect data captured thus far. ', ...
    'Data recording resumes in background but won''t update plots.' ]);

hStreamCheckbox = ...
    uicontrol(hFig, 'style', 'checkbox', 'units', 'pixels', ...
    'position', uiPos(1,23,hBorder,vBorder), 'String', 'Stream from trackers', ...
    'UserData', struct('wasChecked',0,'wasUnchecked',0), ...
    'callback', @streamCheckbox_cb);

hQuitButton = ...
    uicontrol(hFig, 'style', 'pushbutton', 'units', 'pixels', ...
    'position', uiPos(1,25,hBorder,vBorder), ...
    'string', 'Quit', 'callback', @quit_cb);
hQuitButton.UserData.wantQuit = 0;

% Set up 3d axes
axWidth = 930;
axHeight = 611;
hAx = axes('view', [-45 30], 'ButtonDownFcn', @hAx_ButtonDownFcn, ...
    'UserData', struct('buttonDown',0),'tag','3dAxes', 'units', 'pixels', ...
    'position', [width/4, (height*3+vSliderBorder)*1.5, axWidth, axHeight]);
axis equal
axis vis3d
xlabel('x')
ylabel('y')
zlabel('z')
hold on

% Warning text for static data
axc = hAx.Position(1:2)+hAx.Position(3:4)./2;
txtWidth = 300;
txtHeight = 30;
hIdenticalDataText = ...
    uicontrol('style', 'text', 'string', ['Warning: Recorded streaming data ', ...
    'is unchanging. Capture process not running in VZSoft?'],...
    'position', ...
    [axc(1)-txtWidth/2, axc(2)-txtHeight/2, txtWidth, txtHeight], ...
    'foregroundcolor', 'r', 'visible', 'off', ...
    'tag', 'identicalDataText', 'backgroundColor', 'k');

% UI data table
tXpos = hAx.Position(1)+hAx.Position(3)-150;
tYpos = vBorder;
tWidth =  hFig.Position(3) - hBorder - tXpos;
tHeight = hFig.Position(4) - tYpos - 40;
hDataTable = uitable(hFig,'Data',nan(7,7), 'units', 'pixels', ...
                    'Position',[tXpos tYpos tWidth tHeight], 'ColumnName', ...
                    {'TCM','LED','x','y','z','t','good'}, ...
                    'ColumnWidth', num2cell(repmat(floor((tWidth-30)/7),1,7)));
                
% Set units to normalize for scaling                
hDataTable.Units = 'normalized';                
hAx.Units = 'normalized';                               
hFig.Visible = 'on';
hIdenticalDataText.Units = 'Normalized';

try

% Note: There are two main loops here, the outer one just below, which
% determines what data are used, and an inner one, which iterates over the
% frames of the current data.
%
% The code in the outer loop is (re-)executed:
%
% - on startup and as long as no data has been loaded or recorded
% - when a new file was loaded
% - when the user selected a new take in the take dropdown menu
% - when the streaming checkbox is checked or unchecked
% - when the "restart recording" button was clicked (discard data so far)

speedSelected = hSpeedMenu.Value;
speed = speeds(speedSelected);
dataIsStreamedData = 0;

while 1    
           
    % request to restart online streaming 
    
    if hStreamingDiscardButton.UserData.wasClicked
        hStreamingDiscardButton.UserData.wasClicked = 0;
        hStreamCheckbox.Value = 1;
        streamCheckbox_cb(hStreamCheckbox,[]);
    end        
        
    % when streaming first enabled or restart of streaming requested, get
    % some sample data and construct data struct from that
    
    if hStreamCheckbox.UserData.wasChecked                        
        
        % if streaming pause active -> disable 
        if hStreamingPauseButton.UserData.active == 1            
            streamingPause_cb(hStreamingPauseButton); 
            streamingPauseWasActive = 1;
        else
            streamingPauseWasActive = 0;
        end
        
        % reset click state of and checkbox        
        hStreamCheckbox.UserData.wasChecked = 0;        
        
        % Get some sample data (one sec, but at least five frames)                
        f = 0; sampleTime = 1; sampleStart = tic;
        tmpDat = [];
        while toc(sampleStart) < sampleTime || size(tmpDat,3) < 5 
            f = f + 1;
            [tmpDat(:,:,f), waitSecsForBufferUpdateExc] = getDat(3);
            % if data is static (VzSoft not capturing?), cancel streaming
            if waitSecsForBufferUpdateExc
                break;
            end
        end         
        
        if waitSecsForBufferUpdateExc % streaming failed
            
            msgbox(['Data obtained from trackers is not changing. Maybe ', ...
                'data capture is inactive in VzSoft? I stopped ', ...
                'streaming for now.'],'Static data');
        
            % if streaming pause was active before -> re-enable
            % else (=streaming was not active at all) -> disable streaming
            if streamingPauseWasActive
                streamingPause_cb(hStreamingPauseButton);
            else
                hStreamCheckbox.Value = 0;
                streamCheckbox_cb(hStreamCheckbox,[]);
            end                                    
            
        else
            
            dataIsStreamedData = 1;
            
            % reset variable to which data will be recorded
            data = struct();
            
            % compute needed values from sample data
            data(1).nFrames = f;
            data(1).frameRate = f/sampleTime;
            data(1).nMarkers = size(tmpDat,1);
            data(1).markerNames = cellstr(num2str(tmpDat(:,1:2,1)));
            data(1).markerIDs = tmpDat(:,1:2,1);
            data(1).crf = nan;
            
            % Set some UI variables
            take = 1;
            speed = 1;
            hSpeedMenu.Value = find((speeds == 1));
            
            % First few data points
            data(1).frames(:,:,1:5) = tmpDat(:,:,1:5);
        
        end
        
    end
    
    % Load file
    
    if hLoadButton.UserData.newFileLoaded             
        hLoadButton.UserData.newFileLoaded = 0;
        data = hLoadButton.UserData.data.data;
        take = 1;
        hTakeMenu.Value = take;        
        hFrameSlider.Max = data(1).nFrames;
        hFrameSlider.Value = 1;
        hFrameSlider.SliderStep = [1/data(1).nFrames 1/data(1).nFrames];        
        hTakeMenu.String = num2cell(1:size(data,2));
        dataIsStreamedData = 0;
    end
        
    % Calculations based on data only when data has been loaded or recorded
    if exist('data', 'var')
        
        % Store take and speed to be able to detect changes
        
        previousTake = take;
        previousSpeedSelected = speedSelected;
        
        % Put data from struct into variables used in the following
        
        frames = data(take).frames;
        nFrames = data(take).nFrames;
        frameRate = data(take).frameRate;
        nMarkers = data(take).nMarkers;
        lastGoodPos = nan(nMarkers, 3);
        
        % Get time stamps relative to first frame
        
        T = relativeTimeStamps(frames, frameRate);                
        takeDuration = max(T);
        
        % Set frame slider properties according to data
        
        hFrameSlider.Max = nFrames;
        hFrameSlider.SliderStep = [1/nFrames, 1/nFrames];
        
        % Set axes limit based on take data extent (happens in frame loop)
        hFitAxesToTakeDataButton.UserData.clicked = 1;
                                                    
    end
    
    % Iterate over frames
            
    tElapsed = 0;
    curFrame = 0;    
    initializeDots = 1;
    initializeLines = 1;
    previousFrame = 0;    
    hFrameSlider.UserData.setElapsedTime = 0;
    forceReplot = 0;
    rotationTic = tic;
    tic    
    
    % Stream data saving only when streamed data present
    if dataIsStreamedData
        hSaveStreamingButton.Enable = 'on';
    else
        hSaveStreamingButton.Enable = 'off';
    end
    
    % Make sure pause button not operable when no data present,
    % otherwise set correct string.
    if ~exist('data', 'var') || isempty(data)            
        hPauseButton.Enable = 'off';        
    else
        if hPauseButton.UserData == 1
            hPauseButton.String = 'Play';
        elseif hPauseButton.UserData == 0
            hPauseButton.String = 'Pause';
        end
    end
    
    
    while 1                        
        
        % Initialize plots if streaming was enabled or restart
        % of streaming take requested
        if hStreamCheckbox.UserData.wasChecked || ...           
           hStreamingDiscardButton.UserData.wasClicked                             
           delete(hAx.Children)    
           break;
        end
                
        % in case streaming is active
        if hStreamCheckbox.Value              
            % Get frame from trackers (record even when paused) BUT                                   
            % if no new data within wait time, a frame will be obtained
            % anyway, but it will not differ from before (even the time
            % stamps may be identical). If so, replace timestamps
            % artificially and warn. This is just so the script can't get
            % stuck due to bufferUpdateCheck within getDat().
            [obtainedFrame, waitSecsForBufferUpdateExc] = getDat(waitSecsForBufferUpdate);                        
            if ~waitSecsForBufferUpdateExc                
                data(1).frames(:,:,end+1) = obtainedFrame;
                hIdenticalDataText.Visible = 'off';
            else
                obtainedFrame(:,7,:) = nan; % bad data will be nan
                obtainedFrame(:,6,:) = data(1).frames(:,6,end)+waitSecsForBufferUpdate;                                 
                data(1).frames(:,:,end+1) = obtainedFrame;
                hIdenticalDataText.Visible = 'on';
            end                
            data(1).nFrames = size(data(1).frames,3);                                           
            % If live plot is not paused or update button was pressed.
            % Update plotting variables / UI with new data, update time to
            % last streamed frame
            if ~hStreamingPauseButton.UserData.active || ...
                hStreamingUpdateButton.UserData.wasClicked                
                hStreamingUpdateButton.UserData.wasClicked = 0;                            
                nFrames = data(1).nFrames;
                frames = data(1).frames;                              
                T = relativeTimeStamps(frames, frameRate); 
                takeDuration = max(T);                
                frameRate = nFrames/takeDuration; 
                hFrameSlider.Max = nFrames;
                hFrameSlider.SliderStep = [1/nFrames, 1/nFrames];  
                tElapsed = T(end);
            end                                                    
            % When streaming pause just clicked: Enabled-> go to start of
            % recorded frames and set speed to 1. When Disabled-> reset
            % speed.
            if hStreamingPauseButton.UserData.justEnabled
                hStreamingPauseButton.UserData.justEnabled = 0;                                                                
                tElapsed = 0;
                oldSpeed = speed;
                oldSpeedMenuValue = hSpeedMenu.Value;
                speed = 1;
                hSpeedMenu.Value = find((speeds == 1));
            elseif hStreamingPauseButton.UserData.justDisabled
                hStreamingPauseButton.UserData.justDisabled = 0;
                speed = oldSpeed;
                hSpeedMenu.Value = oldSpeedMenuValue;            
            end           
        end                
                
        % Saving streamed data
        if hSaveStreamingButton.UserData.wasClicked
           hSaveStreamingButton.UserData.wasClicked = 0;
            % save only streamed data updated in UI (not that recorded in
            % background)
            saveStreamedData(data, frames, nFrames, frameRate)                  
        end
        
        % For quitters
        if hQuitButton.UserData.wantQuit           
            if dataIsStreamedData
                resp = ...
                    questdlg(['Save streamed data to file before quitting?'], ...
                    'Save data', 'Yes', 'No', 'Yes');
                if strcmp(resp, 'Yes')
                    saveStreamedData(data, frames, nFrames, frameRate)
                end
            end            
            close(hFig);
            return
        end
        
        reload = 0; % flag used in frame loop to get back here
        
        % skip bulk of this loop if no data loaded/recorded yet
        if exist('data', 'var')                        
            
            % If pause not active, increment elapsed time since last plot
            if ~hPauseButton.UserData
                tElapsed = tElapsed + toc * speed;
            end
            tic
            
            % if user moved slider, update tElapsed accordingly; else adjust
            % slider to current elapsed time
            if hFrameSlider.UserData.setElapsedTime
                tElapsed = T(round(hFrameSlider.Value));
                hFrameSlider.UserData.setElapsedTime = 0;
            else
                hFrameSlider.UserData.settingFromCode = 1;
                hFrameSlider.Value = max(1,curFrame);
                hFrameSlider.UserData.settingFromCode = 0;
            end
                        
            % change frame number based on elapsed time
            [~, newFrame] = min(abs(T- tElapsed));            
            
            % curFrame becomes newFrame BUT
            % during streaming, new frame should not exceed available
            % frames and tElapsed should not exceed total recording time;
            % except when pause activated.
            if hStreamCheckbox.Value && ~hPauseButton.UserData
                if tElapsed > T(end) && ...
                        ~hStreamingPauseButton.UserData.active
                    tElapsed = T(end);
                end
                if ~(newFrame > nFrames)
                    curFrame = newFrame;
                end
            else
                curFrame = newFrame;
            end
            
            % Update frame number
            hFrameText.String = ['Frame ', num2str(curFrame), ' of ', ...
                num2str(nFrames), '  |  ', num2str(tElapsed), ' of ',...
                num2str(takeDuration) ' s', ...
                ' | ', num2str(frameRate), ' fps'];            

            % roll around when take duration exceeded
            if tElapsed > T(end)
                tElapsed = 0;
                curFrame = 1;
                tic
            end            
                        
            % if new take selected delete plots and leave loop
            if hTakeMenu.Value ~= previousTake
                take = hTakeMenu.Value;
                reload = 1;
            end                   
       
            % if new speed selected, change speed
            if hSpeedMenu.Value ~= previousSpeedSelected
                speed = speeds(hSpeedMenu.Value);
            end
            
            % set history length
            histLen_old = histLen;
            histLen = round(str2num(hHistLenEdit.String));
            if isempty(histLen)
                histLen = histLen_old;
            end
            if histLen ~= histLen_old
                forceReplot = 1;
            end
            hHistLenEdit.String = num2str(histLen);            
            
            % zoom to data if button clicked (onto mean of data with axes
            % extension based on data span.
            if hFitAxesToMarkersCheckbox.Value || ...
                    hFitAxesToMarkersButton.UserData.clicked
                hFitAxesToMarkersButton.UserData.clicked = 0;
                posTmp = frames(:,[3,4,5],curFrame);
                posTmp = posTmp(~all(posTmp==0,2),:);
                if ~isempty(posTmp)
                    center = mean(posTmp,1);
                    maxDist = ...
                        max(1, max(max(abs(posTmp - repmat(center,size(posTmp,1),1)))));
                    axLims = [center-(maxDist+maxDist*0.1); ...
                        center+(maxDist+maxDist*0.1)];
                    set(hAx, 'XLim', axLims(:,1), 'YLim', axLims(:,2), 'ZLim', axLims(:,3));
                end
            end
            
            % zoom to history or all data (this is done in the frame loop
            % as the history frames are needed which are computed there)
            if hFitAxesToHistButton.UserData.clicked || ...
               hFitAxesToTakeDataButton.UserData.clicked
                forceReplot = 1;                
            end            
            
            % Axes rotation
            if hRotateCheckbox.Value && ~hAx.UserData.buttonDown
                if toc(rotationTic) > secsPerDegreeRotation
                    oldView = hAx.View;
                    hAx.View = oldView + [1 0];
                    rotationTic = tic;
                end
            end
            
            
            
            if curFrame ~= previousFrame || forceReplot
                
                forceReplot = 0;                                                                
                
                % Get current frame data to plot dots (and determine which
                % rows are marked bad data in column seven and which
                % contain only zero position data)
                
                frame = frames(:,:,curFrame);                
                if size(frame,2) == 7 
                    goodDataCol = frame(:,7);                     
                else % streamed data has no column 7
                    goodDataCol = ones(size(frame,1),1);
                end
                rowsMarkedGood = find(goodDataCol)';                     
                [~,zeroRows] = zeroDataCheck(frame);  
                rowsNotZero = setdiff(1:nMarkers, zeroRows);
                % store last good position (not zero, not bad data)
                rowsUsable = unique([rowsMarkedGood, rowsNotZero]);
                lastGoodPos(rowsUsable, :) = frame(rowsUsable,3:5);                                                                
                % use current data for markers where data is marked good
                % and not zero data, otherwise use last good frame position
                rowsUnusable = setdiff(1:nMarkers, rowsUsable);
                tmpFrame = frame;
                tmpFrame(rowsUnusable, 3:5) = lastGoodPos(rowsUnusable,:);                
                x = tmpFrame(:,3)';
                y = tmpFrame(:,4)';
                z = tmpFrame(:,5)';
                t = tmpFrame(:,6)';  
                % for later use during plotting
                rowsMarkedGood = toBoolMask(rowsMarkedGood, nMarkers);
                rowsNotZero = toBoolMask(rowsNotZero, nMarkers);
                rowsUsable = toBoolMask(rowsUsable, nMarkers);                
                
                % Update table
                tblData = [num2cell(frame(:,1:2)), ...
                        arrayfun(@(x) sprintf('%.4f\n',x), frame(:,3:6),'un',0)];
                % last (good data column depends on whether loaded or streamed)
                if size(frame,2) == 7                    
                    tblData = [tblData, num2cell(frame(:,7))];                                        
                else
                    tblData = [tblData, num2cell(nan(size(frame,2),1))];
                end
                hDataTable.Data = tblData;
                
                % Get history over last steps, for lines
                
                histFrames = frames(:,:,max(1,curFrame-histLen):curFrame);
                xHist = squeeze(histFrames(:,3,:))';
                yHist = squeeze(histFrames(:,4,:))';
                zHist = squeeze(histFrames(:,5,:))';                
                
                % Initialize dots (current marker positions)
                
                if initializeDots == 1
                    initializeDots = 0;
                    hDots = plot3(hAx, [x;x], [y;y], [z;z], 'o', ...
                        'markersize', 8, 'linewidth', markerBaseLineWidth);
                    set(hDots, 'markerEdgeColor', 'k');                    
                    for j = 1:numel(hDots)
                        % adjust marker color
                        dt = hDots(j);
                        col = dt.Color+0.25;
                        col(col>1) = 1;
                        dt.MarkerFaceColor = col;
                        % add marker labels
                        hAx;
                        hLabels(j) = text(...                        
                        dt.XData(1), dt.YData(1), dt.ZData(1), ...
                            ['  ', num2str(frame(j,1)), '|', num2str(frame(j,2))]);                                                
                    end
                    try
                    set(hLabels, 'color', [.3 .3 .3], 'fontsize', 10);
                    end
                    if exist('colors', 'var')
                        for i = 1:numel(hDots)                            
                            hDots(i).MarkerFaceColor = colors{i};
                        end
                    end                                                                             
                    grid(hAx, 'on');                                                                 
                end
                
                % Initialize lines (marker histories)
                
                if initializeLines && curFrame > 1
                    hLines = plot3(hAx, xHist, yHist, zHist);
                    for c = 1:numel(hLines)
                        hLines(c).Color = hDots(c).Color;
                    end
                    initializeLines = 0;
                end
                
                % Update plots                                
                hLabels = hLabels(isgraphics(hLabels));
                if ~hLabelCheckbox.Value                   
                   set(hLabels,'Visible','off');
                else
                   set(hLabels,'Visible','on');
                end                                
                set(hDots, 'MarkerEdgeColor', 'k', ... % (Reset dot colors)
                    'linewidth', markerBaseLineWidth);                
                if exist('hDotsCross', 'var')  % remove bad data indicators
                    delete(hDotsCross)                                     
                end
                hDotsCross = gobjects();
                % Go through dots and lines, update their data, also add
                % data quality indicators for each marker
                for numLine = 1:numel(hDots)
                    % Update lines
                    if ~initializeLines
                        hLines(numLine).XData = xHist(:,numLine)';
                        hLines(numLine).YData = yHist(:,numLine)';
                        hLines(numLine).ZData = zHist(:,numLine)';
                    end
                    % Update dots
                    hDots(numLine).XData = x([numLine, numLine]);
                    hDots(numLine).YData = y([numLine, numLine]);
                    hDots(numLine).ZData = z([numLine, numLine]);                    
                    % Add indicators for bad data
                    if ~rowsUsable(numLine)      
                            % zero data -> red outline
                            if ~rowsNotZero(numLine)
                                hDots(numLine).MarkerEdgeColor = 'r';
                                hDots(numLine).LineWidth = markerBaseLineWidth + 1;
                            end                       
                            % marked bad -> additional red cross                            
                            if ~rowsMarkedGood(numLine)                                
                                hDotsCross(end+1) = copyobj(hDots(numLine),hAx) ;
                                hDotsCross(end).Marker = 'x';
                                hDotsCross(end).MarkerEdgeColor = 'r';
                                hDotsCross(end).LineWidth = markerBaseLineWidth;
                                %uistack(hDotsCross(numLine),'top')
                            end                                                                                                            
                    end
                    % Update labels
                    hLabels(numLine).Position = ...
                        [x(numLine) y(numLine) z(numLine)]; 
                end                                
                
                % fit axes limits to extent of history data if desired
                if hFitAxesToHistCheckbox.Value || ...
                        hFitAxesToHistButton.UserData.clicked || ...
                        hFitAxesToTakeDataButton.UserData.clicked
                    % if fit to all data requested, use all data, not hist
                    if hFitAxesToTakeDataButton.UserData.clicked                        
                        hFitAxesToTakeDataButton.UserData.clicked = 0;
                        xHist = squeeze(frames(:,3,:))';
                        yHist = squeeze(frames(:,4,:))';
                        zHist = squeeze(frames(:,5,:))';
                    end                    
                    hFitAxesToHistButton.UserData.clicked = 0;                    
                    % Get history and exclude zeros
                    hist = [xHist(:), yHist(:), zHist(:)];                                                            
                    hist(hist==0) = nan;                    
                    % If desired, use only values below 99th percentile    
                    if hExcludeOutliersCheckbox.Value
                        hist(abs(hist)>=repmat(prctile(hist,99), size(hist,1), 1)) = nan;
                    end               
                    % compute and apply axes limits
                    if size(hist,1) > 1 && all(sum(~isnan(hist))>1)                                                                                                                                                                    
                        extrema = [min(hist); max(hist)];
                        span = diff(extrema);
                        center = extrema(1,:) + span/2;
                        maxSpan = max(span);
                        oneSide = (maxSpan/2 + maxSpan*0.025);
                        axLims = [center - oneSide; center + oneSide];
                        set(hAx, 'XLim', axLims(:,1), 'YLim', axLims(:,2), 'ZLim', axLims(:,3));
                    end                                                                                                                                    
                end
                
                previousFrame = curFrame;
                
            end                                
            
        end
        
        drawnow        
        
        % For changing take or loading new file
        if reload || hLoadButton.UserData.newFileLoaded
            delete(hAx.Children)
            break
        end            
        
    end
       
end


% in case an error occurs and streaming mode is running, allow user to save
% data before closing.
catch
    if dataIsStreamedData
        resp = ...
        questdlg(['Something went wrong or you closed the window instead ', ...
            'of hitting quit. Would you like to save ', ...
            'your streamed data before the application closes?'], ...
            'Error', 'Yes', 'No', 'Yes');
        if strcmp(resp, 'Yes')
           saveStreamedData(data, frames, nFrames, frameRate)
        end
    end
    try
        error('An error occurred. Sorry.')
        close(hFig);
    end 
end


end



%%%% Callbacks

function quit_cb(h,~)
h.UserData.wantQuit = 1;
end

function load_cb(h,~)

loadError = 0;

[f,p] = uigetfile({'*.vzp';'*.mat'});
filename = [p,f];
fl = length(filename);
if ~ischar(filename)
    loadError = 1;    
elseif strcmp(filename(fl-3:end),'.mat')
    data = load(filename);
    if ~(isfield(data,'data') && isstruct(data.data))
        loadError = 1;
        msgbox(['Loaded mat-file must contain data in a struct ''data'', ', ...
            'as output by function loadVzpFile.'],'Invalid data format')
    else
        disp('Loading data...')
    end
elseif strcmp(filename(fl-3:end),'.vzp')
    try
        data = loadVzpFile(filename);
        disp('Loading data...')
    catch        
        loadError = 1;
        msgbox(sprintf(['Error loading vzp-file.\n\nMake sure the following functions ', ...
            'are on your MATLAB path (letter cases intentional): \n\n', ...
            'VzpGetTakeCount\n', ...
            'vzpGetTakeMarkers\n', ...
            'vzpGetTakeFrames\n', ...
            'vzpGetMarkerName\n', ...
            'vzpgetmarkerID\n', ...
            'vzpGetFrameData\n', ...
            'vzpGetTakeFrameRate\n', ...
            'vzpGetTakeCRF']))
    end
end

if ~loadError
    h.UserData.data = data;
    h.UserData.newFileLoaded = 1;    
    set(findobj(h.Parent, 'tag', 'pauseButton'), 'enable', 'on');
    disp('Done')
else    
    h.UserData.newFileLoaded = 0;    
    disp('File could not be loaded.')
end

end

function fig_buttonUp_cb(h,~)
% Use figure button up to reset button down state of 3d axis.
hAx = findobj(h, 'tag', '3dAxes');
if hAx.UserData.buttonDown == 1
    hAx.UserData.buttonDown = 0;
end
end


function hAx_ButtonDownFcn(h,~)
h.UserData.buttonDown = 1;
end

function fitAxesToMarkersButton_cb(h,~)
h.UserData.clicked = 1;
end

function fitAxesToMarkersCheckbox_cb(h,~)
hcb = findobj(h.Parent, 'tag', 'fitToHistCheckbox');
hcb.Value = 0;
end

function fitAxesToHistCheckbox_cb(h,~)
mcb = findobj(h.Parent, 'tag', 'fitToMarkersCheckbox');
mcb.Value = 0;
end

function fitAxesToHistButton_cb(h,~)
h.UserData.clicked = 1;
end

function fitAxesToTakeDataButton_cb(h,~)
h.UserData.clicked = 1;
end

function fig_size_cb(h,~)

hFrameSlider = findobj(h, 'tag', 'frameSlider');
border = hFrameSlider.Position(1);
hFrameSlider.Position(3) = (h.Position(3) - border*2);

end

function frameSlider_preSet_cb(~,h)
if ~h.AffectedObject.UserData.settingFromCode
    h.AffectedObject.UserData.setElapsedTime = 1;
end
end

function streamCheckbox_cb(h, ~)

% test for presence of VzGetDat
if h.Value
    funPresent = 1;            
    try
        tmp = VzGetDat();                
    catch
        funPresent = 0;
    end    
    if ~funPresent
        warndlg('Call to VzGetDat failed. Make sure it is on your MATLAB path.', ...
            'VzGetDat not found');
        h.Value = 0;
        return
    end    
end

h.UserData.wasChecked = h.Value;
h.UserData.wasUnchecked = ~h.Value;    

sub = findobj(h.Parent,'tag','StreamingUpdateButton');
spb = findobj(h.Parent,'tag','StreamingPauseButton');
sdb = findobj(h.Parent,'tag','StreamingDiscardButton');
spm = findobj(h.Parent,'tag','speedMenu');
tkm = findobj(h.Parent,'tag','takeMenu');
fsd = findobj(h.Parent,'tag','frameSlider');
pbn = findobj(h.Parent,'tag','pauseButton');
lbn = findobj(h.Parent,'tag','loadButton');
idt = findobj(h.Parent.Parent,'tag','identicalDataText');

if h.UserData.wasChecked
    sub.Enable = 'off';
    spb.Enable = 'on';
    sdb.Enable = 'on';    
    spm.Enable = 'off';
    tkm.Value = 1;    
    tkm.String = {1};
    tkm.Enable = 'off';
    fsd.Enable = 'off';
    pbn.Enable = 'off';
    pbn.UserData = 0;
    pbn.Enable = 'off';
    lbn.Enable = 'off';    
elseif h.UserData.wasUnchecked
    sub.Enable = 'off';
    spb.Enable = 'off';
    sdb.Enable = 'off';    
    spm.Enable = 'on';
    tkm.Enable = 'on';
    fsd.Enable = 'on';
    pbn.Enable = 'on';
    lbn.Enable = 'on';  
    idt.Visible = 'off';
end   

end

function pause_cb(h, ~)
if h.UserData == 1
    h.UserData = 0;
    h.String = 'Pause';
elseif h.UserData == 0
    h.UserData = 1;
    h.String = 'Play';
end
end

function streamingPause_cb(h, ~)
sub = findobj(h.Parent,'tag','StreamingUpdateButton');
fs = findobj(h.Parent,'tag','frameSlider');
pb = findobj(h.Parent,'tag','pauseButton');
sm = findobj(h.Parent,'tag','speedMenu');
if h.UserData.active == 1
    h.UserData.active = 0;
    h.UserData.justDisabled = 1;
    h.UserData.justEnabled = 0;
    h.String = 'Pause live plot';        
    sub.Enable = 'off';    
    fs.Enable = 'off';
    pb.Enable = 'off';
    sm.Enable = 'off';
    pb.UserData = 1;
    pause_cb(pb,[]); 
elseif h.UserData.active == 0
    h.UserData.active = 1;
    h.UserData.justDisabled = 0;
    h.UserData.justEnabled = 1;
    h.String = 'Resume live plot';
    sub.Enable = 'on';
    fs.Enable = 'on';
    pb.Enable = 'on';
    sm.Enable = 'on';    
    pb.UserData = 0;
    pause_cb(pb,[]);    
end
end

function streamingUpdate_cb(h,~)
    h.UserData.wasClicked = 1;
end

function streamingDiscard_cb(h,~)
    h.UserData.wasClicked = 1;
end

function streamingSave_cb(h,~)
    h.UserData.wasClicked = 1;
end



%%%% Helper functions

function saveStreamedData(data, frames, nFrames, frameRate)
try        
    data(1).frames = frames;
    data(1).nFrames = nFrames;    
    data(1).frameRate = frameRate;        
    [f,p] = uiputfile('*.mat','Save streamed data');
    save([p,f],'data');    
catch
    disp('Could not save data.')
end
end

function mask = toBoolMask(linds, len)
% Helper fun to convert from linear indices to boolean mask for vector of
% length len.
mask = zeros(len,1);
mask(linds) = 1;
mask = logical(mask);
end

function T = relativeTimeStamps(frames,frameRate)
% Get frame time stamps relative to first frame, compensate for wrap-around
% of time stamps (occurs periodically).                               
        T = squeeze(frames(end,6,:)) - frames(end,6,1);        
        timeWrapInds = find(round(diff(T))<0)+1;
        for twInd = timeWrapInds'
            T(twInd:end) = T(twInd:end) - T(twInd) + T(twInd-1) + 1/frameRate;
        end        
end

function [data, maxWaitExc] = getDat(maxWait)
% stream one frame from trackers, as soon as full buffer update has occurred.
%
% maxWait is optional, default Inf.
% If maxWait (in seconds) is exceeded, the data obtained from VzGetDat is
% returned no matter whether the buffer was fully updated. In that case,
% maxWaitExc is set to 1 (else 0).

if nargin < 1
    maxWait = Inf;
end

tStart = tic;
while 1
    % get data
    tmpDat = VzGetDat;
    % check for buffer update, return if ok
    if bufferUpdateCheck(tmpDat)        
        maxWaitExc = 0;
        break;
    end
    % wait time exceeded
    if toc(tStart) > maxWait
        maxWaitExc = 1;        
        break
    end
end

data = tmpDat;

end

% FOR DEBUGGING. Replaces PTI's VzGetDat and streams random data.
%
% function data = VzGetDat()
% 
%     % Number of data changes per second (note that the round time of the
%     % MATLAB code of the visualizer will restrict the effective fps in any
%     % live-streaming setup).
%     desiredFps = 100;
% 
%     persistent startTime;
%     persistent t;
%     persistent lastTime;
%     persistent lastData;
%     
%     if isempty(startTime)
%         startTime = tic;
%         lastTime = tic;
%     end
% 
%     t = toc(startTime);
%     
% %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %     % ALTERNATIVELY TO CODE BELOW (UNCOMMENT THIS BLOCK): Return same data
% %     % each call after a few seconds.
% %     afterSecs = 5; % return differing data only for this many seconds
% %     persistent sameData
% %     persistent startTimeDiffData        
% %     if isempty(startTimeDiffData)
% %         startTimeDiffData = tic;
% %     end    
% %     if toc(startTimeDiffData) <= afterSecs || isempty(sameData) 
% %         t = toc(startTime);
% %         sameData = [rand(3,5), ones(3,1)*t, ones(3,1)];            
% %     end             
% %     data = sameData;
% %     return
% %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
%     
%     if toc(lastTime) > 1/desiredFps || isempty(lastData)
%         lastTime = tic;
%         data = [rand(3,5), ones(3,1) * t, ones(3,1)];
%         lastData = data;
%     else
%         data = [lastData(:,1:5),ones(3,1)*t,ones(3,1)];
%     end
% 
% end