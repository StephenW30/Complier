function interactiveClipVisualization()
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
    
    % Calculate data range for sliders
    validData = originalMap(~isnan(originalMap));
    dataMin = min(validData);
    dataMax = max(validData);
    dataRange = dataMax - dataMin;
    
    % Create figure with custom size to accommodate sliders
    fig = figure('Position', [100, 100, 900, 700]);
    clf;
    
    % Create main axes for the image
    ax = axes('Position', [0.1, 0.2, 0.7, 0.7]);
    
    % Initial plot
    if bPlotInMm
        h_img = imagesc(ax, xMm, yMm, workingMap);
        xlabel(ax, 'X (mm)'); 
        ylabel(ax, 'Y (mm)');
        axis(ax, [-waferSizeMM/2, waferSizeMM/2, -waferSizeMM/2, waferSizeMM/2]);
    else
        h_img = imagesc(ax, workingMap);
        xlabel(ax, 'X (pixels)'); 
        ylabel(ax, 'Y (pixels)');
        axis(ax, [0, dim, 0, dim]);
    end
    
    colormap(ax, 'jet'); 
    h_colorbar = colorbar(ax);
    axis(ax, 'tight'); 
    axis(ax, 'equal'); 
    axis(ax, 'xy');
    title(ax, sprintf('Wafer Map: %s', matFilePath));
    
    % Create sliders
    % Min value slider
    uicontrol('Style', 'text', 'Position', [50, 100, 100, 20], ...
              'String', 'Min Clip Value:', 'FontSize', 10);
    h_min_slider = uicontrol('Style', 'slider', 'Position', [50, 80, 200, 20], ...
                            'Min', dataMin, 'Max', dataMax, 'Value', dataMin, ...
                            'Callback', @updateClipping);
    h_min_text = uicontrol('Style', 'text', 'Position', [260, 80, 80, 20], ...
                          'String', sprintf('%.3f', dataMin), 'FontSize', 9);
    
    % Max value slider
    uicontrol('Style', 'text', 'Position', [50, 50, 100, 20], ...
              'String', 'Max Clip Value:', 'FontSize', 10);
    h_max_slider = uicontrol('Style', 'slider', 'Position', [50, 30, 200, 20], ...
                            'Min', dataMin, 'Max', dataMax, 'Value', dataMax, ...
                            'Callback', @updateClipping);
    h_max_text = uicontrol('Style', 'text', 'Position', [260, 30, 80, 20], ...
                          'String', sprintf('%.3f', dataMax), 'FontSize', 9);
    
    % Reset button
    uicontrol('Style', 'pushbutton', 'Position', [50, 5, 60, 20], ...
              'String', 'Reset', 'Callback', @resetClipping);
    
    % Auto-scale button
    uicontrol('Style', 'pushbutton', 'Position', [120, 5, 80, 20], ...
              'String', 'Auto Scale', 'Callback', @autoScale);
    
    % Callback function for slider updates
    function updateClipping(~, ~)
        % Get current slider values
        minVal = get(h_min_slider, 'Value');
        maxVal = get(h_max_slider, 'Value');
        
        % Ensure min <= max
        if minVal >= maxVal
            if strcmp(get(gcbo, 'Style'), 'slider')
                if gcbo == h_min_slider
                    minVal = maxVal - dataRange * 0.01; % Small offset
                    set(h_min_slider, 'Value', minVal);
                else
                    maxVal = minVal + dataRange * 0.01; % Small offset
                    set(h_max_slider, 'Value', maxVal);
                end
            end
        end
        
        % Store current axis limits to preserve zoom
        xlims = xlim(ax);
        ylims = ylim(ax);
        
        % Apply clipping
        workingMap = originalMap;
        workingMap(workingMap < minVal) = minVal;
        workingMap(workingMap > maxVal) = maxVal;
        
        % Update image data
        set(h_img, 'CData', workingMap);
        
        % Update colorbar limits
        caxis(ax, [minVal, maxVal]);
        
        % Restore axis limits to preserve zoom
        xlim(ax, xlims);
        ylim(ax, ylims);
        
        % Update text displays
        set(h_min_text, 'String', sprintf('%.3f', minVal));
        set(h_max_text, 'String', sprintf('%.3f', maxVal));
    end
    
    % Reset function
    function resetClipping(~, ~)
        set(h_min_slider, 'Value', dataMin);
        set(h_max_slider, 'Value', dataMax);
        updateClipping();
    end
    
    % Auto-scale function (based on current visible data)
    function autoScale(~, ~)
        % Get current axis limits
        xlims = xlim(ax);
        ylims = ylim(ax);
        
        % Find visible data range
        if bPlotInMm
            xIndices = find(xMm >= xlims(1) & xMm <= xlims(2));
            yIndices = find(yMm >= ylims(1) & yMm <= ylims(2));
        else
            xIndices = max(1, floor(xlims(1))):min(size(originalMap, 2), ceil(xlims(2)));
            yIndices = max(1, floor(ylims(1))):min(size(originalMap, 1), ceil(ylims(2)));
        end
        
        if ~isempty(xIndices) && ~isempty(yIndices)
            visibleData = originalMap(yIndices, xIndices);
            validVisibleData = visibleData(~isnan(visibleData));
            
            if ~isempty(validVisibleData)
                newMin = min(validVisibleData);
                newMax = max(validVisibleData);
                
                set(h_min_slider, 'Value', newMin);
                set(h_max_slider, 'Value', newMax);
                updateClipping();
            end
        end
    end
    
    % Add zoom and pan functionality with preserved clipping
    zoom(fig, 'on');
    pan(fig, 'on');
    
    % Set initial clipping
    updateClipping();
end













function interactiveClipVisualization()
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
    
    % Calculate valid data for percentile calculations
    validData = originalMap(~isnan(originalMap));
    
    % Create figure with custom size to accommodate sliders
    fig = figure('Position', [100, 100, 900, 700]);
    clf;
    
    % Create main axes for the image
    ax = axes('Position', [0.1, 0.2, 0.7, 0.7]);
    
    % Initial plot
    if bPlotInMm
        h_img = imagesc(ax, xMm, yMm, workingMap);
        xlabel(ax, 'X (mm)'); 
        ylabel(ax, 'Y (mm)');
        axis(ax, [-waferSizeMM/2, waferSizeMM/2, -waferSizeMM/2, waferSizeMM/2]);
    else
        h_img = imagesc(ax, workingMap);
        xlabel(ax, 'X (pixels)'); 
        ylabel(ax, 'Y (pixels)');
        axis(ax, [0, dim, 0, dim]);
    end
    
    colormap(ax, 'jet'); 
    h_colorbar = colorbar(ax);
    axis(ax, 'tight'); 
    axis(ax, 'equal'); 
    axis(ax, 'xy');
    title(ax, sprintf('Wafer Map: %s', matFilePath));
    
    % Create sliders for percentile-based clipping
    % Low percentile slider (0-50%)
    uicontrol('Style', 'text', 'Position', [50, 120, 120, 20], ...
              'String', 'Low Clip Percentile:', 'FontSize', 10);
    h_low_slider = uicontrol('Style', 'slider', 'Position', [50, 100, 200, 20], ...
                            'Min', 0, 'Max', 50, 'Value', 0, ...
                            'Callback', @updateClipping);
    h_low_percent_text = uicontrol('Style', 'text', 'Position', [260, 100, 40, 20], ...
                                  'String', '0%', 'FontSize', 9);
    h_low_value_text = uicontrol('Style', 'text', 'Position', [310, 100, 80, 20], ...
                                'String', sprintf('%.3f', min(validData)), 'FontSize', 9);
    
    % High percentile slider (50-100%)
    uicontrol('Style', 'text', 'Position', [50, 70, 120, 20], ...
              'String', 'High Clip Percentile:', 'FontSize', 10);
    h_high_slider = uicontrol('Style', 'slider', 'Position', [50, 50, 200, 20], ...
                             'Min', 50, 'Max', 100, 'Value', 100, ...
                             'Callback', @updateClipping);
    h_high_percent_text = uicontrol('Style', 'text', 'Position', [260, 50, 40, 20], ...
                                   'String', '100%', 'FontSize', 9);
    h_high_value_text = uicontrol('Style', 'text', 'Position', [310, 50, 80, 20], ...
                                 'String', sprintf('%.3f', max(validData)), 'FontSize', 9);
    
    % Reset button
    uicontrol('Style', 'pushbutton', 'Position', [50, 5, 60, 20], ...
              'String', 'Reset', 'Callback', @resetClipping);
    
    % Auto-scale button
    uicontrol('Style', 'pushbutton', 'Position', [120, 5, 80, 20], ...
              'String', 'Auto Scale', 'Callback', @autoScale);
    
    % Callback function for slider updates
    function updateClipping(~, ~)
        % Get current percentile values from sliders
        lowClipValue = get(h_low_slider, 'Value');
        highClipValue = get(h_high_slider, 'Value');
        
        % Ensure low <= high
        if lowClipValue >= highClipValue - 1  % Keep at least 1% difference
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
        xlims = xlim(ax);
        ylims = ylim(ax);
        
        % Apply clipping
        workingMap = originalMap;
        workingMap(workingMap < lowClip) = lowClip;
        workingMap(workingMap > highClip) = highClip;
        
        % Update image data
        set(h_img, 'CData', workingMap);
        
        % Update colorbar limits
        caxis(ax, [lowClip, highClip]);
        
        % Restore axis limits to preserve zoom
        xlim(ax, xlims);
        ylim(ax, ylims);
        
        % Update text displays
        set(h_low_percent_text, 'String', sprintf('%.1f%%', lowClipValue));
        set(h_high_percent_text, 'String', sprintf('%.1f%%', highClipValue));
        set(h_low_value_text, 'String', sprintf('%.3f', lowClip));
        set(h_high_value_text, 'String', sprintf('%.3f', highClip));
    end
    
    % Reset function
    function resetClipping(~, ~)
        set(h_min_slider, 'Value', dataMin);
        set(h_max_slider, 'Value', dataMax);
        updateClipping();
    end
    
    % Auto-scale function (based on current visible data)
    function autoScale(~, ~)
        % Get current axis limits
        xlims = xlim(ax);
        ylims = ylim(ax);
        
        % Find visible data range
        if bPlotInMm
            xIndices = find(xMm >= xlims(1) & xMm <= xlims(2));
            yIndices = find(yMm >= ylims(1) & yMm <= ylims(2));
        else
            xIndices = max(1, floor(xlims(1))):min(size(originalMap, 2), ceil(xlims(2)));
            yIndices = max(1, floor(ylims(1))):min(size(originalMap, 1), ceil(ylims(2)));
        end
        
        if ~isempty(xIndices) && ~isempty(yIndices)
            visibleData = originalMap(yIndices, xIndices);
            validVisibleData = visibleData(~isnan(visibleData));
            
            if ~isempty(validVisibleData)
                newMin = min(validVisibleData);
                newMax = max(validVisibleData);
                
                set(h_min_slider, 'Value', newMin);
                set(h_max_slider, 'Value', newMax);
                updateClipping();
            end
        end
    end
    
    % Add zoom and pan functionality with preserved clipping
    zoom(fig, 'on');
    pan(fig, 'on');
    
    % Set initial clipping (no clipping initially)
    updateClipping();
end





、、、、、、、、、、、、、、、、、、、、、、、、、、、、、、、、、、
function interactiveClipVisualization()
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
    
    % Calculate valid data for percentile calculations
    validData = originalMap(~isnan(originalMap));
    
    % Create figure with custom size to accommodate sliders
    fig = figure('Position', [100, 100, 900, 700]);
    clf;
    
    % Create main axes for the image
    ax = axes('Position', [0.1, 0.2, 0.7, 0.7]);
    
    % Initial plot
    if bPlotInMm
        h_img = imagesc(ax, xMm, yMm, workingMap);
        xlabel(ax, 'X (mm)'); 
        ylabel(ax, 'Y (mm)');
        axis(ax, [-waferSizeMM/2, waferSizeMM/2, -waferSizeMM/2, waferSizeMM/2]);
    else
        h_img = imagesc(ax, workingMap);
        xlabel(ax, 'X (pixels)'); 
        ylabel(ax, 'Y (pixels)');
        axis(ax, [0, dim, 0, dim]);
    end
    
    colormap(ax, 'jet'); 
    h_colorbar = colorbar(ax);
    axis(ax, 'tight'); 
    axis(ax, 'equal'); 
    axis(ax, 'xy');
    title(ax, sprintf('Wafer Map: %s', matFilePath));
    
    % Create sliders for percentile-based clipping
    % Low percentile slider (0-50%)
    uicontrol('Style', 'text', 'Position', [50, 120, 120, 20], ...
              'String', 'Low Clip Percentile:', 'FontSize', 10);
    h_low_slider = uicontrol('Style', 'slider', 'Position', [50, 100, 200, 20], ...
                            'Min', 0, 'Max', 50, 'Value', 0, ...
                            'Callback', @updateClipping);
    h_low_percent_text = uicontrol('Style', 'text', 'Position', [260, 100, 40, 20], ...
                                  'String', '0%', 'FontSize', 9);
    h_low_value_text = uicontrol('Style', 'text', 'Position', [310, 100, 80, 20], ...
                                'String', sprintf('%.3f', min(validData)), 'FontSize', 9);
    
    % High percentile slider (50-100%)
    uicontrol('Style', 'text', 'Position', [50, 70, 120, 20], ...
              'String', 'High Clip Percentile:', 'FontSize', 10);
    h_high_slider = uicontrol('Style', 'slider', 'Position', [50, 50, 200, 20], ...
                             'Min', 50, 'Max', 100, 'Value', 100, ...
                             'Callback', @updateClipping);
    h_high_percent_text = uicontrol('Style', 'text', 'Position', [260, 50, 40, 20], ...
                                   'String', '100%', 'FontSize', 9);
    h_high_value_text = uicontrol('Style', 'text', 'Position', [310, 50, 80, 20], ...
                                 'String', sprintf('%.3f', max(validData)), 'FontSize', 9);
    
    % Reset button
    uicontrol('Style', 'pushbutton', 'Position', [50, 5, 60, 20], ...
              'String', 'Reset', 'Callback', @resetClipping);
    
    % Auto-scale button
    uicontrol('Style', 'pushbutton', 'Position', [120, 5, 80, 20], ...
              'String', 'Auto Scale', 'Callback', @autoScale);
    
    % Callback function for slider updates
    function updateClipping(~, ~)
        % Get current percentile values from sliders
        lowClipValue = get(h_low_slider, 'Value');
        highClipValue = get(h_high_slider, 'Value');
        
        % Ensure low <= high
        if lowClipValue >= highClipValue - 1  % Keep at least 1% difference
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
        
        fprintf('Clipping: %.1f%% (%.3f) to %.1f%% (%.3f)\n', ...
                lowClipValue, lowClip, highClipValue, highClip);
        
        % Store current axis limits to preserve zoom
        xlims = xlim(ax);
        ylims = ylim(ax);
        
        % Apply clipping
        workingMap = originalMap;
        workingMap(workingMap < lowClip) = lowClip;
        workingMap(workingMap > highClip) = highClip;
        
        % Update image data
        set(h_img, 'CData', workingMap);
        
        % Update colorbar limits
        caxis(ax, [lowClip, highClip]);
        
        % Restore axis limits to preserve zoom
        xlim(ax, xlims);
        ylim(ax, ylims);
        
        % Update text displays
        set(h_low_percent_text, 'String', sprintf('%.1f%%', lowClipValue));
        set(h_high_percent_text, 'String', sprintf('%.1f%%', highClipValue));
        set(h_low_value_text, 'String', sprintf('%.3f', lowClip));
        set(h_high_value_text, 'String', sprintf('%.3f', highClip));
    end
    
    % Reset function
    function resetClipping(~, ~)
        set(h_min_slider, 'Value', dataMin);
        set(h_max_slider, 'Value', dataMax);
        updateClipping();
    end
    
    % Auto-scale function (based on current visible data)
    function autoScale(~, ~)
        % Get current axis limits
        xlims = xlim(ax);
        ylims = ylim(ax);
        
        % Find visible data range
        if bPlotInMm
            xIndices = find(xMm >= xlims(1) & xMm <= xlims(2));
            yIndices = find(yMm >= ylims(1) & yMm <= ylims(2));
        else
            xIndices = max(1, floor(xlims(1))):min(size(originalMap, 2), ceil(xlims(2)));
            yIndices = max(1, floor(ylims(1))):min(size(originalMap, 1), ceil(ylims(2)));
        end
        
        if ~isempty(xIndices) && ~isempty(yIndices)
            visibleData = originalMap(yIndices, xIndices);
            validVisibleData = visibleData(~isnan(visibleData));
            
            if ~isempty(validVisibleData)
                newMin = min(validVisibleData);
                newMax = max(validVisibleData);
                
                set(h_min_slider, 'Value', newMin);
                set(h_max_slider, 'Value', newMax);
                updateClipping();
            end
        end
    end
    
    % Add zoom and pan functionality with preserved clipping
    zoom(fig, 'on');
    pan(fig, 'on');
    
    % Set initial clipping (no clipping initially)
    updateClipping();
end