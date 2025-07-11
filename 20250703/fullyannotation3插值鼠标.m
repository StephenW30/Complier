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