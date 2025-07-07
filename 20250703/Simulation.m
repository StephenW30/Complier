clear; close all; clc;
addpath('D:\stephen\git_Toolbox');

% Define base input and output directories
baseInputDir  = 'D:\stephen\PL Star\customized_dataset\3-second_round_clean_with_Bosch_remove';
baseOutputDir = 'D:\stephen\PL Star\customized_dataset\6-sixth_round_hazedata_with_plstar';

% Core configuration for PLstar simulation initialization
CONFIG = struct( ...
    'FigureNumber',            100, ...
    'OriginalFolderPath',      baseInputDir, ...
    'SaveResultFolderPath',    baseOutputDir, ...
    'MaskOutputFolderPath',    fullfile(baseOutputDir, 'label'), ...
    'PLstarOutputFolderPath',  fullfile(baseOutputDir, 'simulation_hazemap'), ...
    'SavePlotFolderPath',      fullfile(baseOutputDir, 'visualization_result'), ...
    'PLstarEllipseYXRatio',    2.0, ...
    'PLstarEllipseScale',      0.1, ...
    'PLstarWidth',             3.0, ...
    'PlotInMm',                false ...
);

% Additional configuration parameters
CONFIG.FlipVertical = true;
CONFIG.PLstarEllipseScaleVariation = 0.3;
CONFIG.PLstarCenterVariationX = 0.15;
CONFIG.PLstarCenterVariationY = 0.2;
CONFIG.RunTime = datetime('now', 'Format', 'MMdd_HHmmss');

matFiles = dir(fullfile(CONFIG.OriginalFolderPath, '*.mat'));
fprintf("Found %d .mat files in the original folder.\n", length(matFiles));

% Porcess each .mat file
for i = 1:length(matFiles)
    fprintf("Processing file %d/%d: %s\n", i, length(matFiles), matFiles(i).name);
    CONFIG.PLstarWidth = randi([2, 7]);  % Random width between 2 and 7
    [waferData, waferInfo] = loadMatData(fullfile(CONFIG.OriginalFolderPath, matFiles(i).name), CONFIG);
    maps = generatePLStarMaps(waferData, waferInfo, CONFIG);
    coords = calculateCoordinates(waferInfo);
    plotMaps(maps, coords, matFiles(i).name, CONFIG);
    saveMaskAndPLStar(maps, matFiles(i).name, CONFIG);
end

fprintf("All files processed successfully.\n");

function [waferData, waferInfo] = loadMatData(filePath, CONFIG)
    matData = load(filePath);
    waferInfo = struct();

    if isfield(matData, 'dw_image')
        waferData = matData.dw_image;
    else
        error('The file %s does not contain the expected "dw_image" field.', filePath);
    end

    if isfield(matData, 'waferData')
        waferInfo.Name = matData.waferName;
    else
        [~, waferInfo.Name, ~] = fileparts(filePath);
    end

    % Replace 0 values with NaN
    waferData(waferData == 0) = NaN;
    waferData(waferData == 3158064) = NaN;  % Handle specific case for 3158064
    waferData(waferData == min(waferData(:))) = NaN;  % Handle minimum value case

    if ~isequal(size(waferData), [1500, 1500])
        waferData = imresize(waferData, [1500, 1500], 'nearest');
    end

    waferInfo.shape = size(waferData);

    if isfield(matData, 'pixelSizeMm')
        waferInfo.pixelSizeMm = matData.pixelSizeMm;
    else
        waferInfo.pixelSizeMm = 0.1;  % Default pixel size if not provided
    end

    if CONFIG.FlipVertical
        waferData = flipud(waferData);  % Flip the data vertically if specified
    end

    disp(waferInfo);
end

function coords = calculateCoordinates(waferInfo)
    height = waferInfo.shape(1);
    width = waferInfo.shape(2);

    centerX = round(width / 2);
    centerY = round(height / 2);

    xPixels = 1:width;
    yPixels = 1:height;

    if isfield(waferInfo, 'pixelSizeMm')
        xMm = (xPixels - centerX - 0.5) * waferInfo.pixelSizeMm;
        yMm = (yPixels - centerY - 0.5) * waferInfo.pixelSizeMm;
    else
        xMm = xPixels;
        yMm = yPixels;
    end

    coords = struct('Width', width, 'Height', height, ...
                    'XPixels', xPixels, 'YPixels', yPixels, ...
                    'XMm', xMm, 'YMm', yMm);
end
       

function maps = generatePLStarMaps(waferData, waferInfo, CONFIG)
    maps = struct();
    height = waferInfo.shape(1);
    width = waferInfo.shape(2);

    baseCenterX = round(width * 0.85);
    baseCenterY = round(height * 0.5);

    xVariation = round(width * CONFIG.PLstarCenterVariationX * (3 * rand() - 1));   % Random variation in X direction
    yVariation = round(height * CONFIG.PLstarCenterVariationY * (3 * rand() - 1));

    centerX = max(1, min(width, baseCenterX + xVariation));
    centerY = max(1, min(height, baseCenterY + yVariation));

    while isnan(waferData(centerY, centerX)) || waferData(centerY, centerX) == 0
        xVariation = round(width * CONFIG.PLstarCenterVariationX * (3 * rand() - 1));
        yVariation = round(height * CONFIG.PLstarCenterVariationY * (3 * rand() - 1));
       
        centerX = max(1, min(width, baseCenterX + xVariation));
        centerY = max(1, min(height, baseCenterY + yVariation));
    end

    minDimension = min(height, width);
    ellipseScale = CONFIG.PLstarEllipseScale * (1 + (rand() - 0.5) * CONFIG.PLstarEllipseScaleVariation);
    ellipseMinorAxis = round(minDimension * ellipseScale);
    ellipseMajorAxis = round(ellipseMinorAxis * CONFIG.PLstarEllipseYXRatio);

    % Ensure ellipse axes are within bounds
    ellipseMinorAxis = min(ellipseMinorAxis, minDimension / 2 - 10);
    ellipseMajorAxis = min(ellipseMajorAxis, minDimension / 2 - 10);

    maskMap = generatePLStar(width, height, centerX, centerY, ellipseMinorAxis, ellipseMajorAxis, CONFIG.PLstarWidth, waferData);
    simulateMap = filPLStarStructure(maskMap, waferData);

    maps.RawMap = waferData;
    maps.MaskMap = maskMap;
    maps.SimulateMap = simulateMap;
end
    

function img = generatePLStar(width, height, centerX, centerY, ellipseMinor, ellipseMajor, lineWidth, waferImg)
    img = zeros(height, width, 'uint64');  % Initialize the image with zeros
    angles = [0, 60, 120, 180, 240, 300];  % Angles for the six lines
    anglesRad = deg2rad(angles);  % Convert angles to radians
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
        [xIntersect, yIntersect] = lineEllipseIntersection(centerX, centerY, xTemp(i), yTemp(i), centerX, centerY, ellipseMinor, ellipseMajor);
        for j = 1:length(xIntersect)
            fprintf('Intersection point %d: (%.2f, %.2f)\n', j, xIntersect(j), yIntersect(j));
        end

        % Check if intersection points are valid
        if ~isempty(xIntersect)
            point1 = sprintf('%.2f_%.2f', xIntersect(1), yIntersect(1));
            if ~isKey(uniquePoints, point1)
                uniquePoints(point1) = true;  % Store the unique point
                xEnd(i) = round(xIntersect(1));
                yEnd(i) = round(yIntersect(1));
                validLines = validLines + 1;
            else
                fprintf('Warning: Duplicate intersection point found for angle %.2f\n', angles(i));
                if length(xIntersect) > 1
                    point2 = sprintf('%.2f_%.2f', xIntersect(2), yIntersect(2));
                    if ~isKey(uniquePoints, point2)
                        uniquePoints(point2) = true;  % Store the unique point
                        xEnd(i) = round(xIntersect(2));
                        yEnd(i) = round(yIntersect(2));
                    else
                        fprintf('Warning: Both intersection points are duplicates for angle %.2f\n', angles(i));
                        xEnd(i) = xTemp(i);
                        yEnd(i) = yTemp(i);
                    end
                else
                    xEnd(i) = xTemp(i);
                    yEnd(i) = yTemp(i);
                end
            end
        else
            % No intersection found, use the original end points
            xEnd(i) = xTemp(i);
            yEnd(i) = yTemp(i);
            fprintf('Warning: No intersection found for angle %.2f.\n', angles(i));
        end
    end

    fprintf('PL star: Center[%d, %d], Ellipse[%d, %d], Valid Lines: %d/6\n', ...
        centerX, centerY, ellipseMinor, ellipseMajor, validLines);
    
    % Draw the lines on the image
    for i = 1:length(angles)
        img = drawLine(img, waferImg, centerX, centerY, xEnd(i), yEnd(i), lineWidth);
    end
end

function [xIntersect, yIntersect] = lineEllipseIntersection(x1, y1, x2, y2, cx, cy, a, b)
    x1 = x1 - cx;  % Translate to ellipse center
    y1 = y1 - cy;  % Translate to ellipse center
    x2 = x2 - cx;  % Translate to ellipse center
    y2 = y2 - cy;  % Translate to ellipse center

    dx = x2 - x1; 
    dy = y2 - y1;

    A = (dx^2 / a^2) + (dy^2 / b^2);
    B = (2 * x1 * dx / a^2) + (2 * y1 * dy / b^2);
    C = (x1^2 / a^2) + (y1^2 / b^2) - 1;

    discriminant = B^2 - 4 * A * C;

    if discriminant < 0
        xIntersect = [];  % No intersection
        yIntersect = [];
        return;
    end

    % Calculate the two intersection points
    t1 = (-B + sqrt(discriminant)) / (2 * A);
    t2 = (-B - sqrt(discriminant)) / (2 * A);

    xIntersect = [x1 + t1 * dx, x1 + t2 * dx] + cx;  % Translate back to original coordinates
    yIntersect = [y1 + t1 * dy, y1 + t2 * dy] + cy;  % Translate back to original coordinates

    % Filter out points that are not within the line segment
    dist1 = (xIntersect(1) - (x1+cx))^2 + (yIntersect(1) - (y1+cy))^2;  % Distance from first intersection point to line start
    dist2 = (xIntersect(2) - (x1+cx))^2 + (yIntersect(2) - (y1+cy))^2;  % Distance from second intersection point to line start

    if dist2 < dist1
        % Ensure the first point is the closer one
        xIntersect = [xIntersect(2), xIntersect(1)];
        yIntersect = [yIntersect(2), yIntersect(1)];
    end
end

function img = drawLine(img, waferImg, x1, y1, x2, y2, width)
    % Draw a line on the image using Bresenham's algorithm
    [x, y] = bresenham(x1, y1, x2, y2);
    
    for i = 1:length(x)
        if x(i) < 1 || x(i) > size(img, 2) || y(i) < 1 || y(i) > size(img, 1)
            break;   % Skip out-of-bounds coordinates
        end

        if isnan(waferImg(y(i), x(i)))
            break;  % Skip NaN values
        end

        for dx = -floor(width/2) : floor(width/2)
            for dy = -floor(width/2) : floor(width/2)
                xi = min(max(x(i) + dx, 1), size(img, 2));
                yi = min(max(y(i) + dy, 1), size(img, 1));
                if isnan(waferImg(yi, xi))
                    break;
                end
                img(yi, xi) = 1;
            end
        end
    end
end

function [x, y] = bresenham(x1, y1, x2, y2)
    x1 = round(x1);
    y1 = round(y1);
    x2 = round(x2);
    y2 = round(y2);
    
    dx = abs(x2 - x1);
    dy = abs(y2 - y1);

    sx = sign(x2 - x1);
    sy = sign(y2 - y1);

    err = dx - dy;

    x = [];
    y = [];

    while true
        x = [x; x1];
        y = [y; y1];
        if (x1 == x2 && y1 == y2) || ((sx > 0 && x1 >= x2) && (sy > 0 && y1 >= y2)) || ((sx < 0 && x1 <= x2) && (sy < 0 && y1 <= y2))
            break;
        end
        e2 = 2 * err;
        if e2 > -dy
            err = err - dy;
            x1 = x1 + sx;
        end

        if e2 < dx
            err = err + dx;
            y1 = y1 + sy;
        end
    end
end


function finalImg = filPLStarStructure(masking, waferImg)
    filterSize = 3;
    sigma = 2;
    thresholdLow = 0.001;
    thresholdMid = 0.002;
    thresholdHigh = 0.003;

    % Create a mask for the PL Star structure
    h = fspecial('gaussian', filterSize, sigma);
    backgroundSmoothed = imfilter(waferImg, h);
    nanMask = isnan(backgroundSmoothed);
    backgroundSmoothed(nanMask & ~isnan(waferImg)) = waferImg(nanMask & ~isnan(waferImg));
    diffImg = waferImg - backgroundSmoothed;

    % Convert diffImg to double for processing
    maskIndices = logical(masking);
    diffValues = double(diffImg(maskIndices));
    if ~isempty(diffValues)
        noiseMean = mean(diffValues, 'omitnan');
        noiseStd = std(diffValues, 'omitnan');
    else
        noiseMean = 0;
        noiseStd = 0.0001;  % Default to avoid division by zero
    end
    disp(['Noise Mean: ', num2str(noiseMean), ', Noise Std: ', num2str(noiseStd)]);

    finalImg = waferImg;  % Initialize final image
    [row, col] = find(maskIndices);
    for i = 1:length(row)
        r = row(i);
        c = col(i);
        backgroundValue = backgroundSmoothed(r, c);
        randProb = rand();

        % Choose scaling factor based on random probability
        if randProb < 0.3
            scaleFactor = (1 - thresholdMid + (thresholdMid - thresholdLow) * rand());
        else
            scaleFactor = (1 - thresholdHigh + (thresholdHigh - thresholdMid) * rand());
        end
        newValue = backgroundValue * scaleFactor;
        finalImg(r, c) = newValue;
    end
end

%% Function to plot maps and save the figure
function plotMaps(maps, coords, fileName, CONFIG)
    if ~exist(CONFIG.SavePlotFolderPath, 'dir')
        mkdir(CONFIG.SavePlotFolderPath);
    end
    timestamp = char(CONFIG.RunTime);
    
    figure(CONFIG.FigureNumber); clf;
    set(gcf, 'Position', [100, 100, 1800, 500]);

    mapNames = fieldnames(maps);
    ax = zeros(1, length(mapNames));
    for i = 1:length(mapNames)
        mapName = mapNames{i};  % Get the name of the map
        currentMap = maps.(mapName);  % Access the map data

        if length(mapName) > 3
            ax(i) = subplot(2, 3, i);
        else
            ax(i) = subplot(1, length(mapNames), i);
        end

        if CONFIG.PlotInMm
            imagesc(coords.XMm, coords.YMm, currentMap);
        else
            imagesc(currentMap);
        end

        func_ChangeColorForNaN(gca); 
        func_GetDataStatCurrROI(gca, true, [5 95]);

        if CONFIG.PlotInMm
            xlabel('X (mm)');
            ylabel('Y (mm)');
        else
            xlabel('X (pixels)');
            ylabel('Y (pixels)');
        end

        axis tight; axis equal; colormap('jet'); colorbar();
        axis([1 coords.width 1 coords.height]);
        title(mapName, 'Interpreter', 'none', 'FontSize', 10);
        axis xy;
    end

    linkaxes(ax, 'xy');
    sgtitle(sprintf('File: %s', fileName), 'Interpreter', 'none', 'FontSize', 10, 'FontWeight', 'bold');

    if ishandle(gcf)
        savePath = fullfile(CONFIG.SavePlotFolderPath, [timestamp, '_', fileName, '_plot.png']);
        saveas(gcf, savePath);
    else
        warning('Figure handle is not valid. Skipping save operation.');
    end
    fprintf("Saved plot for %s\n", fileName);
end

%% Save Mask and PL Star Data
function saveMaskAndPLStar(maps, OrigFileName, CONFIG)
    [~, baseName, ~] = fileparts(OrigFileName);
    timestamp = char(CONFIG.RunTime);
    outputDir = CONFIG.SaveResultFolderPath;

    % Create all required directories
    dirs = {outputDir, CONFIG.MaskOutputFolderPath, CONFIG.PLstarOutputFolderPath};
    for i = 1:length(dirs)
        if ~exist(dirs{i}, 'dir')
            mkdir(dirs{i});
        end
    end

    % Save the mask and PL Star data
    maskFile = fullfile(CONFIG.MaskOutputFolderPath, [timestamp, '_', baseName, '_Mask.mat']);
    maskMap = maps.MaskMap;
    save(maskFile, 'maskMap');

    plStarFile = fullfile(CONFIG.PLstarOutputFolderPath, [timestamp, '_', baseName, '_PLStar.mat']);
    modifiedMap = maps.SimulateMap;
    save(plStarFile, 'modifiedMap');

    fprintf("Saved mask and PL Star data for %s\n", baseName);
end


%% Helper function to add a centered title above subplots
function suptitle(txt, fs)
    if nargin < 2
        fs = 12;
    end
    ax = axes('Position', [0, 0.95, 1, 0.05], 'Visible', 'off');
    if iscell(txt)
        for i = 1:length(txt)
            text(0.5, 1.1-i*0.1, txt{i}, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'top', 'FontSize', fs, 'FontWeight', 'bold');
        end
    else
        text(0.5, 1.1, txt, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'top', 'FontSize', fs, 'FontWeight', 'bold');
    end 
end 
