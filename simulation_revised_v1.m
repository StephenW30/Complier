%% PL Star Analysis Script
% Clean workspace and close all figures
clear all; close all; clc;
addpath('D:\stephen\git_Toolbox');  % Add toolbox path to MATLAB search path

%% Main Script
% Set global constants and configuration parameters
CONFIG = struct(...
    'FigureNumber', 100, ...                       % Figure number for plotting
    'FolderPath', 'D:\Stephen\PL star\data\Surface_Inspection(0)_2025-02-01-19-10-39_SuperFine1Res', ...
    'HazeMapFile', 'P2cHaze_Grp[1]FT[MED]Res[100]ch[2]_03_Nppm', ...
    'PixelSizeMm', 0.1, ...                        % Pixel size in mm
    'WaferName', 'sc1 Wolfspeed', ...              % Wafer name
    'WaferSizeMm', 150, ...                        % Wafer size in mm
    'PlotInMm', false, ...                         % Whether to plot in mm units
    'Resolution', 'SuperFine1', ...                % Resolution setting
    'IsAPS1', false, ...                           % APS1 flag
    'PLstarCenter', struct('X', 1100, 'Y', 750), ... % PL star center on right side of wafer
    'PLstarEllipse', struct('MajorAxis', 150, 'MinorAxis', 80), ... % Elliptical shape parameters
    'PLstarWidth', 5 ...                           % Width of the PL star lines
);

% Load raw data
rawMap = loadRawData(CONFIG);

% Generate PL star maps
maps = generatePLStarMaps(rawMap, CONFIG);

% Calculate coordinates
coords = calculateCoordinates(CONFIG);

% Plot maps
plotMaps(maps, coords, CONFIG);

%% Data Loading Function
function rawData = loadRawData(config)
    % Build complete file path
    filePath = fullfile(config.FolderPath, [config.HazeMapFile, '.raw']);
    
    % Load raw data
    rawData = openraw(filePath);
    
    % Replace 0 values with NaN
    rawData(rawData == 0) = nan;
    
    % Flip data vertically if not APS1
    if ~config.IsAPS1
        rawData = flipud(rawData);
    end
end

%% Generate and Process PL Star Images
function maps = generatePLStarMaps(rawMap, config)
    maps = struct();
    
    % Set image size
    imageSize = config.WaferSizeMm / config.PixelSizeMm;
    
    % Generate PL star mask using elliptical boundary
    maskMap = generatePLStar(imageSize, config.PLstarCenter.X, config.PLstarCenter.Y, ...
                          config.PLstarEllipse.MajorAxis, config.PLstarEllipse.MinorAxis, ...
                          config.PLstarWidth, rawMap);
    
    % Simulate filling PL star structure
    simulateMap = fillPLStarStructure(maskMap, rawMap, config);
    
    % Save all maps
    maps.RawMap = rawMap;
    maps.MaskMap = maskMap;
    maps.SimulateMap = simulateMap;
end

%% Calculate Plotting Coordinates
function coords = calculateCoordinates(config)
    % Calculate dimensions and center
    dim = config.WaferSizeMm / config.PixelSizeMm;
    waferCenter = struct('X', dim/2, 'Y', dim/2);
    
    % Calculate mm coordinates
    xMm = ((1:dim) - waferCenter.X - 0.5) * config.PixelSizeMm;
    yMm = ((1:dim) - waferCenter.Y - 0.5) * config.PixelSizeMm;
    
    coords = struct('Dimension', dim, 'XMm', xMm, 'YMm', yMm);
end

%% Plotting Function
function plotMaps(maps, coords, config)
    % Create new figure
    figure(config.FigureNumber); clf;
    
    % Get map names
    mapNames = fieldnames(maps);
    
    % Initialize axes array
    ax = zeros(1, length(mapNames));
    
    % Loop through each map for plotting
    for i = 1:length(mapNames)
        % Get current map
        mapName = mapNames{i};
        currentMap = maps.(mapName);
        
        % Create subplot
        if length(mapNames) > 3
            ax(i) = subplot(2, 3, i);
        else
            ax(i) = subplot(1, length(mapNames), i);
        end
        
        % Plot map
        if config.PlotInMm
            imagesc(coords.XMm, coords.YMm, currentMap);
        else
            imagesc(currentMap);
        end
        
        % Apply custom functions
        func_ChangeColorForNaN(gca);
        func_GetDataStatCurrROI(gca, true, [5 95]);
        
        % Set labels
        if config.PlotInMm
            xlabel('x(mm)');
            ylabel('y(mm)');
        else
            xlabel('x(pixels)');
            ylabel('y(pixels)');
        end
        
        % Adjust axes and set colormap
        axis tight; axis equal;
        colormap('jet'); colorbar();
        
        % Set axis range
        if config.PlotInMm
            axis([-config.WaferSizeMm/2 config.WaferSizeMm/2 -config.WaferSizeMm/2 config.WaferSizeMm/2]);
        else
            axis([0 coords.Dimension 0 coords.Dimension]);
        end
        
        % Add title
        title(sprintf('%s', mapName), 'fontsize', 7);
        
        % Ensure normal XY axis direction
        axis xy;
    end
    
    % Link all axes
    linkaxes(ax, 'xy');
    
    % Add super title
    tt = {sprintf('%s', config.FolderPath), sprintf('%s', config.HazeMapFile)};
    suptitle(tt, 10);
end

%% Manually Generate PL Star with Elliptical Boundary
function img = generatePLStar(imageSize, centerX, centerY, ellipseMajor, ellipseMinor, width, waferImg)
    % Initialize empty binary image
    img = zeros(imageSize, imageSize, 'uint8');
    
    % If wafer image not provided, create all-black image
    if nargin < 7 || isempty(waferImg)
        waferImg = zeros(imageSize, imageSize, 'double');
    else
        waferImg = double(waferImg);
    end
    
    % Define angles for the 6 points of the PL star (in degrees)
    angles = [0, 60, 120, 180, 240, 300];
    
    % Convert to radians
    anglesRad = deg2rad(angles);
    
    % Calculate endpoints based on elliptical boundary
    xEnd = zeros(1, length(angles));
    yEnd = zeros(1, length(angles));
    
    % Ensure the ellipse has major axis along Y direction (vertically elongated)
    % We swap if necessary to ensure Y-axis (vertical) is longer than X-axis (horizontal)
    verticalEllipse = true;  % Force vertical ellipse (Y-axis longer)
    
    % If we need to swap axes to make vertical longer
    if ellipseMajor < ellipseMinor
        temp = ellipseMajor;
        ellipseMajor = ellipseMinor;
        ellipseMinor = temp;
    end
    
    for i = 1:length(angles)
        % Calculate parametric angle for ellipse
        t = anglesRad(i);
        
        % Calculate endpoint based on elliptical shape
        % For vertical ellipse, the Y component uses the major axis (longer)
        if verticalEllipse
            xDist = ellipseMinor * cos(t);  % X uses minor axis (shorter)
            yDist = ellipseMajor * sin(t);  % Y uses major axis (longer)
        else
            xDist = ellipseMajor * cos(t);
            yDist = ellipseMinor * sin(t);
        end
        
        % Add random variation to the length (±10%)
        variationFactor = 0.9 + 0.2 * rand();
        xDist = xDist * variationFactor;
        yDist = yDist * variationFactor;
        
        % Calculate endpoint
        xEnd(i) = round(centerX + xDist);
        yEnd(i) = round(centerY + yDist);
    end
    
    % Draw each line
    for i = 1:length(angles)
        img = drawLine(img, waferImg, centerX, centerY, xEnd(i), yEnd(i), width);
    end
end

%% Draw Line
function img = drawLine(img, waferImg, x1, y1, x2, y2, width)
    % Get points on the line using Bresenhams algorithm
    [x, y] = bresenham(x1, y1, x2, y2);
    
    % Draw each point
    for i = 1:length(x)
        % Check if point is within image boundaries
        if x(i) < 1 || x(i) > size(img, 2) || y(i) < 1 || y(i) > size(img, 1)
            continue;
        end
        
        % Stop drawing if NaN is encountered
        if isnan(waferImg(y(i), x(i)))
            break;
        end
        
        % Draw line with specified width
        for dx = -floor(width/2):floor(width/2)
            for dy = -floor(width/2):floor(width/2)
                % Calculate new position
                xi = min(max(x(i) + dx, 1), size(img, 2));
                yi = min(max(y(i) + dy, 1), size(img, 1));
                
                if isnan(waferImg(yi, xi))
                    continue;
                end
                
                img(yi, xi) = 1;
            end
        end
    end
end

%% Bresenham Algorithm Implementation
function [x, y] = bresenham(x1, y1, x2, y2)
    % Round input coordinates for consistency
    x1 = round(x1); 
    x2 = round(x2); 
    y1 = round(y1); 
    y2 = round(y2);
    
    % Calculate differences in x and y directions
    dx = abs(x2 - x1);
    dy = abs(y2 - y1);
    
    % Determine increment direction for x and y
    sx = sign(x2 - x1);
    sy = sign(y2 - y1);
    
    % Initialize error term
    err = dx - dy;
    
    % Initialize empty arrays to store line points
    x = [];
    y = [];
    
    % Main loop of Bresenhams algorithm
    while true
        % Store current point
        x = [x; x1];
        y = [y; y1];
        
        % Check if end point reached
        if (x1 == x2 && y1 == y2) || ...
           ((sx > 0 && x1 >= x2) && (sy > 0 && y1 >= y2)) || ...
           ((sx < 0 && x1 <= x2) && (sy < 0 && y1 <= y2))
            break;
        end
        
        % Calculate decision parameter
        e2 = 2 * err;
        
        % Update error term and x coordinate if necessary
        if e2 > -dy
            err = err - dy;
            x1 = x1 + sx;
        end
        
        % Update error term and y coordinate if necessary
        if e2 < dx
            err = err + dx;
            y1 = y1 + sy;
        end
    end
end

%% Fill PL Star Structure with Improved Error Handling
function finalImg = fillPLStarStructure(masking, waferImg, config)
    % Parameter settings
    filterSize = 5;
    sigma = 1;
    thresholdLow = 0.0005;
    thresholdMed = 0.001;
    thresholdHigh = 0.003;
    
    % Input data validation: ensure no NaN/Inf
    waferImg = double(waferImg); 
    waferImg(isfinite(waferImg)==0) = 0; % Replace NaN/Inf with 0
    
    % Create Gaussian filter
    h = fspecial('gaussian', filterSize, sigma);
    backgroundSmoothed = imfilter(waferImg, h, 'replicate'); % Add boundary handling
    
    % Calculate noise level only in mask region (fixing NaN issue)
    diff = waferImg - backgroundSmoothed;
    maskDiff = diff(masking == 1); 
    maskDiff = maskDiff(isfinite(maskDiff)); % Remove NaN/Inf
    if ~isempty(maskDiff) && var(maskDiff) > 0
        noiseLevel = std(maskDiff);
    else
        noiseLevel = 0.0002; 
    end
    
    % Initialize output image
    finalImg = waferImg;
    
    % Extract mask coordinates
    [rows, cols] = find(masking == 1);
    
    % Process each masked pixel
    for i = 1:length(rows)
        r = rows(i);
        c = cols(i);
        backgroundValue = backgroundSmoothed(r, c);
        
        % Ensure background value is valid
        if ~isfinite(backgroundValue)
            backgroundValue = 0;
        end
        
        randProb = rand();
        
        % Calculate scaling factor (fix numerical stability)
        if randProb < 0.3
            scalingFactor = 1 - thresholdMed + (thresholdMed - thresholdLow) * rand();
        else
            scalingFactor = 1 - thresholdHigh + (thresholdHigh - thresholdMed) * rand();
        end
        scalingFactor = max(min(scalingFactor, 1), 0); % Constrain to [0,1]
        
        % Synthesize new pixel value
        newValue = backgroundValue * scalingFactor;
        noise = noiseLevel * randn();
        newValue = newValue + noise;
        finalImg(r, c) = newValue;
    end
end
