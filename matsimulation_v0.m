%% PL Star Analysis Script (Refactored)
% Clean workspace and close all figures
clear all; close all; clc;
addpath('D:\stephen\git_Toolbox');  % Keep the toolbox path if needed

%% Configuration Parameters
CONFIG = struct(...
    'FigureNumber', 100, ...                        % Figure number for plotting
    'FolderPath', 'D:\Stephen\PL star\data', ...    % Folder containing .mat files
    'PLstarEllipseYXRatio', 2.0, ...                % Y/X axis ratio (Y > X)
    'PLstarEllipseScale', 0.25, ...                 % Scale relative to wafer size
    'PLstarWidth', 3, ...                           % Width of PL star lines (1-4)
    'PlotInMm', false ...                           % Plot in pixel units
);

% Validate PL star width is within required range
CONFIG.PLstarWidth = max(1, min(4, CONFIG.PLstarWidth));

%% Process all .mat files in the folder
% Get list of .mat files
matFiles = dir(fullfile(CONFIG.FolderPath, '*.mat'));
fprintf('Found %d .mat files to process\n', length(matFiles));

% Process each file
for i = 1:length(matFiles)
    fprintf('Processing file %d/%d: %s\n', i, length(matFiles), matFiles(i).name);
    
    % Load data from .mat file
    [waferData, waferInfo] = loadMatData(fullfile(CONFIG.FolderPath, matFiles(i).name));
    
    % Generate PL star maps
    maps = generatePLStarMaps(waferData, waferInfo, CONFIG);
    
    % Calculate coordinates
    coords = calculateCoordinates(waferInfo);
    
    % Plot maps
    plotMaps(maps, coords, matFiles(i).name, CONFIG);
    
    % Save Mask and modified PL star data
    saveMaskAndPLStar(maps, matFiles(i).name, CONFIG);
end

fprintf('Processing complete\n');

%% Data Loading Function
function [waferData, waferInfo] = loadMatData(filePath)
    % Load the .mat file
    matData = load(filePath);
    
    % Extract necessary information
    % Note: This assumes specific structure in the .mat file, adjust field names as needed
    waferInfo = struct();
    
    % Get wafer dimensions from the data
    waferData = matData.waferData;  % Assuming waferData field exists
    waferInfo.Shape = size(waferData);  % [height, width]
    
    % Extract wafer name if available, otherwise use filename
    if isfield(matData, 'waferName')
        waferInfo.Name = matData.waferName;
    else
        [~, waferInfo.Name, ~] = fileparts(filePath);
    end
    
    % Replace 0 values with NaN
    waferData(waferData == 0) = nan;
    
    % Additional wafer information if available
    if isfield(matData, 'pixelSizeMm')
        waferInfo.PixelSizeMm = matData.pixelSizeMm;
    else
        waferInfo.PixelSizeMm = 0.1;  % Default value
    end
end

%% Calculate Plotting Coordinates
function coords = calculateCoordinates(waferInfo)
    % Get dimensions directly from wafer shape
    height = waferInfo.Shape(1);
    width = waferInfo.Shape(2);
    
    % Calculate center coordinates
    centerX = width / 2;
    centerY = height / 2;
    
    % Calculate pixel coordinates
    xPixels = 1:width;
    yPixels = 1:height;
    
    % Calculate mm coordinates if pixel size is available
    if isfield(waferInfo, 'PixelSizeMm')
        xMm = (xPixels - centerX - 0.5) * waferInfo.PixelSizeMm;
        yMm = (yPixels - centerY - 0.5) * waferInfo.PixelSizeMm;
    else
        xMm = xPixels;
        yMm = yPixels;
    end
    
    coords = struct('Width', width, 'Height', height, ...
                   'XPixels', xPixels, 'YPixels', yPixels, ...
                   'XMm', xMm, 'YMm', yMm);
end

%% Generate and Process PL Star Images
function maps = generatePLStarMaps(waferData, waferInfo, config)
    maps = struct();
    
    % Get wafer dimensions
    height = waferInfo.Shape(1);
    width = waferInfo.Shape(2);
    
    % Determine PL star center (right side, middle height)
    centerX = round(width * 0.75);  % Position on the right side (3/4 of width)
    centerY = round(height / 2);    % Middle height
    
    % Calculate ellipse dimensions (Y > X)
    minDimension = min(width, height);
    ellipseScale = config.PLstarEllipseScale;
    
    % Ensure Y axis is larger than X axis by using the ratio
    ellipseMinorAxis = round(minDimension * ellipseScale); % X-axis (minor)
    ellipseMajorAxis = round(ellipseMinorAxis * config.PLstarEllipseYXRatio); % Y-axis (major)
    
    % Ensure ellipse fits within wafer boundaries
    ellipseMajorAxis = min(ellipseMajorAxis, height/2 - 10);
    ellipseMinorAxis = min(ellipseMinorAxis, width/2 - 10);
    
    % Generate PL star mask using elliptical boundary
    maskMap = generatePLStar(width, height, centerX, centerY, ...
                          ellipseMinorAxis, ellipseMajorAxis, ...
                          config.PLstarWidth, waferData);
    
    % Simulate filling PL star structure
    simulateMap = fillPLStarStructure(maskMap, waferData);
    
    % Save all maps
    maps.RawMap = waferData;
    maps.MaskMap = maskMap;
    maps.SimulateMap = simulateMap;
end

%% Manually Generate PL Star with Elliptical Boundary
function img = generatePLStar(width, height, centerX, centerY, ellipseMinor, ellipseMajor, lineWidth, waferImg)
    % Initialize empty binary image
    img = zeros(height, width, 'uint8');
    
    % Define angles for the 6 points of the PL star (in degrees)
    angles = [0, 60, 120, 180, 240, 300];
    
    % Convert to radians
    anglesRad = deg2rad(angles);
    
    % Calculate endpoints based on very long lines (much longer than the ellipse)
    maxLength = max(width, height) * 2;
    
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
            % Fallback if no intersection found
            xEnd(i) = xTemp(i);
            yEnd(i) = yTemp(i);
        end
    end
    
    % Draw each line
    for i = 1:length(angles)
        img = drawLine(img, waferImg, centerX, centerY, xEnd(i), yEnd(i), lineWidth);
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
        
        % Stop drawing if NaN is encountered in wafer image
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
function finalImg = fillPLStarStructure(masking, waferImg)
    % Parameter settings
    filterSize = 5;
    sigma = 1;
    thresholdLow = 0.0005 * 2;
    thresholdMed = 0.001 * 2;
    thresholdHigh = 0.003 * 2;
    
    % Create Gaussian filter
    h = fspecial('gaussian', filterSize, sigma);
    backgroundSmoothed = imfilter(waferImg, h);
    nanMask = isnan(backgroundSmoothed);
    backgroundSmoothed(nanMask & ~isnan(waferImg)) = waferImg(nanMask & ~isnan(waferImg));

    diffImg = waferImg - backgroundSmoothed;
    noiseMean = mean(diffImg(masking==1), 'omitnan');
    noiseStd = std(diffImg(masking==1), 'omitnan');

    disp(['Noise Mean: ', num2str(noiseMean)]);
    disp(['Noise Std: ', num2str(noiseStd)]);
    
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

%% Plotting Function
function plotMaps(maps, coords, fileName, config)
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
        axis([1 coords.Width 1 coords.Height]);
        
        % Add title
        title(sprintf('%s', mapName), 'fontsize', 7);
        
        % Ensure normal XY axis direction
        axis xy;
    end
    
    % Link all axes
    linkaxes(ax, 'xy');
    
    % Add super title
    tt = {sprintf('File: %s', fileName)};
    suptitle(tt, 10);
    
    % Save figure if needed
    saveas(gcf, [fileName, '_plot.png']);
end

%% Save Mask and PL Star data
function saveMaskAndPLStar(maps, origFileName, config)
    % Get file name without extension
    [~, baseName, ~] = fileparts(origFileName);
    
    % Create output directory if it doesn't exist
    outputDir = fullfile(config.FolderPath, 'PL_Star_Results');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    
    % Save Mask
    maskFile = fullfile(outputDir, [baseName, '_Mask.mat']);
    maskMap = maps.MaskMap;
    save(maskFile, 'maskMap');
    
    % Save modified PL Star data
    plStarFile = fullfile(outputDir, [baseName, '_PLStar.mat']);
    modifiedMap = maps.SimulateMap;
    save(plStarFile, 'modifiedMap');
    
    fprintf('Saved results for %s\n', baseName);
end

%% Helper function for displaying titles
function suptitle(txt, fs)
    if nargin < 2
        fs = 12;
    end
    
    % Add overall title
    ax = axes('Position', [0, 0.95, 1, 0.05], 'Visible', 'off');
    
    if iscell(txt)
        for i = 1:length(txt)
            text(0.5, 1.1-i*0.1, txt{i}, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'top', 'FontSize', fs, 'FontWeight', 'bold');
        end
    else
        text(0.5, 1, txt, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
            'FontSize', fs, 'FontWeight', 'bold');
    end
end



%% Fill PL Star Structure
function finalImg = fillPLStarStructure(masking, waferImg)
    % Parameter settings
    filterSize = 5;
    sigma = 1;
    thresholdLow = 0.0005 * 2;
    thresholdMed = 0.001 * 2;
    thresholdHigh = 0.003 * 2;
    
    % Create Gaussian filter
    h = fspecial('gaussian', filterSize, sigma);
    backgroundSmoothed = imfilter(waferImg, h);
    nanMask = isnan(backgroundSmoothed);
    backgroundSmoothed(nanMask & ~isnan(waferImg)) = waferImg(nanMask & ~isnan(waferImg));

    diffImg = waferImg - backgroundSmoothed;
    
    % Fix: Convert masking to logical type and ensure diffImg is double
    maskIndices = logical(masking);
    diffValues = double(diffImg(maskIndices));
    
    % Calculate statistics with omitnan option
    if ~isempty(diffValues)
        noiseMean = mean(diffValues, 'omitnan');
        noiseStd = std(diffValues, 'omitnan');
    else
        % If no valid mask points, set defaults
        noiseMean = 0;
        noiseStd = 0.001;
    end

    disp(['Noise Mean: ', num2str(noiseMean)]);
    disp(['Noise Std: ', num2str(noiseStd)]);
    
    % Copy original image
    finalImg = waferImg;
    
    % Find points where mask equals 1
    [rows, cols] = find(maskIndices);
    
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


%% Generate and Process PL Star Images
function maps = generatePLStarMaps(waferData, waferInfo, config)
    maps = struct();
    
    % Get wafer dimensions
    height = waferInfo.Shape(1);
    width = waferInfo.Shape(2);
    
    % Determine base PL star center (right side, middle height)
    baseCenterX = round(width * 0.75);  % Position on the right side (3/4 of width)
    baseCenterY = round(height / 2);    % Middle height
    
    % Add random variation to the center position
    xVariation = round(width * config.PLstarCenterVariationX * (2*rand()-1));  % Random between -10% and +10%
    yVariation = round(height * config.PLstarCenterVariationY * (2*rand()-1)); % Random between -10% and +10%
    
    centerX = max(1, min(width, baseCenterX + xVariation));    % Ensure within image boundaries
    centerY = max(1, min(height, baseCenterY + yVariation));   % Ensure within image boundaries
    
    % Calculate base ellipse dimensions
    minDimension = min(width, height);
    
    % Add random variation to ellipse scale
    scaleVariation = config.PLstarEllipseScaleVariation * (2*rand()-1);  % Random between -var and +var
    ellipseScale = max(0.1, min(0.4, config.PLstarEllipseScale + scaleVariation));
    
    % Ensure Y axis is larger than X axis by using the ratio
    ellipseMinorAxis = round(minDimension * ellipseScale); % X-axis (minor)
    ellipseMajorAxis = round(ellipseMinorAxis * config.PLstarEllipseYXRatio); % Y-axis (major)
    
    % Add slight randomness to the ratio as well
    ratioVariation = 0.3 * rand(); // Slight variation in ratio
    ellipseMajorAxis = round(ellipseMajorAxis * (1 + ratioVariation));
    
    % Ensure ellipse fits within wafer boundaries
    ellipseMajorAxis = min(ellipseMajorAxis, height/2 - 10);
    ellipseMinorAxis = min(ellipseMinorAxis, width/2 - 10);
    
    % Generate PL star mask using elliptical boundary
    maskMap = generatePLStar(width, height, centerX, centerY, ...
                          ellipseMinorAxis, ellipseMajorAxis, ...
                          config.PLstarWidth, waferData);
    
    % Simulate filling PL star structure
    simulateMap = fillPLStarStructure(maskMap, waferData);
    
    % Save all maps
    maps.RawMap = waferData;
    maps.MaskMap = maskMap;
    maps.SimulateMap = simulateMap;
    
    % Store metadata for reference
    maps.Metadata = struct(...
        'CenterX', centerX, ...
        'CenterY', centerY, ...
        'EllipseMinorAxis', ellipseMinorAxis, ...
        'EllipseMajorAxis', ellipseMajorAxis, ...
        'Scale', ellipseScale, ...
        'Width', config.PLstarWidth ...
    );
end
