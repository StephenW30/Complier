classdef HazeMapLabelingApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        GridLayout            matlab.ui.container.GridLayout
        LeftPanel             matlab.ui.container.Panel
        RightPanel            matlab.ui.container.Panel
        TopPanel              matlab.ui.container.Panel
        
        % Top panel controls
        LoadButton            matlab.ui.control.Button
        SaveButton            matlab.ui.control.Button
        PrevButton            matlab.ui.control.Button
        NextButton            matlab.ui.control.Button
        ImageCounterLabel     matlab.ui.control.Label
        ClearMaskButton       matlab.ui.control.Button
        BrushSizeSlider       matlab.ui.control.Slider
        BrushSizeLabel        matlab.ui.control.Label
        
        % Image display axes
        HazeMapAxes           matlab.ui.control.UIAxes
        MaskAxes              matlab.ui.control.UIAxes
        
        % Zoom controls
        ZoomInButton          matlab.ui.control.Button
        ZoomOutButton         matlab.ui.control.Button
        ResetZoomButton       matlab.ui.control.Button
        
        % Status label
        StatusLabel           matlab.ui.control.Label
    end
    
    properties (Access = private)
        ImageFiles            % Cell array of image file paths
        CurrentImageIndex     % Index of current image
        CurrentHazeMap        % Current haze map data
        CurrentMask           % Current mask data
        MaskOverlay           % Overlay for visualization
        BrushSize             % Size of labeling brush
        IsLabeling            % Flag for labeling mode
        ImageDirectory        % Directory containing images
        ZoomLevel             % Current zoom level
        PanPosition           % Current pan position
    end
    
    methods (Access = private)
        
        function startupFcn(app)
            % Configure UI components
            app.BrushSize = 5;
            app.CurrentImageIndex = 1;
            app.ZoomLevel = 1;
            app.PanPosition = [0, 0];
            app.IsLabeling = false;
            
            % Set initial status
            app.StatusLabel.Text = 'Ready. Click "Load Directory" to start.';
            
            % Configure axes
            app.HazeMapAxes.XLim = [0 1];
            app.HazeMapAxes.YLim = [0 1];
            app.MaskAxes.XLim = [0 1];
            app.MaskAxes.YLim = [0 1];
            
            % Set axes properties
            app.HazeMapAxes.Title.String = 'Haze Map (Original + Overlay)';
            app.MaskAxes.Title.String = 'Mask (0-1 Binary)';
            
            % Disable navigation buttons initially
            app.PrevButton.Enable = 'off';
            app.NextButton.Enable = 'off';
            app.SaveButton.Enable = 'off';
            app.ClearMaskButton.Enable = 'off';
        end
        
        function loadDirectoryButtonPushed(app, ~)
            % Select directory containing haze maps
            folder = uigetdir('', 'Select Directory Containing Haze Maps');
            if folder == 0
                return;
            end
            
            app.ImageDirectory = folder;
            
            % Find all image files
            supportedFormats = {'*.jpg', '*.jpeg', '*.png', '*.tif', '*.tiff', '*.bmp'};
            app.ImageFiles = {};
            
            for i = 1:length(supportedFormats)
                files = dir(fullfile(folder, supportedFormats{i}));
                for j = 1:length(files)
                    app.ImageFiles{end+1} = fullfile(folder, files(j).name);
                end
            end
            
            if isempty(app.ImageFiles)
                app.StatusLabel.Text = 'No image files found in selected directory.';
                return;
            end
            
            % Sort files
            app.ImageFiles = sort(app.ImageFiles);
            app.CurrentImageIndex = 1;
            
            % Load first image
            app.loadCurrentImage();
            
            % Enable navigation buttons
            app.updateNavigationButtons();
            app.SaveButton.Enable = 'on';
            app.ClearMaskButton.Enable = 'on';
            
            app.StatusLabel.Text = sprintf('Loaded %d images from directory.', length(app.ImageFiles));
        end
        
        function loadCurrentImage(app)
            if isempty(app.ImageFiles) || app.CurrentImageIndex > length(app.ImageFiles)
                return;
            end
            
            % Load haze map
            try
                img = imread(app.ImageFiles{app.CurrentImageIndex});
                if size(img, 3) == 3
                    app.CurrentHazeMap = rgb2gray(img);
                else
                    app.CurrentHazeMap = img;
                end
                app.CurrentHazeMap = double(app.CurrentHazeMap) / 255;
                
                % Initialize mask
                app.CurrentMask = zeros(size(app.CurrentHazeMap));
                
                % Display images
                app.displayImages();
                
                % Update counter
                app.ImageCounterLabel.Text = sprintf('Image %d of %d', app.CurrentImageIndex, length(app.ImageFiles));
                
                % Reset zoom
                app.resetZoom();
                
            catch ME
                app.StatusLabel.Text = sprintf('Error loading image: %s', ME.message);
            end
        end
        
        function displayImages(app)
            % Display haze map with overlay
            cla(app.HazeMapAxes);
            
            % Create RGB image for overlay
            overlayImage = repmat(app.CurrentHazeMap, [1, 1, 3]);
            
            % Add red overlay where mask is 1
            redChannel = overlayImage(:,:,1);
            redChannel(app.CurrentMask > 0) = 1;
            overlayImage(:,:,1) = redChannel;
            
            imshow(overlayImage, 'Parent', app.HazeMapAxes);
            app.HazeMapAxes.Title.String = 'Haze Map (Original + Red Overlay)';
            
            % Display mask
            cla(app.MaskAxes);
            imshow(app.CurrentMask, 'Parent', app.MaskAxes);
            app.MaskAxes.Title.String = 'Mask (0-1 Binary)';
            
            % Set up mouse callbacks
            app.HazeMapAxes.ButtonDownFcn = @(src, event) app.mousePressed(src, event);
            app.UIFigure.WindowButtonMotionFcn = @(src, event) app.mouseMoved(src, event);
            app.UIFigure.WindowButtonUpFcn = @(src, event) app.mouseReleased(src, event);
        end
        
        function mousePressed(app, ~, event)
            if strcmp(event.Button, 'left')
                app.IsLabeling = true;
                app.labelAtPosition(event.IntersectionPoint);
            end
        end
        
        function mouseMoved(app, ~, ~)
            if app.IsLabeling
                % Get current point
                point = app.HazeMapAxes.CurrentPoint;
                if ~isempty(point)
                    app.labelAtPosition(point(1, 1:2));
                end
            end
        end
        
        function mouseReleased(app, ~, ~)
            app.IsLabeling = false;
        end
        
        function labelAtPosition(app, position)
            if isempty(app.CurrentHazeMap)
                return;
            end
            
            % Convert axes coordinates to image coordinates
            [height, width] = size(app.CurrentHazeMap);
            x = round(position(1));
            y = round(position(2));
            
            % Check bounds
            if x < 1 || x > width || y < 1 || y > height
                return;
            end
            
            % Create brush
            [X, Y] = meshgrid(1:width, 1:height);
            brush = (X - x).^2 + (Y - y).^2 <= app.BrushSize^2;
            
            % Update mask
            app.CurrentMask(brush) = 1;
            
            % Update display
            app.displayImages();
        end
        
        function prevButtonPushed(app, ~)
            if app.CurrentImageIndex > 1
                app.CurrentImageIndex = app.CurrentImageIndex - 1;
                app.loadCurrentImage();
                app.updateNavigationButtons();
            end
        end
        
        function nextButtonPushed(app, ~)
            if app.CurrentImageIndex < length(app.ImageFiles)
                app.CurrentImageIndex = app.CurrentImageIndex + 1;
                app.loadCurrentImage();
                app.updateNavigationButtons();
            end
        end
        
        function updateNavigationButtons(app)
            app.PrevButton.Enable = 'on';
            app.NextButton.Enable = 'on';
            
            if app.CurrentImageIndex <= 1
                app.PrevButton.Enable = 'off';
            end
            
            if app.CurrentImageIndex >= length(app.ImageFiles)
                app.NextButton.Enable = 'off';
            end
        end
        
        function saveButtonPushed(app, ~)
            if isempty(app.CurrentMask)
                return;
            end
            
            % Create output directory
            outputDir = fullfile(app.ImageDirectory, 'masks');
            if ~exist(outputDir, 'dir')
                mkdir(outputDir);
            end
            
            % Save mask
            [~, filename, ~] = fileparts(app.ImageFiles{app.CurrentImageIndex});
            maskFilename = fullfile(outputDir, [filename '_mask.png']);
            
            imwrite(uint8(app.CurrentMask * 255), maskFilename);
            
            app.StatusLabel.Text = sprintf('Mask saved: %s', maskFilename);
        end
        
        function clearMaskButtonPushed(app, ~)
            if ~isempty(app.CurrentMask)
                app.CurrentMask = zeros(size(app.CurrentMask));
                app.displayImages();
                app.StatusLabel.Text = 'Mask cleared.';
            end
        end
        
        function brushSizeChanged(app, ~)
            app.BrushSize = app.BrushSizeSlider.Value;
            app.BrushSizeLabel.Text = sprintf('Brush Size: %d', round(app.BrushSize));
        end
        
        function zoomInButtonPushed(app, ~)
            app.ZoomLevel = app.ZoomLevel * 1.2;
            app.applyZoom();
        end
        
        function zoomOutButtonPushed(app, ~)
            app.ZoomLevel = app.ZoomLevel / 1.2;
            app.applyZoom();
        end
        
        function resetZoomButtonPushed(app, ~)
            app.resetZoom();
        end
        
        function applyZoom(app)
            if isempty(app.CurrentHazeMap)
                return;
            end
            
            [height, width] = size(app.CurrentHazeMap);
            
            % Calculate zoom region
            centerX = width / 2 + app.PanPosition(1);
            centerY = height / 2 + app.PanPosition(2);
            
            halfWidth = width / (2 * app.ZoomLevel);
            halfHeight = height / (2 * app.ZoomLevel);
            
            xmin = max(1, centerX - halfWidth);
            xmax = min(width, centerX + halfWidth);
            ymin = max(1, centerY - halfHeight);
            ymax = min(height, centerY + halfHeight);
            
            app.HazeMapAxes.XLim = [xmin, xmax];
            app.HazeMapAxes.YLim = [ymin, ymax];
            app.MaskAxes.XLim = [xmin, xmax];
            app.MaskAxes.YLim = [ymin, ymax];
        end
        
        function resetZoom(app)
            app.ZoomLevel = 1;
            app.PanPosition = [0, 0];
            
            if ~isempty(app.CurrentHazeMap)
                [height, width] = size(app.CurrentHazeMap);
                app.HazeMapAxes.XLim = [0.5, width + 0.5];
                app.HazeMapAxes.YLim = [0.5, height + 0.5];
                app.MaskAxes.XLim = [0.5, width + 0.5];
                app.MaskAxes.YLim = [0.5, height + 0.5];
            end
        end
    end
    
    % Component initialization
    methods (Access = private)
        
        function createComponents(app)
            % Create UIFigure and components
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 800];
            app.UIFigure.Name = 'Haze Map Labeling Tool';
            app.UIFigure.Resize = 'off';
            
            % Create main grid layout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x', '1x'};
            app.GridLayout.RowHeight = {60, '1x', 30};
            
            % Create top panel
            app.TopPanel = uipanel(app.GridLayout);
            app.TopPanel.Layout.Row = 1;
            app.TopPanel.Layout.Column = [1 2];
            app.TopPanel.Title = 'Controls';
            
            % Create top panel controls
            app.LoadButton = uibutton(app.TopPanel, 'push');
            app.LoadButton.ButtonPushedFcn = createCallbackFcn(app, @loadDirectoryButtonPushed, true);
            app.LoadButton.Position = [10 10 100 30];
            app.LoadButton.Text = 'Load Directory';
            
            app.SaveButton = uibutton(app.TopPanel, 'push');
            app.SaveButton.ButtonPushedFcn = createCallbackFcn(app, @saveButtonPushed, true);
            app.SaveButton.Position = [120 10 80 30];
            app.SaveButton.Text = 'Save Mask';
            
            app.PrevButton = uibutton(app.TopPanel, 'push');
            app.PrevButton.ButtonPushedFcn = createCallbackFcn(app, @prevButtonPushed, true);
            app.PrevButton.Position = [210 10 60 30];
            app.PrevButton.Text = 'Previous';
            
            app.NextButton = uibutton(app.TopPanel, 'push');
            app.NextButton.ButtonPushedFcn = createCallbackFcn(app, @nextButtonPushed, true);
            app.NextButton.Position = [280 10 60 30];
            app.NextButton.Text = 'Next';
            
            app.ImageCounterLabel = uilabel(app.TopPanel);
            app.ImageCounterLabel.Position = [350 15 100 20];
            app.ImageCounterLabel.Text = 'Image 0 of 0';
            
            app.ClearMaskButton = uibutton(app.TopPanel, 'push');
            app.ClearMaskButton.ButtonPushedFcn = createCallbackFcn(app, @clearMaskButtonPushed, true);
            app.ClearMaskButton.Position = [460 10 80 30];
            app.ClearMaskButton.Text = 'Clear Mask';
            
            app.BrushSizeSlider = uislider(app.TopPanel);
            app.BrushSizeSlider.Limits = [1 20];
            app.BrushSizeSlider.Value = 5;
            app.BrushSizeSlider.ValueChangedFcn = createCallbackFcn(app, @brushSizeChanged, true);
            app.BrushSizeSlider.Position = [550 20 100 3];
            
            app.BrushSizeLabel = uilabel(app.TopPanel);
            app.BrushSizeLabel.Position = [550 0 100 15];
            app.BrushSizeLabel.Text = 'Brush Size: 5';
            
            app.ZoomInButton = uibutton(app.TopPanel, 'push');
            app.ZoomInButton.ButtonPushedFcn = createCallbackFcn(app, @zoomInButtonPushed, true);
            app.ZoomInButton.Position = [660 10 60 30];
            app.ZoomInButton.Text = 'Zoom In';
            
            app.ZoomOutButton = uibutton(app.TopPanel, 'push');
            app.ZoomOutButton.ButtonPushedFcn = createCallbackFcn(app, @zoomOutButtonPushed, true);
            app.ZoomOutButton.Position = [730 10 60 30];
            app.ZoomOutButton.Text = 'Zoom Out';
            
            app.ResetZoomButton = uibutton(app.TopPanel, 'push');
            app.ResetZoomButton.ButtonPushedFcn = createCallbackFcn(app, @resetZoomButtonPushed, true);
            app.ResetZoomButton.Position = [800 10 80 30];
            app.ResetZoomButton.Text = 'Reset Zoom';
            
            % Create left panel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = 2;
            app.LeftPanel.Layout.Column = 1;
            app.LeftPanel.Title = 'Haze Map with Overlay';
            
            % Create haze map axes
            app.HazeMapAxes = uiaxes(app.LeftPanel);
            app.HazeMapAxes.Position = [10 10 570 650];
            app.HazeMapAxes.XTickLabel = {};
            app.HazeMapAxes.YTickLabel = {};
            
            % Create right panel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Layout.Row = 2;
            app.RightPanel.Layout.Column = 2;
            app.RightPanel.Title = 'Mask';
            
            % Create mask axes
            app.MaskAxes = uiaxes(app.RightPanel);
            app.MaskAxes.Position = [10 10 570 650];
            app.MaskAxes.XTickLabel = {};
            app.MaskAxes.YTickLabel = {};
            
            % Create status label
            app.StatusLabel = uilabel(app.GridLayout);
            app.StatusLabel.Layout.Row = 3;
            app.StatusLabel.Layout.Column = [1 2];
            app.StatusLabel.Text = 'Ready';
            
            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end
    
    % App creation and deletion
    methods (Access = public)
        
        function app = HazeMapLabelingApp
            % Create UIFigure and components
            createComponents(app);
            
            % Register the app with App Designer
            registerApp(app, app.UIFigure);
            
            % Execute the startup function
            runStartupFcn(app, @startupFcn);
            
            if nargout == 0
                clear app;
            end
        end
        
        function delete(app)
            % Delete UIFigure when app is deleted
            delete(app.UIFigure);
        end
    end
end