%% PL Star Analysis System with Enhanced Robustness
% Clean workspace and close all figures
clear all; close all; clc;
addpath('D:\stephen\git_Toolbox');  % Add toolbox path to MATLAB search path

%% Main Processing Pipeline
function main()
    % 初始化配置参数
    CONFIG = initConfig();
    
    try
        % 数据加载与预处理
        [rawMap, normalizedMap] = loadAndPreprocessData(CONFIG);
        
        % 特征增强处理
        enhancedMap = featureEnhancementPipeline(normalizedMap, CONFIG);
        
        % PL星模拟生成
        maps = generatePLStarMaps_enhanced(rawMap, enhancedMap, CONFIG);
        
        % 坐标计算与可视化
        coords = calculateCoordinates(CONFIG);
        plotEnhancedResults(maps, coords, CONFIG);
        
    catch ME
        errorHandler(ME);
    end
end

%% 初始化配置参数
function CONFIG = initConfig()
    CONFIG = struct(...
        'FigureNumber', 100, ...
        'FolderPath', 'D:\Stephen\PL star\data\Surface_Inspection(0)_2025-02-01-19-10-39_SuperFine1Res', ...
        'HazeMapFile', 'P2cHaze_Grp[1]FT[MED]Res[100]ch[2]_03_Nppm', ...
        'PixelSizeMm', 0.1, ...          % 单位换算系数
        'WaferSizeMm', 150, ...          % 晶圆物理尺寸
        'DynamicNormWindow', 10, ...     % 动态归一化窗口(mm)
        'GaborWavelength', [5 10 20], ...% Gabor滤波器波长
        'AnisoDiffIter', 20, ...         % 各向异性扩散迭代次数
        'MorphoDiskSize', 3, ...         % 形态学操作尺寸(mm)
        'PLstarParams', struct(...
            'Center', struct('X', 764, 'Y', 1412), ...
            'LengthRange', [80 120], ...    % PL星臂长范围
            'WidthRange', [3 7], ...        % 线宽范围
            'IntensityRange', [0.5 1.0], ...% 强度范围
            'MissingArmProb', 0.3) ...      % 臂缺失概率
    );
end

%% 数据加载与预处理
function [rawMap, normalizedMap] = loadAndPreprocessData(CONFIG)
    % 原始数据加载
    rawMap = loadRawData(CONFIG);
    
    % 动态背景归一化
    normalizedMap = dynamicBackgroundNorm(rawMap, CONFIG);
    
    % 异常值处理
    normalizedMap = clipOutliers(normalizedMap, 0.01, 99.99);
end

%% 特征增强处理流水线
function enhancedMap = featureEnhancementPipeline(normalizedMap, CONFIG)
    % 各向异性扩散滤波
    diffusedMap = anisoDiffusion(normalizedMap, CONFIG.AnisoDiffIter);
    
    % 多尺度Gabor滤波
    gaborResponse = applyGaborBank(diffusedMap, CONFIG);
    
    % 形态学骨架提取
    enhancedMap = morphologicalRefinement(gaborResponse, CONFIG);
end

%% 动态背景归一化
function normalized = dynamicBackgroundNorm(rawData, CONFIG)
    % 滑动窗口统计
    winSize = round(CONFIG.DynamicNormWindow / CONFIG.PixelSizeMm);
    localMean = movmean(rawData, winSize, [1 2], 'omitnan');
    localStd = movstd(rawData, winSize, 0, [1 2], 'omitnan');
    
    % 全局直方图标准化
    refPoints = quantile(rawData(:), [0.01 0.5 0.99]);
    targetPoints = linspace(0.001, 0.01, 3);
    matchedData = histShape(rawData, refPoints, targetPoints);
    
    % 标准化处理
    normalized = (matchedData - localMean) ./ (localStd + eps);
    normalized = rescale(normalized, -1, 1);
end

%% 多尺度Gabor滤波器组
function response = applyGaborBank(img, CONFIG)
    % 初始化参数
    wavelengths = CONFIG.GaborWavelength;
    angles = 0:60:300;
    response = zeros(size(img));
    
    % 构建滤波器组
    for lambda = wavelengths
        for theta = deg2rad(angles)
            % 生成Gabor核
            gb = gaborKernel(lambda, theta, CONFIG.PixelSizeMm);
            
            % 卷积计算
            filtered = imfilter(img, gb, 'symmetric');
            response = response + abs(filtered);
        end
    end
end

%% 形态学精炼处理
function enhanced = morphologicalRefinement(img, CONFIG)
    % 自适应阈值处理
    th = adaptthresh(img, 0.5, 'NeighborhoodSize', 31);
    binaryMap = imbinarize(img, th);
    
    % 形态学骨架提取
    diskSize = round(CONFIG.MorphoDiskSize / CONFIG.PixelSizeMm);
    se = strel('disk', max(diskSize, 1));
    cleaned = imopen(binaryMap, se);
    skeleton = bwmorph(cleaned, 'skel', Inf);
    
    % 结果增强
    enhanced = img .* double(skeleton);
end

%% 增强型PL星生成
function maps = generatePLStarMaps_enhanced(rawMap, enhancedMap, CONFIG)
    params = CONFIG.PLstarParams;
    
    % 随机生成PL星参数
    armLength = randi(params.LengthRange);
    lineWidth = randi(params.WidthRange);
    intensity = params.IntensityRange(1) + ...
               diff(params.IntensityRange)*rand();
    
    % 生成基础PL星
    baseStar = generatePLStar_enhanced(size(rawMap), params.Center, ...
        armLength, lineWidth, intensity, params.MissingArmProb);
    
    % 与增强特征图融合
    simulatedMap = enhancedMap .* baseStar;
    
    % 存储结果
    maps = struct(...
        'RawMap', rawMap, ...
        'EnhancedMap', enhancedMap, ...
        'PLStarMask', baseStar, ...
        'SimulatedMap', simulatedMap);
end

%% 改进的PL星生成核心函数
function img = generatePLStar_enhanced(imgSize, center, length, width, intensity, missingProb)
    % 初始化图像
    img = zeros(imgSize);
    
    % 生成6个方向的臂
    angles = 0:60:300;
    armStatus = rand(1,6) > missingProb; % 随机缺失臂
    
    % 绘制每条臂
    for i = 1:6
        if armStatus(i)
            theta = deg2rad(angles(i));
            endX = round(center.X + length*cos(theta));
            endY = round(center.Y + length*sin(theta));
            img = drawEnhancedArm(img, center, endX, endY, width);
        end
    end
    
    % 添加强度渐变和噪声
    [X,Y] = meshgrid(1:imgSize);
    distMap = sqrt((X-center.X).^2 + (Y-center.Y).^2);
    decay = exp(-distMap/(length*1.5));
    img = img .* decay * intensity;
    img = imnoise(img, 'gaussian', 0, 0.01);
end

%% 改进的臂绘制函数
function img = drawEnhancedArm(img, center, endX, endY, width)
    % Bresenham算法生成中心线
    [xPoints, yPoints] = bresenham(center.X, center.Y, endX, endY);
    
    % 带宽度扩展的绘制
    for k = 1:length(xPoints)
        x = xPoints(k);
        y = yPoints(k);
        
        % 高斯剖面强度分布
        for dx = -width:width
            for dy = -width:width
                dist = sqrt(dx^2 + dy^2);
                if dist <= width
                    weight = exp(-(dist^2)/(2*(width/2)^2));
                    xi = min(max(x + dx, 1), size(img,2));
                    yi = min(max(y + dy, 1), size(img,1));
                    img(yi,xi) = max(img(yi,xi), weight);
                end
            end
        end
    end
end

%% 辅助函数 --------------------------------------------------
function gb = gaborKernel(lambda, theta, pxSize)
    sigma = lambda/(2*pi)/pxSize;
    halfSize = ceil(3*sigma);
    [x,y] = meshgrid(-halfSize:halfSize);
    
    xRot = x*cos(theta) + y*sin(theta);
    yRot = -x*sin(theta) + y*cos(theta);
    
    gb = exp(-(xRot.^2 + yRot.^2)/(2*sigma^2)) ...
        .* cos(2*pi*xRot/(lambda/pxSize));
    gb = gb - mean(gb(:));
    gb = gb / sum(abs(gb(:)));
end

function img = histShape(img, srcLevels, tgtLevels)
    % 直方图形状匹配
    srcEdges = linspace(min(srcLevels), max(srcLevels), 256);
    tgtEdges = linspace(min(tgtLevels), max(tgtLevels), 256);
    
    srcHist = histcounts(img, srcEdges, 'Normalization','cdf');
    tgtHist = histcounts(linspace(tgtLevels(1),tgtLevels(end),numel(img)),...
                        tgtEdges, 'Normalization','cdf');
    
    [~, bin] = histc(img(:), srcEdges);
    mappedValues = interp1(tgtHist, tgtEdges, srcHist(bin), 'linear');
    img = reshape(mappedValues, size(img));
end

function filtered = anisoDiffusion(img, iterations, dt, kappa)
    % 各向异性扩散滤波
    filtered = img;
    for i = 1:iterations
        [gradN, gradS, gradE, gradW] = gradient4(filtered);
        cN = exp(-(gradN/kappa).^2);
        cS = exp(-(gradS/kappa).^2);
        cE = exp(-(gradE/kappa).^2);
        cW = exp(-(gradW/kappa).^2);
        
        filtered = filtered + dt*(...
            cN.*gradN + cS.*gradS + ...
            cE.*gradE + cW.*gradW);
    end
end

function [n,s,e,w] = gradient4(img)
    % 四方向梯度计算
    n = img - circshift(img, [1 0]);
    s = img - circshift(img, [-1 0]);
    e = img - circshift(img, [0 1]);
    w = img - circshift(img, [0 -1]);
end

%% 可视化模块
function plotEnhancedResults(maps, coords, CONFIG)
    figure(CONFIG.FigureNumber); clf;
    subplot(221); showImage(maps.RawMap, coords, 'Raw Data', CONFIG);
    subplot(222); showImage(maps.EnhancedMap, coords, 'Enhanced Features', CONFIG);
    subplot(223); showImage(maps.PLStarMask, coords, 'PL Star Mask', CONFIG);
    subplot(224); showImage(maps.SimulatedMap, coords, 'Final Simulation', CONFIG);
end

function showImage(img, coords, titleStr, CONFIG)
    if CONFIG.PlotInMm
        imagesc(coords.XMm, coords.YMm, img);
        axis([-CONFIG.WaferSizeMm/2 CONFIG.WaferSizeMm/2 ...
             -CONFIG.WaferSizeMm/2 CONFIG.WaferSizeMm/2]);
    else
        imagesc(img);
        axis([0 coords.Dimension 0 coords.Dimension]);
    end
    func_ChangeColorForNaN(gca);
    colormap(jet); colorbar;
    title(titleStr, 'FontSize', 8);
end

%% 错误处理
function errorHandler(ME)
    fprintf('[ERROR] %s\n', ME.message);
    for k = 1:length(ME.stack)
        fprintf('File: %s\nName: %s\nLine: %d\n',...
            ME.stack(k).file,...
            ME.stack(k).name,...
            ME.stack(k).line);
    end
end

% 调用主程序
main();






%% Fill PL Star Structure with Radial Intensity Variation
function finalImg = fillPLStarStructure(masking, waferImg, config)
    % Parameter settings
    filterSize = 5;
    sigma = 1;
    noiseLevel = 0.0002;
    thresholdLow = 0.995;
    thresholdMed = 0.99;
    thresholdHigh = 0.97;
    
    % Create Gaussian filter
    h = fspecial('gaussian', filterSize, sigma);
    backgroundSmoothed = imfilter(waferImg, h);
    
    % Copy original image
    finalImg = waferImg;
    
    % Find points where mask equals 1
    [rows, cols] = find(masking == 1);
    centerX = config.PLstarCenter.X;
    centerY = config.PLstarCenter.Y;
    maxDist = config.PLstarLength;
    
    % Process each point
    for i = 1:length(rows)
        r = rows(i);
        c = cols(i);
        backgroundValue = backgroundSmoothed(r, c);
        randProb = rand();
        
        % Compute radial distance from center
        distance = sqrt((c - centerX)^2 + (r - centerY)^2);
        attenuationFactor = 1 - (distance / maxDist) * 0.3; % Linearly decrease intensity
        attenuationFactor = max(attenuationFactor, 0.7); % Ensure minimum attenuation
        
        % Choose scaling factor based on random probability
        if randProb < 0.3
            scalingFactor = (thresholdMed + (thresholdLow - thresholdMed) * rand()) * attenuationFactor;
        else
            scalingFactor = (thresholdHigh + (thresholdMed - thresholdHigh) * rand()) * attenuationFactor;
        end
        
        % Calculate new value and add noise
        newValue = backgroundValue * scalingFactor;
        newValue = newValue + noiseLevel * rand();
        finalImg(r, c) = newValue;
    end
end
