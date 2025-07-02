clear; close all; clc;
addpath('D:\stephen\git_toolbox');

CONFIG = struct(...
    'FigureNumber', 100, ...
    'OriginalFolderPath', '', ...
    'SaveResultFolderPath', '', ...
    'MaskOutputFolderPath', '', ...
    'PLStarOutputFolderPath', '', ...
    'SavePlotFolderPath', '', ...
    'PLStarEllipseYXRatio', 2.0, ...
    'PLStarEllipseScale', 0.1, ...
    'PlotInMm', false, ...
);

CONFIG.FlipVertical = true; 
CONFIG.PLStarEllipseScaleVariation = 0.3;
CONFIG.PLStarCenterVariationX = 0.15;
CONFIG.PLStarCenterVariationY = 0.15; 
CONFIG.RunTime = datetime('now', 'Format', 'MMdd_HHmmss');

% Process all .mat files in the folder
matFiles = dir(fullfile(CONFIG.OriginalFolderPath, '*.mat'));
fprintf('Found %d .mat files in the folder.\n', numel(matFiles));

for i = 1:length(matFiles)
    fprintf('Processing file %d of %d: %s\n', i, length(matFiles), matFiles(i).name);
    CONFIG.PLStarWidth = randi([2, 7]);
    [waferData, waferInfo] = loadMatData(fullfile(CONFIG.OriginalFolderPath, matFiles(i).name), CONFIG);
    maps = generatePLStarMaps(waferData, waferInfo, CONFIG);
    coords = calculateCoordinates(waferInfo);
    plotMaps(maps, coords, matFiles(i).name, CONFIG);
    saveMaskAndPLStar(maps, matFiles(i).name, CONFIG);
end
fprintf('Processing completed for all files.\n');

% Data loading function
function [waferData, waferInfo] = loadMatData(filePath, CONFIG)
    matData = load(filePath);
    waferInfo = struct();
    if isfield(matData, 'dw_image')
        waferData = matData.dw_image;
    else
        error('dw_image field not found in the .mat file: %s', filePath);
    end

    if isfield(matData, 'waferData')
        waferInfo.Name = matData.waferName;
    else
        [~, waferInfo.Name, ~] = fileparts(filePath);
    end

    % Replace 0 values with NaN
    waferData(waferData == 0) = nan;
    waferData(waferData == 3158064) = nan;
    waferData(waferData == min(waferData(:))) = nan;

    % Check if the dimension are not 1500x1500
    if size(waferData, 1) ~= 1500 || size(waferData, 2) ~= 1500
        % Nearest neighbor interpolation to 1500x1500
        waferData = imresize(waferData, [1500, 1500], 'nearest');
    end

    waferInfo.Shape = size(waferData);
    
    % Additional wafer information if available
    if isfield(matData, 'pixelSizeMm')
        waferInfo.PixelSizeMm = matData.pixelSizeMm;
    else
        waferInfo.PixelSizeMm = 0.1; % Default value if not provided
    end

    if CONFIG.FlipVertical
        waferData = flipud(waferData);
    end

    disp(waferInfo);
end

function coords = calculateCoordinates(waferInfo)
    height = waferInfo.Shape(1);
    width = waferInfo.Shape(2);

    centerX = width / 2;
    centerY = height / 2;

    xPixels = 1:width;
    yPixels = 1:height;

    if isfield(waferInfo, 'PixelSizeMm')
        xMm = (xPixels - centerX - 0.5) * waferInfo.PixelSizeMm;
        yMm = (yPixels - centerY - 0.5) * waferInfo.PixelSizeMm;
    else
        xMm = xPixels;
        yMm = yPixels;
        warning('Pixel size in mm not provided, using pixel indices instead.');
    end

    coords = struct('Width', width, ...
                    'Height', height, ...
                    'CenterX', centerX, ...
                    'CenterY', centerY, ...
                    'XPixels', xPixels, ...
                    'YPixels', yPixels, ...
                    'XMm', xMm, ...
                    'YMm', yMm);
end


function maps = generatePLStarMaps(waferData, waferInfo, CONFIG)
    maps = struct();

    height = waferInfo.Shape(1);
    width = waferInfo.Shape(2);

    baseCenterX = round(width * 0.8);  % Base center X position
    baseCenterY = round(height * 0.5); % Base center Y position

    xVariation = round(width * CONFIG.PLStarCenterVariationX * (2 * rand() - 1)); % Variation in X 
    yVariation = round(height * CONFIG.PLStarCenterVariationY * (2 * rand() - 1)); % Variation in Y

    centerX = max(1, min(width, baseCenterX + xVariation));
    centerY = max(1, min(height, baseCenterY + yVariation));

    while isnan(waferData(centerY, centerX)) || waferData(centerY, centerX) == 0
        xVariation = round(width * CONFIG.PLStarCenterVariationX * (2 * rand() - 1));
        yVariation = round(height * CONFIG.PLStarCenterVariationY * (2 * rand() - 1));
        centerX = max(1, min(width, baseCenterX + xVariation));
        centerY = max(1, min(height, baseCenterY + yVariation));
    end

    minDimension = min(height, width);
    ellipseScale = CONFIG.PLStarEllipseScale * (1+(rand()-0.5) * CONFIG.PLStarEllipseScaleVariation);

    ellipseMinorAxis = round(minDimension * ellipseScale);
    ellipseMajorAxis = round(ellipseMinorAxis * CONFIG.PLStarEllipseYXRatio);

    ellipseMinorAxis = min(ellipseMinorAxis, width/2 - 10);
    ellipseMajorAxis = min(ellipseMajorAxis, height/2 - 10);
    
    maskMap = generatePLStar(width, height, centerX, centerY, ...
                            ellipseMinorAxis, ellipseMajorAxis, ...
                            CONFIG.PLStarWidth, waferData);
    
    simulatedMap = fillPLStarStructure(maskMap, waferData);

    maps.RawMap = waferData;
    maps.MaskMap = maskMap;
    maps.SimulatedMap = simulatedMap;
end 


function img = generatePLStar(width, height, centerX, centerY, ...
                            ellipseMinorAxis, ellipseMajorAxis, ...
                            lineWidth, waferImg)
    img = zeros(height, width, 'uint64');
    angles = [0, 60, 120, 180, 240, 300];
    anglesRad = deg2rad(angles);

    maxLength = max(width, height) * 2;
    xTemp = zeros(1, length(angles));
    yTemp = zeros(1, length(angles));

    for i = 1:length(angles)
        xTemp(i) = round(centerX + maxLength * cos(anglesRad(i)));
        yTemp(i) = round(centerY + maxLength * sin(anglesRad(i)));
    end

    xEnd = zeros(1, length(angles));
    yEnd = zeros(1, length(angles));
    validLines = 0;

    uniquePoints = containers.Map('KeyType', 'char', 'ValueType', 'any');

    for i = 1:length(angles)
        [xIntersect, yIntersect] = lineEllipseIntersection(centerX, centerY, xTemp(i), yTemp(i), ...
                                                            centerX, centerY, ellipseMinorAxis, ellipseMajorAxis);
    
        for j = 1:length(xIntersect)
            fprintf('Intersection %d: (%f, %f)\n', j, xIntersect(j), yIntersect(j));
        end

        if ~isempty(xIntersect)
            point1 = sprintf('%f, %f', xIntersect(1), yIntersect(1));
            if ~iskey(uniquePoints, point1)
                uniquePoints(point1) = true;
                validLines = validLines + 1;
                xEnd(i) = round(xIntersect(1));
                yEnd(i) = round(yIntersect(1));
            else
                fprintf('Warning: Duplicate intersection point found for angle %d:\n', angles(i));
                if length(xIntersect) > 1
                    point2 = sprintf('%f, %f', xIntersect(2), yIntersect(2));
                    if ~iskey(uniquePoints, point2)
                        uniquePoints(point2) = true;
                        xEnd(i) = round(xIntersect(2));
                        yEnd(i) = round(yIntersect(2));
                    else
                        fprintf('Warning: Duplicate intersection point found for angle %d:\n', angles(i));
                        xEnd(i) = xTemp(i);
                        yEnd(i) = yTemp(i);
                    end
                else
                    xEnd(i) = xTemp(i);
                    yEnd(i) = yTemp(i);
                end
            end
        else
            fprintf('Warning: No intersection found for angle %d.\n', angles(i));
            xEnd(i) = xTemp(i);
            yEnd(i) = yTemp(i);
        end
    end
    fprintf('PL Star: Center[%d, %d], Ellipse [%d, %d], Valid lines: %d/6.\n', ...
            centerX, centerY, ellipseMinorAxis, ellipseMajorAxis, validLines);

    for i = 1:length(angles)
        img = drawLine(img, waferImg, centerX, centerY, xEnd(i), yEnd(i), lineWidth);
    end
end


function [xIntersect, yIntersect] = lineEllipseIntersection(x1, y1, x2, y2, cx, cy, a, b)
    x1 = x1 - cx;
    y1 = y1 - cy;
    x2 = x2 - cx;
    y2 = y2 - cy;

    dx = x2 - x1;
    dy = y2 - y1;

    A = (dx*dx)/(a*a) + (dy*dy)/(b*b);
    B = 2 * (x1*dx/(a*a) + y1*dy/(b*b));
    C = (x1*x1)/(a*a) + (y1*y1)/(b*b) - 1;

    discriminant = B*B - 4*A*C;

    if discriminant < 0
        xIntersect = [];
        yIntersect = [];
        return;
    end

    t1 = (-B + sqrt(discriminant)) / (2*A);
    t2 = (-B - sqrt(discriminant)) / (2*A);

    xIntersect = [x1 + t1*dx, x1 + t2*dx] + cx;
    yIntersect = [y1 + t1*dy, y1 + t2*dy] + cy;

    dist1 = (xIntersect(1) - (x1+cx))^2 + (yIntersect(1) - (y1+cy))^2;
    dist2 = (xIntersect(2) - (x1+cx))^2 + (yIntersect(2) - (y1+cy))^2;

    if dist1 < dist2
        xIntersect = [xIntersect(2), xIntersect(1)];
        yIntersect = [yIntersect(2), yIntersect(1)];
    end
end

function img = drawLine(img, waferImg, x1, y1, x2, y2, width)
    % Get points on the line using Bresenham's algorithm
    [x, y] = bresenham(x1, y1, x2, y2);

    % Draw each point
    for i = 1:length(x)
        % Check if point is within image boundaries
        if x(i) < 1 || x(i) > size(img, 2) || y(i) < 1 || y(i) > size(img, 1)
            break;
            % continue; % Skip points outside the image
        end

        % Stop drawing if NaN is encountered in wafer image
        if isnan(waferImg(y(i), x(i))) || waferImg(y(i), x(i)) == 0
            break;
        end

        % Draw line with specified width
        for dx = -floor(width / 2):floor(width / 2)
            for dy = -floor(width / 2):floor(width / 2)
                % Calculate new position
                xi = min(max(x(i) + dx, 1), size(img, 2));
                yi = min(max(y(i) + dy, 1), size(img, 1));

                % Skip if wafer image at the position is NaN
                if isnan(waferImg(yi, xi))
                    break;
                    % continue;
                end

                % Set pixel value to 1
                img(yi, xi) = 1;
            end
        end
    end
end

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

        % Check if end point is reached
        if (x1 == x2 && y1 == y2) || ...
            ((sx > 0 && x1 >= x2) && (sy > 0 && y1 >= y2)) || ...
            ((sx < 0 && x1 <= x2) && (sy < 0 && y1 <= y2))
            break;
        end

        % Calculate decision parameter
        e2 = 2 * err;

        % Update error term and x coordinate
        if e2 > -dy
            err = err - dy;
            x1 = x1 + sx;
        end

        % Update error term and y coordinate
        if e2 < dx
            err = err + dx;
            y1 = y1 + sy;
        end
    end
end

function finalImg = fillPLStarStructure(masking, waferImg)
    % Parameter settings
    filterSize = 3;
    sigma = 2;
    thresholdLow = 0.001 / 0.8;
    thresholdMed = 0.002 / 0.8;
    thresholdHigh = 0.003 / 0.8;

    % Create Gaussian filter
    h = fspecial('gaussian', filterSize, sigma);
    backgroundSmoothed = imfilter(waferImg, h);

    % Handle NaN values in the smoothed background
    nanMask = isnan(backgroundSmoothed);
    backgroundSmoothed(nanMask & ~isnan(waferImg)) = waferImg(nanMask & ~isnan(waferImg));

    % Calculate the difference image
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
        noiseStd = 0.0001;
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
            scalingFactor = (1 - thresholdMed) + (thresholdMed - thresholdLow) * rand();
        elseif randProb < 0.7
            scalingFactor = (1 - thresholdHigh) + (thresholdHigh - thresholdMed) * rand();
        else
            scalingFactor = 1 + thresholdHigh * rand();
        end

        % Calculate new value and add noise
        newValue = backgroundValue * scalingFactor;
        % newValue = newValue + min(noiseStd, thresholdLow) * randn();

        % Update the final image
        finalImg(r, c) = newValue;
    end
end

function plotMaps(maps, coords, fileName, config)
    if ~exist(config.SavePlotFolderPath, 'dir')
        mkdir(config.SavePlotFolderPath);
    end

    timestamp = char(config.RunTime);

    figure(config.FigureNumber); clf;
    set(gcf, 'position', [100, 100, 1800, 500]);

    mapNames = fieldnames(maps);

    ax = zeros(1, length(mapNames));

    for i = 1:length(mapNames)
        mapName = mapNames{i};
        currentMap = maps.(mapName);

        if length(mapNames) > 3
            ax(i) = subplot(2, 3, i);
        else    
            ax(i) = subplot(1, length(mapNames), i);
        end

        if config.PlotInMm
            imagesc(coords.XMm, coords.YMm, currentMap);
        else
            imagesc(currentMap);
        end

        func_ChangeColorForNaN(gca);
        func_GetDataStatCurrROI(gca, true, [5, 95]);

        if config.PlotInMm
            xlabel('X (mm)');
            ylabel('Y (mm)');
        else
            xlabel('X (pixels)');
            ylabel('Y (pixels)');
        end

        axis tight; axis equal; colormap('jet'); colorbar();
        axis([1 coords.Width 1 coords.Height]);

        title(mapName, 'fontsize', 10, 'Interpreter', 'none');
        axis xy;
    end

    linkaxes(ax, 'xy');
    sgtitle(sprintf('File: %s', fileName), 'Interpreter', 'none', 'FontSize', 10);

    if ishandle(gcf)
        savePath = fullfile(config.SavePlotFolderPath, [timestamp, '_', fileName, '_plot.png']);
        saveas(gcf, savePath);
    else
        warning('Figure handle is not valid, cannot save plot.');
    end
end


%% Save Mask and pL star data
function saveMaskAndPLStar(maps, origFileName, config)
    % Get file name without extension
    [~, baseName, ~] = fileparts(origFileName);
    % Generate timestamp for filename
    timestamp = char(config.RunTime);
    % Create output directory if it doesn't exist
    outputDir = config.SaveResultFolderPath;
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    if ~exist(config.MaskOutputFolderPath, 'dir')
        mkdir(config.MaskOutputFolderPath);
    end
    if ~exist(config.PLStarOutputFolderPath, 'dir')
        mkdir(config.PLStarOutputFolderPath);
    end
    % Save Mask
    maskFile = fullfile(config.MaskOutputFolderPath, [timestamp, '_', baseName, '_mask.mat']);
    maskMap = maps.MaskMap;
    save(maskFile, 'maskMap');
    % Save modified pL star data
    plstarFile = fullfile(config.PLStarOutputFolderPath, [timestamp, '_', baseName, '_plstar.mat']);
    modifiedMap = maps.SimulatedMap;
    save(plstarFile, 'modifiedMap');
    fprintf('Saved results for %s\n', baseName);
end

%% Helper function for displaying titles
function sgtitle(txt, varargin)
    % Parse input arguments
    p = inputParser;
    addParameter(p, 'FontSize', 12, @isnumeric);
    addParameter(p, 'Interpreter', 'tex', @ischar);
    parse(p, varargin{:});
    
    fs = p.Results.FontSize;
    interpreter = p.Results.Interpreter;
    
    % Add overall title
    ax = axes('Position', [0, 0.95, 1, 0.05], 'Visible', 'off');
    if iscell(txt)
        for i = 1:length(txt)
            text(0.5, 1.1 - i * 0.1, txt{i}, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'top', 'FontSize', fs, 'FontWeight', 'bold', ...
                'Interpreter', interpreter);
        end
    else
        text(0.5, 1, txt, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'top', 'FontSize', fs, 'FontWeight', 'bold', ...
            'Interpreter', interpreter);
    end
end
