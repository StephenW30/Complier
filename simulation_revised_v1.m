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
    'PLstarCenter', struct('X', 1400, 'Y', 750), ... % PL star center on right side of wafer
    'PLstarEllipse', struct('MajorAxis', 200, 'MinorAxis', 100), ... % Elliptical shape parameters
    'PLstarWidth', 3 ...                           % Width of the PL star lines
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
    set(gcf, 'Position', [100, 100, 1800, 400]);
    
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
    
    % Calculate endpoints based on very long lines (much longer than the ellipse)
    % This ensures we can find intersection with ellipse
    maxLength = max(imageSize, max(ellipseMajor, ellipseMinor) * 2);
    
    % First create long lines in all 6 directions
    xTemp = zeros(1, length(angles));
    yTemp = zeros(1, length(angles));
    
    for i = 1:length(angles)
        xTemp(i) = round(centerX + maxLength * cos(anglesRad(i)));
        yTemp(i) = round(centerY + maxLength * sin(anglesRad(i)));
    end
    
    % Now find intersection points with the ellipse for each line
    xEnd = zeros(1, length(angles));
    yEnd = zeros(1, length(angles));
    
    for i = 1:length(angles)
        % Find intersection of the line from center to (xTemp,yTemp) with the ellipse
        [xIntersect, yIntersect] = lineEllipseIntersection(centerX, centerY, xTemp(i), yTemp(i), ...
                                                          centerX, centerY, ellipseMinor, ellipseMajor);
        
        % Use the first intersection point (closest to center)
        if ~isempty(xIntersect)
            xEnd(i) = round(xIntersect(1));
            yEnd(i) = round(yIntersect(1));
        else
            % Fallback if no intersection found (shouldn't happen with sufficiently large maxLength)
            xEnd(i) = xTemp(i);
            yEnd(i) = yTemp(i);
        end
    end
    
    % Draw each line
    for i = 1:length(angles)
        img = drawLine(img, waferImg, centerX, centerY, xEnd(i), yEnd(i), width);
    end
end

%% Find intersection between a line and an ellipse
function [xIntersect, yIntersect] = lineEllipseIntersection(x1, y1, x2, y2, cx, cy, a, b)
    % Input:
    %   (x1,y1) and (x2,y2) are the endpoints of the line
    %   (cx,cy) is the center of the ellipse
    %   a is the semi-minor axis (X direction)
    %   b is the semi-major axis (Y direction)
    
    % Translate to make ellipse centered at origin
    x1 = x1 - cx;
    y1 = y1 - cy;
    x2 = x2 - cx;
    y2 = y2 - cy;
    
    % Parametric equation of the line: (x,y) = (x1,y1) + t*((x2-x1),(y2-y1))
    dx = x2 - x1;
    dy = y2 - y1;
    
    % Quadratic formula coefficients
    A = (dx*dx)/(a*a) + (dy*dy)/(b*b);
    B = 2*((x1*dx)/(a*a) + (y1*dy)/(b*b));
    C = (x1*x1)/(a*a) + (y1*y1)/(b*b) - 1;
    
    % Calculate discriminant
    discriminant = B*B - 4*A*C;
    
    % If discriminant is negative, no intersection
    if discriminant < 0
        xIntersect = [];
        yIntersect = [];
        return;
    end
    
    % Calculate intersection parameters
    t1 = (-B + sqrt(discriminant)) / (2*A);
    t2 = (-B - sqrt(discriminant)) / (2*A);
    
    % Calculate intersection points
    xIntersect = [x1 + t1*dx, x1 + t2*dx] + cx;
    yIntersect = [y1 + t1*dy, y1 + t2*dy] + cy;
    
    % Sort based on distance from original point (x1,y1)
    dist1 = (xIntersect(1) - (x1+cx))^2 + (yIntersect(1) - (y1+cy))^2;
    dist2 = (xIntersect(2) - (x1+cx))^2 + (yIntersect(2) - (y1+cy))^2;
    
    if dist2 < dist1
        xIntersect = [xIntersect(2), xIntersect(1)];
        yIntersect = [yIntersect(2), yIntersect(1)];
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

%% Fill PL Star Structure
function finalImg = fillPLStarStructure(masking, waferImg, config)
    % Parameter settings
    filterSize = 5;
    sigma = 1;
    % noiseLevel = 0.0002;
    thresholdLow = 0.0005 * 2;
    thresholdMed = 0.001 * 2;
    thresholdHigh = 0.003 * 2;
    
    % Create Gaussian filter
    h = fspecial('gaussian', filterSize, sigma);
    backgroundSmoothed = imfilter(waferImg, h);
    nanMask = isnan(backgroundSmoothed);
    backgroundSmoothed(nanMask & ~isnan(waferImg)) waferImg(nanMask & ~isnan(waferImg));

    diffImg = waferImg - backgroundSmoothed;
    noiseMean = mean(diffImg(masking==1));
    noiseStd = std(diffImg(masking==1));

    disp(noiseMean);
    disp(noiseStd);
    
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
        newValue = newValue + min(noiseStd, thresholdLow) * randn() * 0.1;
        finalImg(r, c) = newValue;
    end
end
