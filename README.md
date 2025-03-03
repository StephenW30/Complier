# Complier

```
%% PL Star Analysis Script
% Clear MATLAB workspace and close all figures
clear all; clc;
addpath('D:\stephen\git_Toolbox');  % Add the specified path to the MATLAB search path

iFigure = 100;  % Figure number for plotting

% Set folder path and parameters for data loading
strFolderPath = 'D:\Stephen\PL star\data\Surface_Inspection(0)_2025-02-01-19-10-39_SuperFine1Res';
% Name of the file to load
strHazeMap = 'P2cHaze_Grp[1]FT[MED]Res[100]ch[2]_03_Nppm';
% Pixel size in mm
pixelSizeMm = 0.1;
% Additional commented options for different configurations
% strHazeMap = 'P2cHaze _Grp[1]FT[MED]Res[200]ch[2]_03_Nppm';
% pixelSizeMm = 0.2;
% pixelSizeMm = 0.1;
% strHazeMap = 'P2CHaze Grp[1]FT[MED]Res[100]ch[2]_03';

% Wafer name
waferName = 'sc1 Wolfspeed';
% Wafer size in mm
waferSizeMm = 150;
% Plot in mm coordinates instead of pixels
bPlotInMm = 0;
strResolution = 'SuperFine1';  % Resolution setting (not used here)
% --------
% APS1 flag
bIsAPS1 = 0;

%% Load data
strFileNameFullPath = sprintf('%s\\%s.raw', strFolderPath, strHazeMap);
rawMap = openraw(strFileNameFullPath);
rawMap(rawMap == 0) = nan;
if (~bIsAPS1)
    rawMap = flipud(rawMap);
end

strMap = 'HazeMap';
maskMap = 'MaskMap';
simulateMap = 'simMap';
% Name of the map variable

map.(strMap) = rawMap;  % Store in the "map" structure

% Main script to generate and display the pL star image
imageSize = 1500;  % Set the size of the generated image(200x200)
% PLstarCenterX = 200;  % Center coordinates for the pl star
% PLstarCenterY = 750;
% PLstarCenterX = 1318;  % Center coordinates for the Pl star
% PLstarCenterY = 599;
PLstarCenterX = 764;  % Center coordinates for the pL star
PLstarCenterY = 1412;

L = 100;  % Length from the center to the outer vertices
W = 5;  % Width of the lines

% Call the function to generate and display the PL star image
maskmap = generate_plstar_manual(imageSize, PLstarCenterX, PLstarCenterY, L, W, rawMap);
map.(maskMap) = maskmap;
simulatemap = fill_pLstar_structure(maskmap, rawMap);
map.(simulateMap) = simulatemap;

%% Calculate coordinates for plotting
dim = waferSizeMm / pixelSizeMm;
waferCenter.xPixel = dim / 2;  % X-coordinate of the center (pixels)
waferCenter.yPixel = dim / 2;  % Y-coordinate of the center (pixels)

xMm = ((1:dim) - waferCenter.xPixel - 0.5) * pixelSizeMm;  % X-coordinates in mm
yMm = ((1:dim) - waferCenter.yPixel - 0.5) * pixelSizeMm;  % Y-coordinates in mm

%% Plotting setup
cellstrMapToPlot = {sprintf('map.%s', strMap), sprintf('map.%s', maskMap), sprintf('map.%s', simulateMap)};

% Create a new figure and clear it
figure(iFigure); clf;
ax = [];  % Initialize axes array for subplots

% Loop through each map to plot
for i = 1:length(cellstrMapToPlot)
    strMapToPlot = cellstrMapToPlot{i};  % Get the current map name
    mapToPlot = eval(strMapToPlot);      % Evaluate the string to get the data
    
    if (length(cellstrMapToPlot) > 3)
        ax(i) = subplot(2, 3, i);  % If more than 3 maps, arrange in 2x3 grid
    else
        ax(i) = subplot(1, length(cellstrMapToPlot), i);  % Otherwise, arrange horizontally
    end
    
    if (bPlotInMm)
        imagesc(xMm, yMm, mapToPlot);  % If plotting in mm coordinates
    else
        imagesc(mapToPlot);  % Otherwise, plot in pixel coordinates
    end
    
    func_ChangeColorForNaN(gca);  % Change color for NaN values (custom function)
    func_GetDataStatCurrROI(gca, true, [5 95]);  % Corrected function name here
    
    if (bPlotInMm)
        xlabel('x(mm)');
        ylabel('y(mm)');
    else
        xlabel('x(pixels)');
        ylabel('y(pixels)');
    end
    
    % Adjust axis limits and make it square
    axis tight; axis equal;
    colormap('jet'); colorbar();
    if (bPlotInMm)
        axis([-waferSizeMm/2 waferSizeMm/2 -waferSizeMm/2 waferSizeMm/2]);  % Set axis limits
    else
        axis([0 dim 0 dim]);  % Set axis limits
    end
    title(sprintf('%s', strMapToPlot), 'fontsize', 7);  % Add title to each subplot
    axis xy;  % Ensure x-axis comes first (for image display)
end

linkaxes(ax, 'xy');  % Link axes across subplots for consistent view

% Create supertitle with folder path and filename
tt = {sprintf('%s', strFolderPath), sprintf('%s', strHazeMap)};
suptitle(tt, 10);  % Add supertitle to the figure

% End of script
return;

%% Helper Functions

function final_img = fill_pLstar_structure(masking, wafer_img)
    filter_size = 5;
    sigma = 1;
    noise_level = 0.0002;
    thres_l = 0.0005;
    thres_m = 0.001;
    thres_h = 0.003;
    
    h = fspecial('gaussian', filter_size, sigma);
    background_smoothed = imfilter(wafer_img, h);
    
    final_img = wafer_img;
    [rows, cols] = find(masking == 1);
    
    for i = 1:length(rows)
        r = rows(i);
        c = cols(i);
        background_value = background_smoothed(r, c);
        rand_prob = rand();
        
        if rand_prob < 0.3
            scaling_factor = (1 - thres_m + (thres_m - thres_l) * rand());
        else
            scaling_factor = (1 - thres_h + (thres_h - thres_m) * rand());
        end
        
        new_value = background_value * scaling_factor;
        new_value = new_value + noise_level * rand();
        final_img(r, c) = new_value;
    end
end

function img = generate_plstar_manual(image_size, PLstarCenterX, PLstarCenterY, L, W, wafer_img)
    % Manually drawn Pentagram or Lozenge (PL star) structure
    % This function generates an image with PL star structure
    % Parameters:
    % image_size: The size of the generated image (image_size x image_size)
    % PLstarCenterX, PLstarCenterY: The center coordinates of the PL star
    % L: The length from the center to the outer vertices of the PL star
    % W: The width of the lines forming the PL star

    % Initialize an empty binary image with zeros (0-1 range)
    img = zeros(image_size, image_size, 'uint8');

    % If not provided a wafer_img, then create an all black wafer img
    if nargin < 6 || isempty(wafer_img)
        wafer_img = zeros(image_size, image_size, 'double');
    else
        wafer_img = double(wafer_img);
    end

    % Define the angles for the 6 points of the PL star in degrees
    angles = [0, 60, 120, 180, 240, 300];

    % Convert these angles to radians
    anglesRad = deg2rad(angles);

    % Calculate the end coordinates for each line of the star
    x_end = round(PLstarCenterX + L*cos(anglesRad));
    y_end = round(PLstarCenterY + L*sin(anglesRad));

    % Loop through each pair of points to draw a line between them
    for i = 1:6
        img = drawLine(img, wafer_img, PLstarCenterX, PLstarCenterY, x_end(i), y_end(i), W);
    end

    % Display the generated image with a title
    % imshow(img, []);
    % title('PL star structure');
    % colorbar;
    % axis square;
    % axis on;
end

function img = drawLine(img, wafer_img, x1, y1, x2, y2, width)
    % This function draws a line on an existing binary image using the Bresenham's algorithm
    % Parameters:
    % img: The existing binary image where the line will be drawn
    % x1, y1: The starting coordinates of the line
    % x2, y2: The ending coordinates of the line
    % width: The thickness of the line

    % Get the points that make up the line using Bresenham's algorithm
    [x, y] = bresenham(x1, y1, x2, y2);

    % Draw each point of the line with the specified width and set it to 1 (binary)
    for i = 1:length(x)
        % Check if point is within the boundary of the image
        if x(i) < 1 || x(i) > size(img, 2) || y(i) < 1 || y(i) > size(img, 1)
            continue;
        end
        
        % Check the NaN value, if meet then stop drawing
        if isnan(wafer_img(y(i), x(i)))
            break;
        end
        
        for dx = -floor(width/2):floor(width/2)
            for dy = -floor(width/2):floor(width/2)
                % Compute new position
                xi = min(max(x(i) + dx, 1), size(img, 2));
                yi = min(max(y(i) + dy, 1), size(img, 1));
                
                if isnan(wafer_img(yi, xi))
                    continue;
                end
                
                img(yi, xi) = 1;
            end
        end
    end
end

function [x, y] = bresenham(x1, y1, x2, y2)
    % Round the input coordinates for consistency
    x1 = round(x1); 
    x2 = round(x2); 
    y1 = round(y1); 
    y2 = round(y2);

    % Calculate differences in x and y directions
    dx = abs(x2 - x1);
    dy = abs(y2 - y1);

    % Determine the increment direction for x and y
    sx = sign(x2 - x1);
    sy = sign(y2 - y1);

    % Initialize error term
    err = dx - dy;

    % Initialize empty arrays to store line points
    x = [];
    y = [];

    % Main loop of Bresenham's algorithm
    while true
        % Store the current point
        x = [x; x1];
        y = [y; y1];
        
        % Check if we have reached the end point
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
```
