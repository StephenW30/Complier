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
    'PLstarWidth', 5, ...                          % Width of the PL star lines
    'PSF', struct(...                              % PSF parameters
        'Size', 9, ...                             % Size of PSF kernel (larger for smoother edges)
        'Sigma', 2.0, ...                          % Sigma for Gaussian PSF (larger for more diffuse effect)
        'DefectDepth', 0.0005 ...                  % Very subtle defect depth/contrast (0.05%)
    )...
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
    
    % Simulate filling PL star structure using PSF method
    simulateMap = fillPLStarStructure_PSF(maskMap, rawMap, config.PSF);
    
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
    % Create new figure with large size
    figure(config.FigureNumber); clf;
    
    % Set figure size to be large (width x height in pixels)
    set(gcf, 'Position', [100, 100, 1200, 800]);
    
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
            xlabel('x(mm)', 'FontSize', 12);
            ylabel('y(mm)', 'FontSize', 12);
        else
            xlabel('x(pixels)', 'FontSize', 12);
            ylabel('y(pixels)', 'FontSize', 12);
        end
        
        % Adjust axes and set colormap
        axis tight; axis equal;
        colormap('jet'); 
        c = colorbar();
        c.FontSize = 12;  % Increase colorbar font size
        
        % Set axis range
        if config.PlotInMm
            axis([-config.WaferSizeMm/2 config.WaferSizeMm/2 -config.WaferSizeMm/2 config.WaferSizeMm/2]);
        else
            axis([0 coords.Dimension 0 coords.Dimension]);
        end
        
        % Add title with larger font
        title(sprintf('%s', mapName), 'FontSize', 14, 'FontWeight', 'bold');
        
        % Ensure normal XY axis direction
        axis xy;
        
        % Increase tick label font size
        set(gca, 'FontSize', 12);
    end
    
    % Link all axes
    linkaxes(ax, 'xy');
    
    % Add super title with larger font
    tt = {sprintf('%s', config.FolderPath), sprintf('%s', config.HazeMapFile)};
    suptitle(tt, 14);
    
    % Add more space between subplots
    if length(mapNames) <= 3
        subplotSpacing = 0.04;  % Adjust this value as needed
        pos = get(ax, 'Position');
        if iscell(pos)
            for j = 1:length(pos)
                if j > 1
                    newPos = pos{j};
                    newPos(1) = newPos(1) + subplotSpacing;
                    set(ax(j), 'Position', newPos);
                end
            end
        end
    end
    
    % Make figure visible on top of other windows
    figure(config.FigureNumber);
    drawnow;
end

%% Helper Functions

% Fill PL Star Structure using PSF method
function finalImg = fillPLStarStructure_PSF(masking, waferImg, psfConfig)
    % PL Star filling using Point Spread Function (PSF) simulation
    % This approach models the optical properties of defects using PSF
    
    % Get PSF parameters
    psfSize = psfConfig.Size;          % Size of the PSF kernel
    psfSigma = psfConfig.Sigma;        % Sigma value for PSF Gaussian
    defectDepth = psfConfig.DefectDepth; % Defect strength
    
    % Additional parameters
    filterSize = 7;                     % Size of Gaussian filter for background (larger for smoother background)
    sigma = 1.5;                        % Sigma for background smoothing (increased for more blending)
    noiseLevel = 0.0001;                % Reduced noise level for subtle effect
    
    % 1. Create PSF kernel (Gaussian PSF model)
    [x, y] = meshgrid(-floor(psfSize/2):floor(psfSize/2), -floor(psfSize/2):floor(psfSize/2));
    psf = exp(-(x.^2 + y.^2)/(2*psfSigma^2));
    psf = psf / sum(psf(:));  % Normalize PSF to sum to 1
    
    % 2. Smooth background for reference values
    h = fspecial('gaussian', filterSize, sigma);
    backgroundSmoothed = imfilter(waferImg, h);
    
    % 3. Create a copy of the original image as starting point
    finalImg = waferImg;
    
    % 4. Generate defect pattern based on mask
    defectMap = zeros(size(masking));
    defectMap(masking == 1) = -defectDepth;  % Negative for reduction in intensity
    
    % 5. Apply PSF to simulate optical properties of the defect
    defectPSF = imfilter(defectMap, psf, 'replicate');
    
    % 6. Apply the PSF-modulated defect to the background (vectorized implementation)
    maskIndices = masking == 1;
    
    % Create very subtle noise with reduced amplitude
    randomNoise = noiseLevel * (rand(size(waferImg)) - 0.5);
    
    % Calculate scaling factors from PSF (ensure extremely subtle effect)
    scaleFactors = ones(size(waferImg)) + defectPSF;
    
    % Further dampen the effect to make it barely noticeable
    effectDampening = 0.7;  % Reduce effect by 30%
    scaleFactors = 1 + (scaleFactors - 1) * effectDampening;
    
    % Apply to masked areas with careful blending to avoid detectability
    % Expand the affected area slightly beyond mask for smoother transition
    expandedMask = imfilter(double(masking), fspecial('gaussian', 5, 1.5)) > 0.01;
    transitionMask = expandedMask & ~maskIndices;
    
    % Apply full effect to main mask
    finalImg(maskIndices) = backgroundSmoothed(maskIndices) .* scaleFactors(maskIndices) + randomNoise(maskIndices);
    
    % Apply reduced effect to transition area for smoother blending with background
    if any(transitionMask(:))
        transitionEffect = (scaleFactors(transitionMask) - 1) * 0.5 + 1;  % Half strength in transition zone
        finalImg(transitionMask) = backgroundSmoothed(transitionMask) .* transitionEffect + randomNoise(transitionMask) * 0.5;
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
