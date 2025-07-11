function interactiveLabelingTool()
    % File and display parameters
    matFilePath = ''; % Set your file path here
    bPlotInMm = 0;
    flipVertical = 1;
    pixelSizeMm = 0.1;
    waferSizeMM = 150;
    dim = waferSizeMM / pixelSizeMm;
    centerPixel = dim / 2;
    xMm = (1:dim - centerPixel - 0.5) * pixelSizeMm;
    yMm = (1:dim - centerPixel - 0.5) * pixelSizeMm;
    
    % Load data
    if isempty(matFilePath)
        error('Please set the matFilePath variable to your .mat file location');
    end
    
    data = load(matFilePath);
    if isfield(data, 'dw_image')
        rawMap = data.dw_image;
    else
        error('The file %s does not contain dw_image field.', matFilePath);
    end
    
    % Process data
    if flipVertical
        rawMap = flipud(rawMap);
    end
    
    % Store original data and create working copy
    originalMap = rawMap;
    originalMap(originalMap == 0 | originalMap == min(originalMap(:))) = NaN;
    workingMap = originalMap;
    
    % Initialize annotation mask and states
    annotationMask = false(size(originalMap));
    annotationEnabled = false;
    isRightClicking = false;
    isLeftClicking = false;
    brushSize = 1;  % Default brush size (1 pixel)
    operationHistory = {};  % Store history for undo functionality
    lastMousePos = [NaN, NaN];  % Track last mouse position for interpolation
    
    % Calculate valid data for percentile calculations
    validData = originalMap(~isnan(originalMap));
    
    % Create figure with custom size
    fig = figure('Position', [50, 50, 1400, 700]);
    clf;
    
    % Create left axes for Original Image + Red Annotations
    ax_left = axes('Position', [0.05, 0.2, 0.4, 0.7]);
    
    % Create right axes for Annotation Mask
    ax_right = axes('Position', [0.5, 0.2, 0.4, 0.7]);
    
    % Initial plot for left side (Original Image)
    if bPlotInMm
        h_img_left = imagesc(ax_left, xMm, yMm, workingMap);
        xlabel(ax_left, 'X (mm)'); 
        ylabel(ax_left, 'Y (mm)');
        axis(ax_left, [-waferSizeMM/2, waferSizeMM/2, -waferSizeMM/2, waferSizeMM/2]);
        
        h_img_right = imagesc(ax_right, xMm, yMm, double(annotationMask));
        xlabel(ax_right, 'X (mm)'); 
        ylabel(ax_right, 'Y (mm)');
        axis(ax_right, [-waferSizeMM/2, waferSizeMM/2, -waferSizeMM/2, waferSizeMM/2]);
    else
        h_img_left = imagesc(ax_left, workingMap);
        xlabel(ax_left, 'X (pixels)'); 
        ylabel(ax_left, 'Y (pixels)');
        axis(ax_left, [0, dim, 0, dim]);
        
        h_img_right = imagesc(ax_right, double(annotationMask));
        xlabel(ax_right, 'X (pixels)'); 
        ylabel(ax_right, 'Y (pixels)');
        axis(ax_right, [0, dim, 0, dim]);
    end
    
    % Set colormaps and properties
    colormap(ax_left, 'gray');  % Changed to gray as requested
    colormap(ax_right, 'gray');
    
    h_colorbar_left = colorbar(ax_left);
    h_colorbar_right = colorbar(ax_right);
    
    axis(ax_left, 'tight'); 
    axis(ax_left, 'equal'); 
    axis(ax_left, 'xy');
    title(ax_left, 'Original Image + Red Annotations');
    
    axis(ax_right, 'tight'); 
    axis(ax_right, 'equal'); 
    axis(ax_right, 'xy');
    title(ax_right, 'Annotation Mask');
    caxis(ax_right, [0 1]);  % Set color axis for binary mask display
    
    % Link the axes
    linkaxes([ax_left, ax_right], 'xy');
    
    % Create red overlay for annotations on left image
    hold(ax_left, 'on');
    % Create RGB red overlay data
    red_overlay_data = cat(3, ones(size(annotationMask)), ...
                             zeros(size(annotationMask)), ...
                             zeros(size(annotationMask)));
    h_overlay = imagesc(ax_left, 'XData', get(h_img_left, 'XData'), ...
                       'YData', get(h_img_left, 'YData'), ...
                       'CData', red_overlay_data, ...
                       'AlphaData', double(annotationMask) * 0.6);
    hold(ax_left, 'off');
    
    % Create sliders for percentile-based clipping
    % Low percentile slider (0-50%)
    uicontrol('Style', 'text', 'Position', [50, 150, 120, 20], ...
              'String', 'Low Clip Percentile:', 'FontSize', 10);
    h_low_slider = uicontrol('Style', 'slider', 'Position', [50, 130, 200, 20], ...
                            'Min', 0, 'Max', 50, 'Value', 0, ...
                            'Callback', @updateClipping);
    h_low_percent_text = uicontrol('Style', 'text', 'Position', [260, 130, 50, 20], ...
                                  'String', '0%', 'FontSize', 9);
    h_low_value_text = uicontrol('Style', 'text', 'Position', [310, 130, 80, 20], ...
                                'String', sprintf('%.3f', min(validData)), 'FontSize', 9);
    
    % High percentile slider (50-100%)
    uicontrol('Style', 'text', 'Position', [50, 100, 120, 20], ...
              'String', 'High Clip Percentile:', 'FontSize', 10);
    h_high_slider = uicontrol('Style', 'slider', 'Position', [50, 80, 200, 20], ...
                             'Min', 50, 'Max', 100, 'Value', 100, ...
                             'Callback', @updateClipping);
    h_high_percent_text = uicontrol('Style', 'text', 'Position', [260, 80, 50, 20], ...
                                   'String', '100%', 'FontSize', 9);
    h_high_value_text = uicontrol('Style', 'text', 'Position', [310, 80, 80, 20], ...
                                 'String', sprintf('%.3f', max(validData)), 'FontSize', 9);
    
    % Control buttons
    uicontrol('Style', 'pushbutton', 'Position', [50, 45, 60, 25], ...
              'String', 'Reset', 'Callback', @resetClipping);
    
    uicontrol('Style', 'pushbutton', 'Position', [120, 45, 80, 25], ...
              'String', 'Auto Scale', 'Callback', @autoScale);
    
    % Brush size controls
    uicontrol('Style', 'text', 'Position', [50, 15, 80, 20], ...
              'String', 'Brush Size:', 'FontSize', 10);
    h_brush_slider = uicontrol('Style', 'slider', 'Position', [50, 0, 100, 15], ...
                              'Min', 1, 'Max', 10, 'Value', brushSize, ...
                              'SliderStep', [1/9, 1/9], ...
                              'Callback', @updateBrushSize);
    h_brush_text = uicontrol('Style', 'text', 'Position', [155, 0, 30, 15], ...
                            'String', sprintf('%d', brushSize), 'FontSize', 9);
    
    % Sensitivity tip
    uicontrol('Style', 'text', 'Position', [200, 0, 200, 15], ...
              'String', 'Tip: Drag slowly for precise control', ...
              'FontSize', 8, 'ForegroundColor', [0.6 0.6 0.6]);
    
    % New annotation control buttons
    h_annotation_btn = uicontrol('Style', 'pushbutton', 'Position', [220, 45, 120, 25], ...
              'String', 'Enable Annotation', 'Callback', @toggleAnnotation, ...
              'BackgroundColor', [0.8 0.8 0.8]);
    
    % Status display
    h_status_text = uicontrol('Style', 'text', 'Position', [350, 15, 150, 20], ...
                             'String', 'Press ESC to cancel annotation', ...
                             'FontSize', 9, 'ForegroundColor', [0.5 0.5 0.5]);
    
    uicontrol('Style', 'pushbutton', 'Position', [350, 45, 60, 25], ...
              'String', 'Undo', 'Callback', @undoLastOperation);
    
    uicontrol('Style', 'pushbutton', 'Position', [420, 45, 60, 25], ...
              'String', 'Save', 'Callback', @saveMask);
    
    % Set up mouse callbacks
    set(fig, 'WindowButtonDownFcn', @mouseDown);
    set(fig, 'WindowButtonUpFcn', @mouseUp);
    set(fig, 'WindowButtonMotionFcn', @mouseMove);
    set(fig, 'KeyPressFcn', @keyPress);  % Add keyboard support
    
    % Add mouse enter/leave callbacks to left axes
    set(ax_left, 'ButtonDownFcn', @axesButtonDown);
    
    % Callback function for slider updates
    function updateClipping(~, ~)
        % Get current percentile values from sliders
        lowClipValue = get(h_low_slider, 'Value');
        highClipValue = get(h_high_slider, 'Value');
        
        % Ensure low <= high
        if lowClipValue >= highClipValue - 1
            if gcbo == h_low_slider
                lowClipValue = highClipValue - 1;
                set(h_low_slider, 'Value', lowClipValue);
            else
                highClipValue = lowClipValue + 1;
                set(h_high_slider, 'Value', highClipValue);
            end
        end
        
        % Calculate actual clipping values using percentiles
        validData = originalMap(~isnan(originalMap));
        lowClip = prctile(validData, lowClipValue);
        highClip = prctile(validData, highClipValue);
        
        % Store current axis limits to preserve zoom
        xlims = xlim(ax_left);
        ylims = ylim(ax_left);
        
        % Apply clipping
        workingMap = originalMap;
        workingMap(workingMap < lowClip) = lowClip;
        workingMap(workingMap > highClip) = highClip;
        
        % Update image data
        set(h_img_left, 'CData', workingMap);
        
        % Update colorbar limits
        caxis(ax_left, [lowClip, highClip]);
        
        % Restore axis limits to preserve zoom
        xlim(ax_left, xlims);
        ylim(ax_left, ylims);
        
        % Update text displays
        set(h_low_percent_text, 'String', sprintf('%.1f%%', lowClipValue));
        set(h_high_percent_text, 'String', sprintf('%.1f%%', highClipValue));
        set(h_low_value_text, 'String', sprintf('%.3f', lowClip));
        set(h_high_value_text, 'String', sprintf('%.3f', highClip));
    end
    
    % Reset function
    function resetClipping(~, ~)
        set(h_low_slider, 'Value', 5);
        set(h_high_slider, 'Value', 95);
        updateClipping();
    end
    
    % Auto scale function
    function autoScale(~, ~)
        set(h_low_slider, 'Value', 2);
        set(h_high_slider, 'Value', 98);
        updateClipping();
    end
    
    % Update brush size function
    function updateBrushSize(~, ~)
        brushSize = round(get(h_brush_slider, 'Value'));
        set(h_brush_text, 'String', sprintf('%d', brushSize));
    end
    
    % Toggle annotation function
    function toggleAnnotation(~, ~)
        annotationEnabled = ~annotationEnabled;
        if annotationEnabled
            set(h_annotation_btn, 'String', 'Disable Annotation', ...
                'BackgroundColor', [0.8 1.0 0.8]);
            set(h_status_text, 'String', 'Annotation ON - ESC to cancel', ...
                'ForegroundColor', [0 0.6 0]);
        else
            set(h_annotation_btn, 'String', 'Enable Annotation', ...
                'BackgroundColor', [0.8 0.8 0.8]);
            set(h_status_text, 'String', 'Annotation OFF', ...
                'ForegroundColor', [0.5 0.5 0.5]);
            % Reset any ongoing annotation states
            resetAnnotationStates();
        end
    end
    
    % Mouse down callback
    function mouseDown(src, ~)
        if ~annotationEnabled
            return;
        end
        
        % Get current point
        cp = get(gca, 'CurrentPoint');
        if gca ~= ax_left
            return;  % Only respond to clicks on left axes
        end
        
        % Check if zoom or pan is active (only if handles exist)
        if exist('h_zoom', 'var') && exist('h_pan', 'var')
            if strcmp(get(h_zoom, 'Enable'), 'on') || strcmp(get(h_pan, 'Enable'), 'on')
                return;  % Don't annotate if zoom/pan is active
            end
        end
        
        % Get mouse button
        selectionType = get(src, 'SelectionType');
        
        if strcmp(selectionType, 'normal')  % Left click
            % Save current state for undo
            saveCurrentState();
            
            % Start left clicking mode and add annotation
            isLeftClicking = true;
            lastMousePos = [cp(1,1), cp(1,2)];  % Record starting position
            addAnnotationAtPoint(cp(1,1), cp(1,2));
            
        elseif strcmp(selectionType, 'alt')  % Right click
            % Save current state for undo
            saveCurrentState();
            
            % Start erasing mode
            isRightClicking = true;
            lastMousePos = [cp(1,1), cp(1,2)];  % Record starting position
            eraseAnnotationAtPoint(cp(1,1), cp(1,2));
        end
    end
    
    % Axes-specific button down callback
    function axesButtonDown(~, ~)
        % This ensures we're definitely in the correct axes
        if gca == ax_left && annotationEnabled
            % Additional safety check
            if exist('h_zoom', 'var') && exist('h_pan', 'var')
                if strcmp(get(h_zoom, 'Enable'), 'on') || strcmp(get(h_pan, 'Enable'), 'on')
                    resetAnnotationStates();
                end
            end
        end
    end
    
    % Mouse up callback
    function mouseUp(~, ~)
        isRightClicking = false;
        isLeftClicking = false;
        lastMousePos = [NaN, NaN];  % Reset position tracking
    end
    
    % Mouse move callback
    function mouseMove(~, ~)
        if ~annotationEnabled
            return;
        end
        
        % Get current point
        currentAxes = gca;
        if currentAxes ~= ax_left
            % Mouse is outside the left axes - reset states
            resetAnnotationStates();
            return;
        end
        
        % Check if zoom or pan is active (only if handles exist)
        if exist('h_zoom', 'var') && exist('h_pan', 'var')
            if strcmp(get(h_zoom, 'Enable'), 'on') || strcmp(get(h_pan, 'Enable'), 'on')
                resetAnnotationStates();
                return;
            end
        end
        
        cp = get(currentAxes, 'CurrentPoint');
        currentPos = [cp(1,1), cp(1,2)];
        
        if isLeftClicking
            % Interpolate between last position and current position
            if ~isnan(lastMousePos(1)) && ~isnan(lastMousePos(2))
                interpolateAndAnnotate(lastMousePos, currentPos, @addAnnotationAtPoint);
            else
                addAnnotationAtPoint(currentPos(1), currentPos(2));
            end
            lastMousePos = currentPos;
            
        elseif isRightClicking
            % Interpolate between last position and current position
            if ~isnan(lastMousePos(1)) && ~isnan(lastMousePos(2))
                interpolateAndAnnotate(lastMousePos, currentPos, @eraseAnnotationAtPoint);
            else
                eraseAnnotationAtPoint(currentPos(1), currentPos(2));
            end
            lastMousePos = currentPos;
        end
    end
    
    % Interpolate between two points and apply annotation
    function interpolateAndAnnotate(startPos, endPos, annotateFunc)
        % Calculate distance between points
        dx = endPos(1) - startPos(1);
        dy = endPos(2) - startPos(2);
        distance = sqrt(dx^2 + dy^2);
        
        % Determine number of interpolation steps based on distance and brush size
        % Use smaller steps for better coverage
        stepSize = max(0.3, brushSize * 0.2);  % Smaller step size for smoother lines
        numSteps = max(1, ceil(distance / stepSize));
        
        % Interpolate points along the line
        for i = 0:numSteps
            t = i / numSteps;
            interpX = startPos(1) + t * dx;
            interpY = startPos(2) + t * dy;
            
            % Call annotation function without updating display
            if isequal(annotateFunc, @addAnnotationAtPoint)
                addAnnotationAtPoint(interpX, interpY, false);
            else
                eraseAnnotationAtPoint(interpX, interpY, false);
            end
        end
        
        % Update display once after all interpolation is done
        updateAnnotationDisplay();
    end
    
    % Reset annotation states
    function resetAnnotationStates(~, ~)
        isLeftClicking = false;
        isRightClicking = false;
        lastMousePos = [NaN, NaN];  % Reset position tracking
        % Update status if annotation is enabled
        if annotationEnabled && exist('h_status_text', 'var')
            set(h_status_text, 'String', 'Annotation ON - ESC to cancel', ...
                'ForegroundColor', [0 0.6 0]);
        end
    end
    
    % Keyboard callback
    function keyPress(~, eventdata)
        if strcmp(eventdata.Key, 'escape')
            % ESC key to cancel current annotation
            resetAnnotationStates();
            if annotationEnabled && exist('h_status_text', 'var')
                set(h_status_text, 'String', 'Annotation cancelled - ESC pressed', ...
                    'ForegroundColor', [0.8 0.4 0]);
                % Reset back to normal after 2 seconds
                timer_obj = timer('TimerFcn', @(~,~) set(h_status_text, 'String', 'Annotation ON - ESC to cancel', 'ForegroundColor', [0 0.6 0]), ...
                                 'StartDelay', 2, 'ExecutionMode', 'singleShot');
                start(timer_obj);
            end
        end
    end
    
    % Add annotation at specific point (optimized version)
    function addAnnotationAtPoint(x, y, updateDisplay)
        if nargin < 3
            updateDisplay = true;  % Default behavior
        end
        
        % Convert coordinates to array indices
        if bPlotInMm
            col = round((x - xMm(1)) / pixelSizeMm + 1);
            row = round((y - yMm(1)) / pixelSizeMm + 1);
        else
            col = round(x);
            row = round(y);
        end
        
        % Check bounds
        if row >= 1 && row <= size(annotationMask, 1) && ...
           col >= 1 && col <= size(annotationMask, 2)
            
            % Apply brush with adjustable size
            if brushSize == 1
                % Single pixel
                annotationMask(row, col) = true;
            else
                % Circular brush
                brush_radius = brushSize - 1;
                for dr = -brush_radius:brush_radius
                    for dc = -brush_radius:brush_radius
                        r = row + dr;
                        c = col + dc;
                        if r >= 1 && r <= size(annotationMask, 1) && ...
                           c >= 1 && c <= size(annotationMask, 2) && ...
                           sqrt(dr^2 + dc^2) <= brush_radius
                            annotationMask(r, c) = true;
                        end
                    end
                end
            end
            
            if updateDisplay
                updateAnnotationDisplay();
            end
        end
    end
    
    % Erase annotation at specific point (optimized version)
    function eraseAnnotationAtPoint(x, y, updateDisplay)
        if nargin < 3
            updateDisplay = true;  % Default behavior
        end
        
        % Convert coordinates to array indices
        if bPlotInMm
            col = round((x - xMm(1)) / pixelSizeMm + 1);
            row = round((y - yMm(1)) / pixelSizeMm + 1);
        else
            col = round(x);
            row = round(y);
        end
        
        % Check bounds
        if row >= 1 && row <= size(annotationMask, 1) && ...
           col >= 1 && col <= size(annotationMask, 2)
            
            % Apply eraser with adjustable size (slightly larger than brush)
            erase_radius = max(1, brushSize);
            if erase_radius == 1
                % Single pixel
                annotationMask(row, col) = false;
            else
                % Circular eraser
                for dr = -erase_radius:erase_radius
                    for dc = -erase_radius:erase_radius
                        r = row + dr;
                        c = col + dc;
                        if r >= 1 && r <= size(annotationMask, 1) && ...
                           c >= 1 && c <= size(annotationMask, 2) && ...
                           sqrt(dr^2 + dc^2) <= erase_radius
                            annotationMask(r, c) = false;
                        end
                    end
                end
            end
            
            if updateDisplay
                updateAnnotationDisplay();
            end
        end
    end
    
    % Update annotation display
    function updateAnnotationDisplay()
        % Update red overlay on left image (semi-transparent red mask)
        set(h_overlay, 'AlphaData', double(annotationMask) * 0.6);
        
        % Update annotation mask on right image (binary 0,1 display)
        set(h_img_right, 'CData', double(annotationMask));
        caxis(ax_right, [0 1]);  % Ensure proper contrast for binary mask
    end
    
    % Save current state for undo
    function saveCurrentState()
        operationHistory{end+1} = annotationMask;
        % Keep only last 20 operations to save memory
        if length(operationHistory) > 20
            operationHistory(1) = [];
        end
    end
    
    % Undo last operation
    function undoLastOperation(~, ~)
        if ~isempty(operationHistory)
            annotationMask = operationHistory{end};
            operationHistory(end) = [];
            updateAnnotationDisplay();
        end
    end
    
    % Save mask function
    function saveMask(~, ~)
        [filename, pathname] = uiputfile('*.mat', 'Save Annotation Mask');
        if filename ~= 0
            annotation_mask = annotationMask; %#ok<NASGU>
            save(fullfile(pathname, filename), 'annotation_mask');
            msgbox(['Mask saved as: ' fullfile(pathname, filename)], 'Save Complete');
        end
    end
    
    % Add zoom and pan functionality
    h_zoom = zoom(fig);
    h_pan = pan(fig);
    
    % Monitor zoom/pan tool state changes (move this after zoom/pan creation)
    set(h_zoom, 'ActionPreCallback', @resetAnnotationStates);
    set(h_pan, 'ActionPreCallback', @resetAnnotationStates);
    
    % Set initial clipping
    updateClipping();
    
    % Initialize display
    updateAnnotationDisplay();
end













classdef InteractiveLabelingApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        GridLayout                     matlab.ui.container.GridLayout
        LeftPanel                      matlab.ui.container.Panel
        RightPanel                     matlab.ui.container.Panel
        ControlPanel                   matlab.ui.container.Panel
        
        % Image display components
        OriginalImageAxes             matlab.ui.control.UIAxes
        AnnotationMaskAxes            matlab.ui.control.UIAxes
        
        % Control components
        LoadDataButton                matlab.ui.control.Button
        LowClipSlider                 matlab.ui.control.Slider
        LowClipSliderLabel            matlab.ui.control.Label
        LowPercentLabel               matlab.ui.control.Label
        LowValueLabel                 matlab.ui.control.Label
        HighClipSlider                matlab.ui.control.Slider
        HighClipSliderLabel           matlab.ui.control.Label
        HighPercentLabel              matlab.ui.control.Label
        HighValueLabel                matlab.ui.control.Label
        ResetButton                   matlab.ui.control.Button
        AutoScaleButton               matlab.ui.control.Button
        BrushSizeSlider               matlab.ui.control.Slider
        BrushSizeSliderLabel          matlab.ui.control.Label
        BrushSizeLabel                matlab.ui.control.Label
        AnnotationButton              matlab.ui.control.Button
        StatusLabel                   matlab.ui.control.Label
        UndoButton                    matlab.ui.control.Button
        SaveButton                    matlab.ui.control.Button
        TipLabel                      matlab.ui.control.Label
        
        % Plot settings
        PlotInMmCheckBox              matlab.ui.control.CheckBox
        FlipVerticalCheckBox          matlab.ui.control.CheckBox
        PixelSizeEditField            matlab.ui.control.NumericEditField
        PixelSizeEditFieldLabel       matlab.ui.control.Label
        WaferSizeEditField            matlab.ui.control.NumericEditField
        WaferSizeEditFieldLabel       matlab.ui.control.Label
    end

    % Properties for data and state management
    properties (Access = private)
        % Data properties
        originalMap                   % Original image data
        workingMap                   % Current processed image data
        annotationMask               % Binary annotation mask
        validData                    % Valid data for percentile calculations
        
        % Display properties
        h_img_left                   % Handle to left image
        h_img_right                  % Handle to right image
        h_overlay                    % Handle to red overlay
        pixelSizeMm = 0.1           % Pixel size in mm
        waferSizeMM = 150           % Wafer size in mm
        dim                         % Image dimensions
        centerPixel                 % Center pixel coordinate
        xMm                         % X coordinates in mm
        yMm                         % Y coordinates in mm
        
        % Annotation state
        annotationEnabled = false   % Whether annotation mode is on
        isRightClicking = false     % Right mouse button state
        isLeftClicking = false      % Left mouse button state
        brushSize = 1               % Current brush size
        operationHistory = {}       % Undo history
        lastMousePos = [NaN, NaN]   % Last mouse position for interpolation
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1400 900];
            app.UIFigure.Name = 'Interactive Labeling Tool';
            app.UIFigure.WindowButtonDownFcn = createCallbackFcn(app, @UIFigureWindowButtonDown, true);
            app.UIFigure.WindowButtonUpFcn = createCallbackFcn(app, @UIFigureWindowButtonUp, true);
            app.UIFigure.WindowButtonMotionFcn = createCallbackFcn(app, @UIFigureWindowButtonMotion, true);
            app.UIFigure.WindowKeyPressFcn = createCallbackFcn(app, @UIFigureWindowKeyPress, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidths = {'1x', '1x', '300px'};
            app.GridLayout.RowHeights = {'1x'};

            % Create Left Panel for Original Image
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Title = 'Original Image + Red Annotations';
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create Right Panel for Annotation Mask
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Title = 'Annotation Mask';
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;

            % Create Control Panel
            app.ControlPanel = uipanel(app.GridLayout);
            app.ControlPanel.Title = 'Controls';
            app.ControlPanel.Layout.Row = 1;
            app.ControlPanel.Layout.Column = 3;

            % Create axes for image display
            app.OriginalImageAxes = uiaxes(app.LeftPanel);
            app.OriginalImageAxes.Position = [10 10 app.LeftPanel.Position(3)-20 app.LeftPanel.Position(4)-40];
            app.OriginalImageAxes.ButtonDownFcn = createCallbackFcn(app, @OriginalImageAxesButtonDown, true);

            app.AnnotationMaskAxes = uiaxes(app.RightPanel);
            app.AnnotationMaskAxes.Position = [10 10 app.RightPanel.Position(3)-20 app.RightPanel.Position(4)-40];

            % Create control components in Control Panel
            yPos = 850;
            spacing = 35;

            % Load Data Button
            app.LoadDataButton = uibutton(app.ControlPanel, 'push');
            app.LoadDataButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDataButtonPushed, true);
            app.LoadDataButton.Position = [10 yPos 120 25];
            app.LoadDataButton.Text = 'Load Data';

            yPos = yPos - spacing;

            % Plot settings
            app.PlotInMmCheckBox = uicheckbox(app.ControlPanel);
            app.PlotInMmCheckBox.ValueChangedFcn = createCallbackFcn(app, @PlotInMmCheckBoxValueChanged, true);
            app.PlotInMmCheckBox.Text = 'Plot in mm';
            app.PlotInMmCheckBox.Position = [10 yPos 100 22];

            yPos = yPos - spacing;

            app.FlipVerticalCheckBox = uicheckbox(app.ControlPanel);
            app.FlipVerticalCheckBox.ValueChangedFcn = createCallbackFcn(app, @FlipVerticalCheckBoxValueChanged, true);
            app.FlipVerticalCheckBox.Text = 'Flip Vertical';
            app.FlipVerticalCheckBox.Position = [10 yPos 100 22];
            app.FlipVerticalCheckBox.Value = true;

            yPos = yPos - spacing;

            % Pixel size
            app.PixelSizeEditFieldLabel = uilabel(app.ControlPanel);
            app.PixelSizeEditFieldLabel.Position = [10 yPos 80 22];
            app.PixelSizeEditFieldLabel.Text = 'Pixel Size (mm)';

            app.PixelSizeEditField = uieditfield(app.ControlPanel, 'numeric');
            app.PixelSizeEditField.ValueChangedFcn = createCallbackFcn(app, @PixelSizeEditFieldValueChanged, true);
            app.PixelSizeEditField.Position = [100 yPos 50 22];
            app.PixelSizeEditField.Value = 0.1;

            yPos = yPos - spacing;

            % Wafer size
            app.WaferSizeEditFieldLabel = uilabel(app.ControlPanel);
            app.WaferSizeEditFieldLabel.Position = [10 yPos 80 22];
            app.WaferSizeEditFieldLabel.Text = 'Wafer Size (mm)';

            app.WaferSizeEditField = uieditfield(app.ControlPanel, 'numeric');
            app.WaferSizeEditField.ValueChangedFcn = createCallbackFcn(app, @WaferSizeEditFieldValueChanged, true);
            app.WaferSizeEditField.Position = [100 yPos 50 22];
            app.WaferSizeEditField.Value = 150;

            yPos = yPos - spacing;

            % Low percentile clipping
            app.LowClipSliderLabel = uilabel(app.ControlPanel);
            app.LowClipSliderLabel.Position = [10 yPos 120 22];
            app.LowClipSliderLabel.Text = 'Low Clip Percentile:';

            yPos = yPos - 25;

            app.LowClipSlider = uislider(app.ControlPanel);
            app.LowClipSlider.Limits = [0 50];
            app.LowClipSlider.ValueChangedFcn = createCallbackFcn(app, @LowClipSliderValueChanged, true);
            app.LowClipSlider.Position = [10 yPos 180 3];
            app.LowClipSlider.Value = 0;

            app.LowPercentLabel = uilabel(app.ControlPanel);
            app.LowPercentLabel.Position = [200 yPos-10 40 22];
            app.LowPercentLabel.Text = '0%';

            app.LowValueLabel = uilabel(app.ControlPanel);
            app.LowValueLabel.Position = [245 yPos-10 50 22];
            app.LowValueLabel.Text = '0.000';

            yPos = yPos - spacing;

            % High percentile clipping
            app.HighClipSliderLabel = uilabel(app.ControlPanel);
            app.HighClipSliderLabel.Position = [10 yPos 120 22];
            app.HighClipSliderLabel.Text = 'High Clip Percentile:';

            yPos = yPos - 25;

            app.HighClipSlider = uislider(app.ControlPanel);
            app.HighClipSlider.Limits = [50 100];
            app.HighClipSlider.ValueChangedFcn = createCallbackFcn(app, @HighClipSliderValueChanged, true);
            app.HighClipSlider.Position = [10 yPos 180 3];
            app.HighClipSlider.Value = 100;

            app.HighPercentLabel = uilabel(app.ControlPanel);
            app.HighPercentLabel.Position = [200 yPos-10 40 22];
            app.HighPercentLabel.Text = '100%';

            app.HighValueLabel = uilabel(app.ControlPanel);
            app.HighValueLabel.Position = [245 yPos-10 50 22];
            app.HighValueLabel.Text = '1.000';

            yPos = yPos - spacing;

            % Reset and Auto Scale buttons
            app.ResetButton = uibutton(app.ControlPanel, 'push');
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonPushed, true);
            app.ResetButton.Position = [10 yPos 60 25];
            app.ResetButton.Text = 'Reset';

            app.AutoScaleButton = uibutton(app.ControlPanel, 'push');
            app.AutoScaleButton.ButtonPushedFcn = createCallbackFcn(app, @AutoScaleButtonPushed, true);
            app.AutoScaleButton.Position = [80 yPos 80 25];
            app.AutoScaleButton.Text = 'Auto Scale';

            yPos = yPos - spacing;

            % Brush size
            app.BrushSizeSliderLabel = uilabel(app.ControlPanel);
            app.BrushSizeSliderLabel.Position = [10 yPos 80 22];
            app.BrushSizeSliderLabel.Text = 'Brush Size:';

            yPos = yPos - 25;

            app.BrushSizeSlider = uislider(app.ControlPanel);
            app.BrushSizeSlider.Limits = [1 10];
            app.BrushSizeSlider.ValueChangedFcn = createCallbackFcn(app, @BrushSizeSliderValueChanged, true);
            app.BrushSizeSlider.Position = [10 yPos 100 3];
            app.BrushSizeSlider.Value = 1;

            app.BrushSizeLabel = uilabel(app.ControlPanel);
            app.BrushSizeLabel.Position = [120 yPos-10 30 22];
            app.BrushSizeLabel.Text = '1';

            yPos = yPos - spacing;

            % Tip label
            app.TipLabel = uilabel(app.ControlPanel);
            app.TipLabel.Position = [10 yPos 200 22];
            app.TipLabel.Text = 'Tip: Drag slowly for precise control';
            app.TipLabel.FontColor = [0.6 0.6 0.6];

            yPos = yPos - spacing;

            % Annotation control
            app.AnnotationButton = uibutton(app.ControlPanel, 'push');
            app.AnnotationButton.ButtonPushedFcn = createCallbackFcn(app, @AnnotationButtonPushed, true);
            app.AnnotationButton.Position = [10 yPos 120 25];
            app.AnnotationButton.Text = 'Enable Annotation';

            yPos = yPos - spacing;

            % Status label
            app.StatusLabel = uilabel(app.ControlPanel);
            app.StatusLabel.Position = [10 yPos 200 22];
            app.StatusLabel.Text = 'Press ESC to cancel annotation';
            app.StatusLabel.FontColor = [0.5 0.5 0.5];

            yPos = yPos - spacing;

            % Undo and Save buttons
            app.UndoButton = uibutton(app.ControlPanel, 'push');
            app.UndoButton.ButtonPushedFcn = createCallbackFcn(app, @UndoButtonPushed, true);
            app.UndoButton.Position = [10 yPos 60 25];
            app.UndoButton.Text = 'Undo';

            app.SaveButton = uibutton(app.ControlPanel, 'push');
            app.SaveButton.ButtonPushedFcn = createCallbackFcn(app, @SaveButtonPushed, true);
            app.SaveButton.Position = [80 yPos 60 25];
            app.SaveButton.Text = 'Save';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = InteractiveLabelingApp

            % Create UIFigure and components
            createComponents(app);

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end

    % Callback methods
    methods (Access = private)

        % Button pushed function: LoadDataButton
        function LoadDataButtonPushed(app, event)
            [filename, pathname] = uigetfile('*.mat', 'Select .mat file containing dw_image');
            if filename ~= 0
                try
                    data = load(fullfile(pathname, filename));
                    if isfield(data, 'dw_image')
                        app.originalMap = data.dw_image;
                        initializeData(app);
                        updateDisplay(app);
                        app.StatusLabel.Text = 'Data loaded successfully';
                        app.StatusLabel.FontColor = [0 0.6 0];
                    else
                        uialert(app.UIFigure, 'The file does not contain dw_image field.', 'Error');
                    end
                catch ME
                    uialert(app.UIFigure, ['Error loading file: ' ME.message], 'Error');
                end
            end
        end

        % Value changed function: PlotInMmCheckBox
        function PlotInMmCheckBoxValueChanged(app, event)
            updateDisplay(app);
        end

        % Value changed function: FlipVerticalCheckBox
        function FlipVerticalCheckBoxValueChanged(app, event)
            if ~isempty(app.originalMap)
                initializeData(app);
                updateDisplay(app);
            end
        end

        % Value changed function: PixelSizeEditField
        function PixelSizeEditFieldValueChanged(app, event)
            app.pixelSizeMm = app.PixelSizeEditField.Value;
            if ~isempty(app.originalMap)
                calculateCoordinates(app);
                updateDisplay(app);
            end
        end

        % Value changed function: WaferSizeEditField
        function WaferSizeEditFieldValueChanged(app, event)
            app.waferSizeMM = app.WaferSizeEditField.Value;
            if ~isempty(app.originalMap)
                calculateCoordinates(app);
                updateDisplay(app);
            end
        end

        % Value changed function: LowClipSlider
        function LowClipSliderValueChanged(app, event)
            updateClipping(app);
        end

        % Value changed function: HighClipSlider
        function HighClipSliderValueChanged(app, event)
            updateClipping(app);
        end

        % Button pushed function: ResetButton
        function ResetButtonPushed(app, event)
            app.LowClipSlider.Value = 5;
            app.HighClipSlider.Value = 95;
            updateClipping(app);
        end

        % Button pushed function: AutoScaleButton
        function AutoScaleButtonPushed(app, event)
            app.LowClipSlider.Value = 2;
            app.HighClipSlider.Value = 98;
            updateClipping(app);
        end

        % Value changed function: BrushSizeSlider
        function BrushSizeSliderValueChanged(app, event)
            app.brushSize = round(app.BrushSizeSlider.Value);
            app.BrushSizeLabel.Text = sprintf('%d', app.brushSize);
        end

        % Button pushed function: AnnotationButton
        function AnnotationButtonPushed(app, event)
            app.annotationEnabled = ~app.annotationEnabled;
            if app.annotationEnabled
                app.AnnotationButton.Text = 'Disable Annotation';
                app.AnnotationButton.BackgroundColor = [0.8 1.0 0.8];
                app.StatusLabel.Text = 'Annotation ON - ESC to cancel';
                app.StatusLabel.FontColor = [0 0.6 0];
            else
                app.AnnotationButton.Text = 'Enable Annotation';
                app.AnnotationButton.BackgroundColor = [0.94 0.94 0.94];
                app.StatusLabel.Text = 'Annotation OFF';
                app.StatusLabel.FontColor = [0.5 0.5 0.5];
                resetAnnotationStates(app);
            end
        end

        % Button pushed function: UndoButton
        function UndoButtonPushed(app, event)
            if ~isempty(app.operationHistory)
                app.annotationMask = app.operationHistory{end};
                app.operationHistory(end) = [];
                updateAnnotationDisplay(app);
            end
        end

        % Button pushed function: SaveButton
        function SaveButtonPushed(app, event)
            [filename, pathname] = uiputfile('*.mat', 'Save Annotation Mask');
            if filename ~= 0
                annotation_mask = app.annotationMask; %#ok<NASGU>
                save(fullfile(pathname, filename), 'annotation_mask');
                uialert(app.UIFigure, ['Mask saved as: ' fullfile(pathname, filename)], 'Save Complete', 'Icon', 'success');
            end
        end

        % Mouse button down function
        function UIFigureWindowButtonDown(app, event)
            if ~app.annotationEnabled || isempty(app.originalMap)
                return;
            end

            % Check if click is on the original image axes
            cp = app.OriginalImageAxes.CurrentPoint;
            if isempty(cp)
                return;
            end

            % Save current state for undo
            saveCurrentState(app);

            % Get mouse button
            selectionType = app.UIFigure.SelectionType;

            if strcmp(selectionType, 'normal')  % Left click
                app.isLeftClicking = true;
                app.lastMousePos = [cp(1,1), cp(1,2)];
                addAnnotationAtPoint(app, cp(1,1), cp(1,2));
            elseif strcmp(selectionType, 'alt')  % Right click
                app.isRightClicking = true;
                app.lastMousePos = [cp(1,1), cp(1,2)];
                eraseAnnotationAtPoint(app, cp(1,1), cp(1,2));
            end
        end

        % Mouse button up function
        function UIFigureWindowButtonUp(app, event)
            app.isRightClicking = false;
            app.isLeftClicking = false;
            app.lastMousePos = [NaN, NaN];
        end

        % Mouse motion function
        function UIFigureWindowButtonMotion(app, event)
            if ~app.annotationEnabled || isempty(app.originalMap)
                return;
            end

            cp = app.OriginalImageAxes.CurrentPoint;
            if isempty(cp)
                resetAnnotationStates(app);
                return;
            end

            currentPos = [cp(1,1), cp(1,2)];

            if app.isLeftClicking
                if ~isnan(app.lastMousePos(1)) && ~isnan(app.lastMousePos(2))
                    interpolateAndAnnotate(app, app.lastMousePos, currentPos, true);
                else
                    addAnnotationAtPoint(app, currentPos(1), currentPos(2));
                end
                app.lastMousePos = currentPos;
            elseif app.isRightClicking
                if ~isnan(app.lastMousePos(1)) && ~isnan(app.lastMousePos(2))
                    interpolateAndAnnotate(app, app.lastMousePos, currentPos, false);
                else
                    eraseAnnotationAtPoint(app, currentPos(1), currentPos(2));
                end
                app.lastMousePos = currentPos;
            end
        end

        % Key press function
        function UIFigureWindowKeyPress(app, event)
            if strcmp(event.Key, 'escape')
                resetAnnotationStates(app);
                if app.annotationEnabled
                    app.StatusLabel.Text = 'Annotation cancelled - ESC pressed';
                    app.StatusLabel.FontColor = [0.8 0.4 0];
                    % Reset back to normal after 2 seconds
                    pause(0.1);
                    timer('TimerFcn', @(~,~) resetStatusText(app), ...
                          'StartDelay', 2, 'ExecutionMode', 'singleShot').start();
                end
            end
        end

        % Axes button down function
        function OriginalImageAxesButtonDown(app, event)
            % This ensures proper focus on the axes
        end
    end

    % Helper methods
    methods (Access = private)

        function initializeData(app)
            if isempty(app.originalMap)
                return;
            end

            % Apply vertical flip if enabled
            if app.FlipVerticalCheckBox.Value
                app.originalMap = flipud(app.originalMap);
            end

            % Calculate coordinates
            calculateCoordinates(app);

            % Process data
            app.originalMap(app.originalMap == 0 | app.originalMap == min(app.originalMap(:))) = NaN;
            app.workingMap = app.originalMap;

            % Initialize annotation mask
            app.annotationMask = false(size(app.originalMap));

            % Calculate valid data for percentile calculations
            app.validData = app.originalMap(~isnan(app.originalMap));

            % Reset history
            app.operationHistory = {};
        end

        function calculateCoordinates(app)
            if isempty(app.originalMap)
                return;
            end

            app.dim = app.waferSizeMM / app.pixelSizeMm;
            app.centerPixel = app.dim / 2;
            app.xMm = (1:app.dim - app.centerPixel - 0.5) * app.pixelSizeMm;
            app.yMm = (1:app.dim - app.centerPixel - 0.5) * app.pixelSizeMm;
        end

        function updateDisplay(app)
            if isempty(app.originalMap)
                return;
            end

            cla(app.OriginalImageAxes);
            cla(app.AnnotationMaskAxes);

            % Plot original image
            if app.PlotInMmCheckBox.Value
                app.h_img_left = imagesc(app.OriginalImageAxes, app.xMm, app.yMm, app.workingMap);
                app.OriginalImageAxes.XLabel.String = 'X (mm)';
                app.OriginalImageAxes.YLabel.String = 'Y (mm)';
                axis(app.OriginalImageAxes, [-app.waferSizeMM/2, app.waferSizeMM/2, -app.waferSizeMM/2, app.waferSizeMM/2]);

                app.h_img_right = imagesc(app.AnnotationMaskAxes, app.xMm, app.yMm, double(app.annotationMask));
                app.AnnotationMaskAxes.XLabel.String = 'X (mm)';
                app.AnnotationMaskAxes.YLabel.String = 'Y (mm)';
                axis(app.AnnotationMaskAxes, [-app.waferSizeMM/2, app.waferSizeMM/2, -app.waferSizeMM/2, app.waferSizeMM/2]);
            else
                app.h_img_left = imagesc(app.OriginalImageAxes, app.workingMap);
                app.OriginalImageAxes.XLabel.String = 'X (pixels)';
                app.OriginalImageAxes.YLabel.String = 'Y (pixels)';
                axis(app.OriginalImageAxes, [0, app.dim, 0, app.dim]);

                app.h_img_right = imagesc(app.AnnotationMaskAxes, double(app.annotationMask));
                app.AnnotationMaskAxes.XLabel.String = 'X (pixels)';
                app.AnnotationMaskAxes.YLabel.String = 'Y (pixels)';
                axis(app.AnnotationMaskAxes, [0, app.dim, 0, app.dim]);
            end

            % Set colormaps and properties
            colormap(app.OriginalImageAxes, 'gray');
            colormap(app.AnnotationMaskAxes, 'gray');

            axis(app.OriginalImageAxes, 'tight');
            axis(app.OriginalImageAxes, 'equal');
            axis(app.OriginalImageAxes, 'xy');

            axis(app.AnnotationMaskAxes, 'tight');
            axis(app.AnnotationMaskAxes, 'equal');
            axis(app.AnnotationMaskAxes, 'xy');
            clim(app.AnnotationMaskAxes, [0 1]);

            % Create red overlay for annotations
            hold(app.OriginalImageAxes, 'on');
            red_overlay_data = cat(3, ones(size(app.annotationMask)), ...
                                     zeros(size(app.annotationMask)), ...
                                     zeros(size(app.annotationMask)));
            app.h_overlay = imagesc(app.OriginalImageAxes, 'XData', get(app.h_img_left, 'XData'), ...
                           'YData', get(app.h_img_left, 'YData'), ...
                           'CData', red_overlay_data, ...
                           'AlphaData', double(app.annotationMask) * 0.6);
            hold(app.OriginalImageAxes, 'off');

            % Link axes
            linkaxes([app.OriginalImageAxes, app.AnnotationMaskAxes], 'xy');

            % Update clipping
            updateClipping(app);
        end

        function updateClipping(app)
            if isempty(app.validData)
                return;
            end

            % Get percentile values
            lowClipValue = app.LowClipSlider.Value;
            highClipValue = app.HighClipSlider.Value;

            % Ensure low <= high
            if lowClipValue >= highClipValue - 1
                if app.LowClipSlider == event.Source
                    lowClipValue = highClipValue - 1;
                    app.LowClipSlider.Value = lowClipValue;
                else
                    highClipValue = lowClipValue + 1;
                    app.HighClipSlider.Value = highClipValue;
                end
            end

            % Calculate clipping values
            lowClip = prctile(app.validData, lowClipValue);
            highClip = prctile(app.validData, highClipValue);

            % Apply clipping
            app.workingMap = app.originalMap;
            app.workingMap(app.workingMap < lowClip) = lowClip;
            app.workingMap(app.workingMap > highClip) = highClip;

            % Update image data
            if ~isempty(app.h_img_left) && isvalid(app.h_img_left)
                set(app.h_img_left, 'CData', app.workingMap);
                clim(app.OriginalImageAxes, [lowClip, highClip]);
            end

            % Update text displays
            app.LowPercentLabel.Text = sprintf('%.1f%%', lowClipValue);
            app.HighPercentLabel.Text = sprintf('%.1f%%', highClipValue);
            app.LowValueLabel.Text = sprintf('%.3f', lowClip);
            app.HighValueLabel.Text = sprintf('%.3f', highClip);
        end

        function resetAnnotationStates(app)
            app.isLeftClicking = false;
            app.isRightClicking = false;
            app.lastMousePos = [NaN, NaN];
        end

        function resetStatusText(app)
            if app.annotationEnabled
                app.StatusLabel.Text = 'Annotation ON - ESC to cancel';
                app.StatusLabel.FontColor = [0 0.6 0];
            end
        end

        function interpolateAndAnnotate(app, startPos, endPos, isAdding)
            % Calculate distance between points
            dx = endPos(1) - startPos(1);
            dy = endPos(2) - startPos(2);
            distance = sqrt(dx^2 + dy^2);

            % Determine number of interpolation steps
            stepSize = max(0.3, app.brushSize * 0.2);
            numSteps = max(1, ceil(distance / stepSize));

            % Interpolate points along the line
            for i = 0:numSteps
                t = i / numSteps;
                interpX = startPos(1) + t * dx;
                interpY = startPos(2) + t * dy;

                if isAdding
                    addAnnotationAtPoint(app, interpX, interpY, false);
                else
                    eraseAnnotationAtPoint(app, interpX, interpY, false);
                end
            end

            updateAnnotationDisplay(app);
        end

        function addAnnotationAtPoint(app, x, y, updateDisplay)
            if nargin < 4
                updateDisplay = true;
            end

            % Convert coordinates to array indices
            if app.PlotInMmCheckBox.Value
                col = round((x - app.xMm(1)) / app.pixelSizeMm + 1);
                row = round((y - app.yMm(1)) / app.pixelSizeMm + 1);
            else
                col = round(x);
                row = round(y);
            end

            % Check bounds
            if row >= 1 && row <= size(app.annotationMask, 1) && ...
               col >= 1 && col <= size(app.annotationMask, 2)

                % Apply brush
                if app.brushSize == 1
                    app.annotationMask(row, col) = true;
                else
                    brush_radius = app.brushSize - 1;
                    for dr = -brush_radius:brush_radius
                        for dc = -brush_radius:brush_radius
                            r = row + dr;
                            c = col + dc;
                            if r >= 1 && r <= size(app.annotationMask, 1) && ...
                               c >= 1 && c <= size(app.annotationMask, 2) && ...
                               sqrt(dr^2 + dc^2) <= brush_radius
                                app.annotationMask(r, c) = true;
                            end
                        end
                    end
                end

                if updateDisplay
                    updateAnnotationDisplay(app);
                end
            end
        end

        function eraseAnnotationAtPoint(app, x, y, updateDisplay)
            if nargin < 4
                updateDisplay = true;
            end

            % Convert coordinates to array indices
            if app.PlotInMmCheckBox.Value
                col = round((x - app.xMm(1)) / app.pixelSizeMm + 1);
                row = round((y - app.yMm(1)) / app.pixelSizeMm + 1);
            else
                col = round(x);
                row = round(y);
            end

            % Check bounds
            if row >= 1 && row <= size(app.annotationMask, 1) && ...
               col >= 1 && col <= size(app.annotationMask, 2)

                % Apply eraser
                erase_radius = max(1, app.brushSize);
                if erase_radius == 1
                    app.annotationMask(row, col) = false;
                else
                    for dr = -erase_radius:erase_radius
                        for dc = -erase_radius:erase_radius
                            r = row + dr;
                            c = col + dc;
                            if r >= 1 && r <= size(app.annotationMask, 1) && ...
                               c >= 1 && c <= size(app.annotationMask, 2) && ...
                               sqrt(dr^2 + dc^2) <= erase_radius
                                app.annotationMask(r, c) = false;
                            end
                        end
                    end
                end

                if updateDisplay
                    updateAnnotationDisplay(app);
                end
            end
        end

        function updateAnnotationDisplay(app)
            % Update red overlay on left image
            if ~isempty(app.h_overlay) && isvalid(app.h_overlay)
                set(app.h_overlay, 'AlphaData', double(app.annotationMask) * 0.6);
            end

            % Update annotation mask on right image
            if ~isempty(app.h_img_right) && isvalid(app.h_img_right)
                set(app.h_img_right, 'CData', double(app.annotationMask));
                clim(app.AnnotationMaskAxes, [0 1]);
            end
        end

        function saveCurrentState(app)
            app.operationHistory{end+1} = app.annotationMask;
            % Keep only last 20 operations to save memory
            if length(app.operationHistory) > 20
                app.operationHistory(1) = [];
            end
        end
    end
end