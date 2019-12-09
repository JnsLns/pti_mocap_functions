function vzpVisualizer()
% function vzpVisualizer()
%
% Jonas Lins, December 2019.
%
% Visualization tool for motion capture data from PTI motion trackers. No
% arguments required. Allows streaming from trackers in realtime as well as
% loading vzp or mat file (as obtained from function loadVzpFile).

% NOTE: To debug streaming without a tracker connection uncomment the
% VzGetDat function replacement at the bottom of this file, which will
% "stream" random data points.

% Set up GUI etc.

secsPerDegreeRotation = 0.01; % rotation speed
histLen = 500; % initial history length in frames (plotted lines)
speeds = [0.1, 0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 4, 8, 16, 32];
markerBaseLineWidth = 0.5;

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
    'string', 'Pause playback', 'callback', @pause_cb, 'UserData', 0, 'tag', ...
    'pauseButton');

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

hFitAxesCheckbox = ...
    uicontrol(hFig, 'style', 'checkbox', 'units', 'pixels', ...
    'position', uiPos(1,8,hBorder,vBorder), 'String', 'Always fit axes ');

hFitAxesButton = ...
    uicontrol(hFig, 'style', 'pushbutton', 'units', 'pixels', ...
    'position', uiPos(1,9,hBorder,vBorder), ...
    'string', 'Fit axes to data', 'UserData', struct('clicked', 0), ...
    'callback', @fitAxes_cb);


hTakeMenu = ...
    uicontrol(hFig, 'style', 'popupmenu', 'units', 'pixels', ...
    'position', uiPos(1,16,hBorder,vBorder)./[1 1 3 1], ...
    'string', ' ');

hTakeText = ...
    uicontrol(hFig, 'style', 'text', 'units', 'pixels', ...
    'position', uiPos(2,16,hBorder,vBorder)./[3 1 1.5 1]+[sep*3 0 0 0], ...
    'string', 'Take', 'horizontalAlignment', 'left');

hLoadButton = ...
    uicontrol(hFig, 'style', 'pushbutton', 'units', 'pixels', ...
    'position', uiPos(1,17,hBorder,vBorder), ...
    'string', 'Load data file', 'callback', @load_cb, 'tooltip', ...
    ['Load *.vzp or *.mat file (the latter must contain data ', ...
    'in the format returned by loadVzpFile()).']);
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

while 1    
    
    % when streaming disabled, reset where applicable
    
    if hStreamCheckbox.UserData.wasUnchecked                
        hStreamCheckbox.UserData.wasUnchecked = 0;
        clearvars data;        
        hSpeedMenu.Enable = 'on';                        
        hTakeMenu.Enable = 'on';
        hFrameSlider.Enable = 'on';                        
        hPauseButton.Enable = 'on';        
        hLoadButton.Enable = 'on';         
    end
        
    % when streaming first enabled or restart of streaming requested, get
    % some sample data and construct data struct from that
    
    if hStreamCheckbox.UserData.wasChecked || ...
            hStreamingDiscardButton.UserData.wasClicked
        % if restart requested and streaming pause on -> disable pause
        if hStreamingPauseButton.UserData.active == 1
            hStreamingPauseButton.UserData.active = 1;
            streamingPause_cb(hStreamingPauseButton); % will disable
        end
        % reset click state of reset and checkbox
        hStreamingDiscardButton.UserData.wasClicked = 0;
        hStreamCheckbox.UserData.wasChecked = 0;
        data = struct();
        % Get some sample data (one sec, but at least five frames)                
        f = 0; sampleTime = 1; sampleStart = tic;
        tmpDat = [];
        while toc(sampleStart) < sampleTime || size(tmpDat,3) < 5 
            f = f + 1;
            tmpDat(:,:,f) = getDat();
        end                
        % compute needed values
        data(1).nFrames = f;                
        data(1).frameRate = f/sampleTime;                               
        data(1).nMarkers = size(tmpDat,1);        
        data(1).markerNames = cellstr(num2str(tmpDat(:,1:2,1)));
        data(1).markerIDs = tmpDat(:,1:2,1);
        data(1).crf = nan;
        % Set some UI variables                       
        take = 1;
        hSpeedMenu.Enable = 'off';
        speed = 1;
        hSpeedMenu.Value = find((speeds == 1));
        hTakeMenu.Value = 1;
        hTakeMenu.String = {1};
        hTakeMenu.Enable = 'off';
        hFrameSlider.Enable = 'off';                
        hPauseButton.UserData  = 0; % disable pause
        hPauseButton.Enable = 'off';        
        hLoadButton.Enable = 'off'; 
        % First few data points
        data(1).frames(:,:,1:5) = tmpDat(:,:,1:5);        
    end
    
    % Load file
    
    if hLoadButton.UserData.newFileLoaded
        hStreamCheckbox.Value = 0;        
        hLoadButton.UserData.newFileLoaded = 0;
        data = hLoadButton.UserData.data.data;
        take = 1;
        hTakeMenu.Value = take;        
        hFrameSlider.Max = data(1).nFrames;
        hFrameSlider.Value = 1;
        hFrameSlider.SliderStep = [1/data(1).nFrames 1/data(1).nFrames];        
        hTakeMenu.String = num2cell(1:size(data,2));
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
        
        % Set axes limit to min and max values occurring in data
        
        tmpFrames = frames;
        for i = 1:size(tmpFrames,3)
            bad = tmpFrames(:,7,i) ~= 1;
            tmpFrames(bad,:,i) = nan;
        end
        tmpFrames = tmpFrames(:,[3,4,5],:);
        tmpFrames = tmpFrames(:);
        minVal = min(tmpFrames);
        maxVal = max(tmpFrames);        
        set(hAx, 'XLim', [minVal maxVal],...
            'YLim', [minVal maxVal], 'ZLim', [minVal maxVal]);                                      
        
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
    frameLoopAvgRoundTime = 0; 
    frameLoopCounter = 0;
    frameLoopRoundTime = nan;
    tic    
    
    while 1
        
        frameLoopTic = tic; % to measure loop round time
        if frameLoopCounter > 0
            frameLoopAvgRoundTime = ...
                ((frameLoopAvgRoundTime * (frameLoopCounter-1)) + ...
                frameLoopRoundTime) / frameLoopCounter;
            frameLoopFps = 1/frameLoopAvgRoundTime;
        end
        
        % Initialize plots if streaming was enabled or disabled or restart
        % of streaming take requested
        if hStreamCheckbox.UserData.wasChecked || ...
           hStreamCheckbox.UserData.wasUnchecked || ...
           hStreamingDiscardButton.UserData.wasClicked
           delete(hAx.Children)    
           break;
        end
                
        % in case streaming is active
        if hStreamCheckbox.Value                                                            
            % Get frame from trackers (record even when paused)                        
            data(1).frames(:,:,end+1) = getDat();            
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
            % add frame loop round time, as this constrains the possible
            % frame rate at which data can be obtained from trackers (so
            % low tracker fps may not be due to tracker restrictions)
            if hStreamCheckbox.Value && ~hStreamingPauseButton.UserData.active
                hFrameText.String = [hFrameText.String, ...
                    ' (trackers queried @ ', num2str(frameLoopFps), 'fps)'];
            end
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
            
            % zoom to data if button clicked (onto median of data with axes
            % extension based on data span, plus 10 percent, identical for all
            % axes (i.e., always based on largest data span on any axis).
            % Disregard zero data.
            if hFitAxesCheckbox.Value || hFitAxesButton.UserData.clicked
                hFitAxesButton.UserData.clicked = 0;
                posTmp = frames(:,[3,4,5],curFrame);
                posTmp = posTmp(~all(posTmp==0,2),:);
                if ~isempty(posTmp)
                    center = mean(posTmp,1);
                    maxDist = ...
                        max(1, max(max(abs(posTmp - repmat(center,size(posTmp,1),1)))));
                    axLims = [center-(maxDist+maxDist*0.3); ...
                        center+(maxDist+maxDist*0.3)];
                    set(hAx, 'XLim', axLims(:,1), 'YLim', axLims(:,2), 'ZLim', axLims(:,3));
                end
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
                rowsMarkedGood = find(frame(:,7))';                     
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
                hDataTable.Data = [num2cell(frame(:,1:2)), ...
                    arrayfun(@(x) sprintf('%.4f\n',x), frame(:,3:6),'un',0), ...
                    num2cell(frame(:,7))];
                
                
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
                        hLabels(j) = text(hAx, ...                        
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
                                                
                previousFrame = curFrame;
                
            end                                
            
        end
        
        drawnow        
        
        % For changing take or loading new file
        if reload || hLoadButton.UserData.newFileLoaded
            delete(hAx.Children)
            break
        end    
        
        frameLoopCounter = frameLoopCounter + 1;
        frameLoopRoundTime = toc(frameLoopTic);
        
    end
       
end


% in case an error occurs and streaming mode is running, allow user to save
% data before closing.
catch
    if hStreamCheckbox.Value
        resp = ...
        questdlg(['Something went wrong. Would you like to save ', ...
            'your streamed data before the application closes?'], ...
            'Error', 'Yes', 'No', 'Yes');
        if strcmp(resp, 'Yes')
           saveStreamedData(data, frames, nFrames, frameRate)
        end
    end    
    close(hFig);
    error(['There was an error. Sorry! I''d appreciate if you would create', ...
        ' an issue at github.com/JnsLns/pti_mocap_functions, describing ', ...
        'what lead up to the crash. Thanks!'])    
end


end



%%%% Callbacks

function quit_cb(h,~)
h.UserData.wantQuit = 1;
end

function load_cb(h,~)

loadError = 0;

[f,p] = uigetfile({'*.mat','*.vzp'});
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
        msgbox('Error loading file.')
    end
end

if ~loadError
    h.UserData.data = data;
    h.UserData.newFileLoaded = 1;    
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

function fitAxes_cb(h,~)
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
h.UserData.wasChecked = h.Value;
h.UserData.wasUnchecked = ~h.Value;    
sub = findobj(h.Parent,'tag','StreamingUpdateButton');
spb = findobj(h.Parent,'tag','StreamingPauseButton');
sdb = findobj(h.Parent,'tag','StreamingDiscardButton');
ssb = findobj(h.Parent,'tag','hSaveStreamingButton');
if h.Value
    sub.Enable = 'off';
    spb.Enable = 'on';
    sdb.Enable = 'on';
    ssb.Enable = 'on';
else
    sub.Enable = 'on';
    spb.Enable = 'off';
    sdb.Enable = 'off';
    ssb.Enable = 'off';
end
if h.UserData.wasUnchecked
    sub.Enable = 'off';
end
end

function pause_cb(h, ~)
if h.UserData == 1
    h.UserData = 0;
    h.String = 'Pause playback';
elseif h.UserData == 0
    h.UserData = 1;
    h.String = 'Resume playback';
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

function data = getDat()
% stream one frame from trackers, as soon as full buffer update has occurred.
while 1
    tmpDat = VzGetDat;
    if bufferUpdateCheck(tmpDat)
        data = tmpDat;                
        break;
    end    
end
end

% FOR DEBUGGING. Replaces PTI's VzGetDat and streams random data.
%
function data = VzGetDat()

    % Number of data changes per second (note that the round time of the
    % MATLAB code of the visualizer will restrict the effective fps in any
    % live-streaming setup).
    desiredFps = 100;

    persistent startTime;
    persistent t;
    persistent lastTime;
    persistent lastData;

    if isempty(startTime)
        startTime = tic;
        lastTime = tic;
    end

    t = toc(startTime);
    if toc(lastTime) > 1/desiredFps || isempty(lastData)
        lastTime = tic;
        data = [rand(3,5), ones(3,1) * t, ones(3,1)];
        lastData = data;
    else
        data = [lastData(:,1:5),ones(3,1)*t,ones(3,1)];
    end

end