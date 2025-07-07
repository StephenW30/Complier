%% Main Script: Batch PL Star Simulation with Multiple Stars & Line Gaps
clear; close all; clc;
addpath('D:\stephen\git_Toolbox');

% Define base input and output directories
baseInputDir  = 'D:\stephen\PL Star\customized_dataset\3-second_round_clean_with_Bosch_remove';
baseOutputDir = 'D:\stephen\PL Star\customized_dataset\6-sixth_round_hazedata_with_plstar_testc';

% Core configuration for PLstar simulation initialization
CONFIG = struct( ...
    'FigureNumber',               100, ...
    'OriginalFolderPath',         baseInputDir, ...
    'SaveResultFolderPath',       baseOutputDir, ...
    'MaskOutputFolderPath',       fullfile(baseOutputDir, 'label'), ...
    'PLstarOutputFolderPath',     fullfile(baseOutputDir, 'simulation_hazemap'), ...
    'SavePlotFolderPath',         fullfile(baseOutputDir, 'visualization_result'), ...
    'PLstarEllipseYXRatio',       2.0, ...
    'PLstarEllipseScale',         0.1, ...
    'PLstarWidth',                3.0, ...
    'PlotInMm',                   false, ...
    'FlipVertical',               true, ...
    'PLstarEllipseScaleVariation',0.3, ...
    'PLstarCenterVariationX',     0.15, ...
    'PLstarCenterVariationY',     0.2, ...
    'RunTime',                    datetime('now', 'Format', 'MMdd_HHmmss') ...
);

% Find all .mat files
matFiles = dir(fullfile(CONFIG.OriginalFolderPath, '*.mat'));
fprintf("Found %d .mat files in the original folder.\n", length(matFiles));

% Process each .mat file
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



%% Function: Load .mat Data
function [waferData, waferInfo] = loadMatData(filePath, CONFIG)
    matData = load(filePath);
    waferInfo = struct();

    if isfield(matData, 'dw_image')
        waferData = matData.dw_image;
    else
        error('The file %s does not contain the expected "dw_image" field.', filePath);
    end

    if isfield(matData, 'waferName')
        waferInfo.Name = matData.waferName;
    else
        [~, waferInfo.Name, ~] = fileparts(filePath);
    end

    % Replace invalid values with NaN
    waferData(waferData == 0) = NaN;
    waferData(waferData == 3158064) = NaN;
    waferData(waferData == min(waferData(:))) = NaN;

    % Resize if necessary
    if ~isequal(size(waferData), [1500, 1500])
        waferData = imresize(waferData, [1500, 1500], 'nearest');
    end

    waferInfo.shape = size(waferData);

    if isfield(matData, 'pixelSizeMm')
        waferInfo.pixelSizeMm = matData.pixelSizeMm;
    else
        waferInfo.pixelSizeMm = 0.1;
    end

    if CONFIG.FlipVertical
        waferData = flipud(waferData);
    end

    disp(waferInfo);
end


%% Function: Calculate Coordinates for Plotting
function coords = calculateCoordinates(waferInfo)
    height = waferInfo.shape(1);
    width  = waferInfo.shape(2);

    centerX = round(width/2);
    centerY = round(height/2);

    xPixels = 1:width;
    yPixels = 1:height;

    xMm = (xPixels - centerX - 0.5) * waferInfo.pixelSizeMm;
    yMm = (yPixels - centerY - 0.5) * waferInfo.pixelSizeMm;

    coords = struct(...
        'Width',  width,  ...
        'Height', height, ...
        'XPixels', xPixels,...
        'YPixels', yPixels,...
        'XMm',    xMm,    ...
        'YMm',    yMm     ...
    );
end


%% Function: Generate Multiple PL Stars and Composite Maps
function maps = generatePLStarMaps(waferData, waferInfo, CONFIG)
    [height, width] = size(waferData);

    % Randomly choose 1–3 PL Stars
    numStars = randi([1,3]);
    maskMap  = false(height, width);
    centers  = zeros(numStars, 2);

    for s = 1:numStars
        % Base center and random offset
        baseX = round(width * 0.85);
        baseY = round(height * 0.5);
        dx = round(width  * CONFIG.PLstarCenterVariationX * (2*rand()-1));
        dy = round(height * CONFIG.PLstarCenterVariationY * (2*rand()-1));
        cx = min(max(1, baseX + dx), width);
        cy = min(max(1, baseY + dy), height);

        % Ensure valid (not NaN) center
        while isnan(waferData(cy, cx))
            dx = round(width  * CONFIG.PLstarCenterVariationX * (2*rand()-1));
            dy = round(height * CONFIG.PLstarCenterVariationY * (2*rand()-1));
            cx = min(max(1, baseX + dx), width);
            cy = min(max(1, baseY + dy), height);
        end
        centers(s,:) = [cx, cy];

        % Ellipse axes with variation
        minDim = min(height, width);
        scale  = CONFIG.PLstarEllipseScale * (1 + (rand()-0.5)*CONFIG.PLstarEllipseScaleVariation);
        minor  = round(minDim * scale);
        major  = round(minor   * CONFIG.PLstarEllipseYXRatio);
        minor  = min(minor, minDim/2 - 10);
        major  = min(major, minDim/2 - 10);

        % Generate single-star mask and composite
        starMask = generatePLStar(width, height, cx, cy, minor, major, CONFIG.PLstarWidth, waferData);
        maskMap  = maskMap | starMask;
    end

    simulateMap = filPLStarStructure(maskMap, waferData);

    maps = struct(...
        'RawMap',      waferData, ...
        'MaskMap',     maskMap,  ...
        'SimulateMap', simulateMap,...
        'Centers',     centers    ...
    );
end


%% Function: Generate One PL Star with Random Line Gaps
function img = generatePLStar(width, height, cx, cy, a, b, lineWidth, waferImg)
    img    = false(height, width);
    angles = [0, 60, 120, 180, 240, 300];
    angRad = deg2rad(angles);
    maxLen = max(width, height)*2;

    % Compute raw endpoints
    xTemp = cx + maxLen*cos(angRad);
    yTemp = cy + maxLen*sin(angRad);

    for i = 1:6
        % Intersection with ellipse
        [xI, yI] = lineEllipseIntersection(cx, cy, xTemp(i), yTemp(i), cx, cy, a, b);
        if isempty(xI)
            xE = round(xTemp(i));
            yE = round(yTemp(i));
        else
            xE = round(xI(1));
            yE = round(yI(1));
        end

        % Draw the full line
        img = drawLine(img, waferImg, cx, cy, xE, yE, lineWidth);

        % Randomly introduce a gap
        if rand()<0.5
            [xLine, yLine] = bresenham(cx, cy, xE, yE);
            L = numel(xLine);
            segLen   = randi([5, max(5, floor(L/5))]);
            startIdx = randi([floor(L*0.2), max(floor(L*0.2), floor(L*0.8)-segLen)]);
            for k = startIdx : startIdx+segLen
                for dx = -floor(lineWidth/2):floor(lineWidth/2)
                    for dy = -floor(lineWidth/2):floor(lineWidth/2)
                        xi = xLine(k)+dx; yi = yLine(k)+dy;
                        if xi>=1 && xi<=width && yi>=1 && yi<=height
                            img(yi, xi) = false;
                        end
                    end
                end
            end
        end
    end
end


%% Function: Line–Ellipse Intersection
function [xIntersect, yIntersect] = lineEllipseIntersection(x1, y1, x2, y2, cx, cy, a, b)
    x1 = x1 - cx;  y1 = y1 - cy;
    x2 = x2 - cx;  y2 = y2 - cy;
    dx = x2 - x1;  dy = y2 - y1;

    A = (dx^2/a^2) + (dy^2/b^2);
    B = 2*(x1*dx/a^2 + y1*dy/b^2);
    C = (x1^2/a^2 + y1^2/b^2 - 1);

    D = B^2 - 4*A*C;
    if D<0
        xIntersect = []; yIntersect = [];
        return;
    end

    t1 = (-B+sqrt(D))/(2*A);
    t2 = (-B-sqrt(D))/(2*A);
    pts = [x1+t1*dx, x1+t2*dx; y1+t1*dy, y1+t2*dy]';
    pts = pts + [cx, cy];

    % Order by closeness to start
    d1 = sum((pts(1,:)-[cx,cy]).^2);
    d2 = sum((pts(2,:)-[cx,cy]).^2);
    if d2<d1, pts = flipud(pts); end

    xIntersect = pts(:,1)';
    yIntersect = pts(:,2)';
end


%% Function: Bresenham Line & Width Draw
function imgOut = drawLine(imgIn, waferImg, x1, y1, x2, y2, width)
    imgOut = imgIn;
    [xs, ys] = bresenham(x1, y1, x2, y2);
    for idx = 1:numel(xs)
        if isnan(waferImg(ys(idx), xs(idx))), break; end
        for dx = -floor(width/2):floor(width/2)
            for dy = -floor(width/2):floor(width/2)
                xi = xs(idx)+dx; yi = ys(idx)+dy;
                if xi<1||xi>size(imgIn,2)||yi<1||yi>size(imgIn,1), continue; end
                if ~isnan(waferImg(yi,xi))
                    imgOut(yi,xi) = true;
                end
            end
        end
    end
end

function [x, y] = bresenham(x1,y1,x2,y2)
    x1=round(x1); y1=round(y1);
    x2=round(x2); y2=round(y2);
    dx=abs(x2-x1); dy=abs(y2-y1);
    sx=sign(x2-x1); sy=sign(y2-y1);
    err=dx-dy;
    x=[]; y=[];
    while true
        x(end+1)=x1; y(end+1)=y1;
        if x1==x2 && y1==y2, break; end
        e2 = 2*err;
        if e2>-dy, err=err-dy; x1=x1+sx; end
        if e2< dx, err=err+dx; y1=y1+sy; end
    end
end


%% Function: Simulate PL Star Structure Overlay
function finalImg = filPLStarStructure(masking, waferImg)
    filterSize    = 3; sigma = 2;
    thresholdLow  = 0.001;
    thresholdMid  = 0.002;
    thresholdHigh = 0.003;

    h = fspecial('gaussian', filterSize, sigma);
    bg = imfilter(waferImg, h);
    nanMask = isnan(bg);
    bg(nanMask & ~isnan(waferImg)) = waferImg(nanMask & ~isnan(waferImg));
    diffImg = waferImg - bg;

    idx = masking;
    vals = double(diffImg(idx));
    if ~isempty(vals)
        m = mean(vals, 'omitnan');
        s = std(vals,  'omitnan');
    else
        m = 0; s = 1e-4;
    end
    disp(['Noise Mean: ', num2str(m), ', Std: ', num2str(s)]);

    finalImg = waferImg;
    [rows, cols] = find(idx);
    for k = 1:numel(rows)
        r = rows(k); c = cols(k);
        base = bg(r,c);
        p = rand();
        if p<0.3
            scale = (1-thresholdMid) + (thresholdMid-thresholdLow)*rand();
        else
            scale = (1-thresholdHigh)+(thresholdHigh-thresholdMid)*rand();
        end
        finalImg(r,c) = base * scale;
    end
end


%% Function: Plot Maps and Save Figures
function plotMaps(maps, coords, fileName, CONFIG)
    if ~exist(CONFIG.SavePlotFolderPath, 'dir')
        mkdir(CONFIG.SavePlotFolderPath);
    end
    timestamp = char(CONFIG.RunTime);

    figure(CONFIG.FigureNumber); clf;
    set(gcf, 'Position', [100,100,1800,500]);

    mapNames = fieldnames(maps);
    n = numel(mapNames);
    ax = gobjects(1,n);

    for i = 1:n
        ax(i) = subplot(1,n,i);
        M = maps.(mapNames{i});
        if CONFIG.PlotInMm
            imagesc(coords.XMm, coords.YMm, M);
            xlabel('X (mm)'); ylabel('Y (mm)');
        else
            imagesc(M);
            xlabel('X (pixels)'); ylabel('Y (pixels)');
        end
        func_ChangeColorForNaN(gca);
        func_GetDataStatCurrROI(gca, true, [5 95]);
        axis equal tight; axis([1 coords.Width 1 coords.Height]);
        colormap('jet'); colorbar();
        title(mapNames{i}, 'Interpreter','none','FontSize',10);
        axis xy;

        % Overlay centers on SimulateMap
        if strcmp(mapNames{i}, 'SimulateMap')
            hold on;
            scatter(maps.Centers(:,1), maps.Centers(:,2), 50, 'w', 'filled','MarkerEdgeColor','k');
            hold off;
        end
    end

    linkaxes(ax,'xy');
    sgtitle(sprintf('File: %s', fileName), 'Interpreter','none','FontSize',12);

    savePath = fullfile(CONFIG.SavePlotFolderPath, [timestamp '_' fileName '_plot.png']);
    saveas(gcf, savePath);
    fprintf("Saved plot for %s\n", fileName);
end


%% Function: Save Mask & PL Star Data
function saveMaskAndPLStar(maps, OrigFileName, CONFIG)
    [~, baseName, ~] = fileparts(OrigFileName);
    timestamp = char(CONFIG.RunTime);
    dirs = {CONFIG.SaveResultFolderPath, CONFIG.MaskOutputFolderPath, CONFIG.PLstarOutputFolderPath};
    for d = dirs, if ~exist(d{1}, 'dir'), mkdir(d{1}); end; end

    maskFile   = fullfile(CONFIG.MaskOutputFolderPath,   [timestamp '_' baseName '_Mask.mat']);
    plStarFile = fullfile(CONFIG.PLstarOutputFolderPath, [timestamp '_' baseName '_PLStar.mat']);

    maskMap    = maps.MaskMap;
    finalMap   = maps.SimulateMap;
    save(maskFile,   'maskMap');
    save(plStarFile, 'finalMap');
    fprintf("Saved mask and PL Star data for %s\n", baseName);
end
