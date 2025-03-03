%% PL Star Analysis Script
% Clean workspace and close all figures
clear all; close all; clc;
addpath('D:\stephen\git_Toolbox');  % Add toolbox path to MATLAB search path

%% Main Script
% Set global constants and configuration parameters
CONFIG = struct(...
    'FigureNumber', 100, ...                       % Figure number for plotting
    'FolderPath', 'D:\StephenPL starldatalsurface Inspection(0)_2025-02-01-19-10-39 SuperFine1Res', ...
    'HazeMapFile', 'P2cHaze_Grp[1]FT[MED]Res[100]ch[2]_03_Nppm', ...
    'PixelSizeMm', 0.1, ...                        % Pixel size in mm
    'WaferName', 'sc1 Wolfspeed', ...              % Wafer name
    'WaferSizeMm', 150, ...                        % Wafer size in mm
    'PlotInMm', false, ...                         % Whether to plot in mm units
    'Resolution', 'SuperFine1', ...                % Resolution setting
    'IsAPS1', false, ...                           % APS1 flag
    'PLstarCenter', struct('X', 764, 'Y', 1412), ... % PL star center coordinates
    'PLstarLength', 100, ...                       % Length from center to outer vertices
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
    imageSize = 1500;
    
    % Generate PL star mask
    maskMap = generatePLStar(imageSize, config.PLstarCenter.X, config.PLstarCenter.Y, ...
                            config.PLstarLength, config.PLstarWidth, rawMap);
    
    % Simulate filling PL star structure
    simulateMap = fillPLStarStructure(maskMap, rawMap);
    
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

%% Helper Functions

% Fill PL Star Structure
function finalImg = fillPLStarStructure(masking, waferImg)
    % Parameter settings
    filterSize = 5;
    sigma = 1;
    noiseLevel = 0.0002;
    thresholdLow = 0.0005;
    thresholdMed = 0.001;
    thresholdHigh = 0.003;
    
    % Create Gaussian filter
    h = fspecial('gaussian', filterSize, sigma);
    backgroundSmoothed = imfilter(waferImg, h);
    
    % Copy original image
    finalImg = waferImg;
    
    % Find points where mask equals 1
    [rows, cols] = find(masking == 1);
    
    % Process each point
    for i = 1:length(rows)
        r = rows(i);
        c = cols(i);
        backgroundValue = backgroundSmoothed(r, c);
        randProb = rand();
        
        % Choose scaling factor based on random probability
        if randProb < 0.3
            scalingFactor = (1 - thresholdMed + (thresholdMed - thresholdLow) * rand());
        else
            scalingFactor = (1 - thresholdHigh + (thresholdHigh - thresholdMed) * rand());
        end
        
        % Calculate new value and add noise
        newValue = backgroundValue * scalingFactor;
        newValue = newValue + noiseLevel * rand();
        finalImg(r, c) = newValue;
    end
end

% Manually Generate PL Star
function img = generatePLStar(imageSize, centerX, centerY, length, width, waferImg)
    % Initialize empty binary image
    img = zeros(imageSize, imageSize, 'uint8');
    
    % If wafer image not provided, create all-black image
    if nargin < 6 || isempty(waferImg)
        waferImg = zeros(imageSize, imageSize, 'double');
    else
        waferImg = double(waferImg);
    end
    
    % Define angles for the 6 points of the PL star (in degrees)
    angles = [0, 60, 120, 180, 240, 300];
    
    % Convert to radians
    anglesRad = deg2rad(angles);
    
    % Calculate endpoints of each line
    xEnd = round(centerX + length * cos(anglesRad));
    yEnd = round(centerY + length * sin(anglesRad));
    
    % Draw each line
    for i = 1:6
        img = drawLine(img, waferImg, centerX, centerY, xEnd(i), yEnd(i), width);
    end
end

% Draw Line
function img = drawLine(img, waferImg, x1, y1, x2, y2, width)
    % Get points on the line using Bresenham's algorithm
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

% Bresenham Algorithm Implementation
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
    
    % Main loop of Bresenham's algorithm
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
