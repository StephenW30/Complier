%% 批量处理PL Star分析脚本
% 清空工作区并关闭所有图形
clear all; close all; clc;
addpath('D:\stephen\git_Toolbox');  % 添加工具箱路径到MATLAB搜索路径

%% 主脚本 - 批量处理
% 设置全局常量和配置参数
CONFIG = struct(...
    'FigureNumber', 100, ...                     % 用于绘图的图形编号
    'FolderPath', 'D:\Stephen\PL star\data', ... % 指定包含.mat文件的文件夹
    'OutputFolder', 'D:\Stephen\PL star\output', ... % 输出文件夹
    'PixelSizeMm', 0.1, ...                      % 像素大小（毫米）
    'PlotInMm', false, ...                       % 是否以毫米为单位绘图
    'IsAPS1', false, ...                         % APS1标志
    'PLstarEllipseRatio', struct('MajorAxis', 0.3, 'MinorAxis', 0.2), ... % 椭圆形状参数（相对于晶圆尺寸的比例）
    'PLstarWidth', 3 ...                         % PL star线宽（1-4之间）
);

% 确保输出文件夹存在
if ~exist(CONFIG.OutputFolder, 'dir')
    mkdir(CONFIG.OutputFolder);
end

% 获取所有.mat文件
matFiles = dir(fullfile(CONFIG.FolderPath, '*.mat'));

% 检查是否找到文件
if isempty(matFiles)
    error('在指定文件夹中找不到.mat文件');
end

% 批量处理每个文件
for fileIdx = 1:length(matFiles)
    % 获取当前文件名
    currentFile = matFiles(fileIdx).name;
    fprintf('处理文件 %d/%d: %s\n', fileIdx, length(matFiles), currentFile);
    
    % 加载wafer数据
    [waferData, waferInfo] = loadWaferData(fullfile(CONFIG.FolderPath, currentFile));
    
    % 更新配置参数
    currentConfig = CONFIG;
    currentConfig.WaferName = waferInfo.WaferName;
    currentConfig.WaferSizeMm = waferInfo.WaferSizeMm;
    
    % 计算PL star中心点（在wafer右侧中部）
    currentConfig.PLstarCenter = calculatePLStarCenter(waferData, currentConfig);
    
    % 计算椭圆尺寸参数（基于晶圆大小）
    currentConfig.PLstarEllipse = calculatePLStarEllipse(currentConfig);
    
    % 生成PL star图
    maps = generatePLStarMaps(waferData, currentConfig);
    
    % 计算坐标
    coords = calculateCoordinates(currentConfig);
    
    % 绘制图形
    plotMaps(maps, coords, currentConfig, currentFile);
    
    % 保存生成的Mask和修改后的PL star数据
    saveOutputMaps(maps, waferInfo, currentFile, currentConfig);
end

%% 加载Wafer数据的函数
function [waferData, waferInfo] = loadWaferData(filePath)
    % 从.mat文件加载数据
    data = load(filePath);
    
    % 提取结构体中的字段
    fieldNames = fieldnames(data);
    if length(fieldNames) == 1
        % 如果只有一个字段，直接使用它
        mainField = fieldNames{1};
        mainData = data.(mainField);
    else
        % 尝试找到包含数据的主要字段
        mainData = data;
    end
    
    % 提取wafer数据和相关信息
    if isstruct(mainData) && isfield(mainData, 'data')
        % 数据存储在data字段中
        waferData = mainData.data;
        
        % 提取wafer信息
        waferInfo = struct();
        if isfield(mainData, 'waferName')
            waferInfo.WaferName = mainData.waferName;
        else
            % 使用文件名作为默认wafer名称
            [~, waferInfo.WaferName, ~] = fileparts(filePath);
        end
        
        if isfield(mainData, 'waferSize')
            waferInfo.WaferSizeMm = mainData.waferSize;
        else
            % 假设方形wafer，尺寸是矩阵的大小乘以像素大小
            waferInfo.WaferSizeMm = 150; % 默认150mm
        end
    elseif isnumeric(mainData)
        % 数据直接是一个数值矩阵
        waferData = mainData;
        
        % 创建默认wafer信息
        waferInfo = struct();
        [~, waferInfo.WaferName, ~] = fileparts(filePath);
        waferInfo.WaferSizeMm = 150; % 默认150mm
    else
        error('无法从.mat文件中提取wafer数据');
    end
    
    % 替换0值为NaN
    waferData(waferData == 0) = nan;
    
    % 如果不是APS1，则垂直翻转数据
    if ~isequal(waferData, flipud(waferData))
        waferData = flipud(waferData);
    end
end

%% 计算PL Star中心点
function center = calculatePLStarCenter(waferData, config)
    % 获取数据尺寸
    [height, width] = size(waferData);
    
    % 计算wafer中心
    centerX = width / 2;
    centerY = height / 2;
    
    % 计算PL star中心位置（在右侧中部）
    % 将中心向右移动到约3/4处
    offsetX = width * 0.25; % 向右偏移，使得中心点在右侧
    
    center = struct(...
        'X', centerX + offsetX, ...
        'Y', centerY ... % 保持Y轴不变，位于中部
    );
end

%% 计算PL Star椭圆参数
function ellipse = calculatePLStarEllipse(config)
    % 获取wafer尺寸（像素）
    waferSizePixels = config.WaferSizeMm / config.PixelSizeMm;
    
    % 计算椭圆的主轴和次轴（确保Y轴长度大于X轴长度）
    majorAxisLength = waferSizePixels * config.PLstarEllipseRatio.MajorAxis;
    minorAxisLength = waferSizePixels * config.PLstarEllipseRatio.MinorAxis;
    
    % 如果不满足Y轴大于X轴的条件，则交换它们
    if majorAxisLength <= minorAxisLength
        temp = majorAxisLength;
        majorAxisLength = minorAxisLength * 1.2; % 确保Y轴明显大于X轴
        minorAxisLength = temp;
    end
    
    % 构建椭圆参数
    ellipse = struct(...
        'MajorAxis', majorAxisLength, ... % Y轴方向（长轴）
        'MinorAxis', minorAxisLength ...  % X轴方向（短轴）
    );
end

%% 生成和处理PL Star图像
function maps = generatePLStarMaps(waferMap, config)
    maps = struct();
    
    % 设置图像大小
    [height, width] = size(waferMap);
    
    % 生成PL star掩码（使用椭圆边界）
    maskMap = generatePLStar(height, width, config.PLstarCenter.X, config.PLstarCenter.Y, ...
                          config.PLstarEllipse.MinorAxis, config.PLstarEllipse.MajorAxis, ...
                          config.PLstarWidth, waferMap);
    
    % 模拟填充PL star结构
    simulateMap = fillPLStarStructure(maskMap, waferMap);
    
    % 保存所有图
    maps.RawMap = waferMap;
    maps.MaskMap = maskMap;
    maps.SimulateMap = simulateMap;
end

%% 计算绘图坐标
function coords = calculateCoordinates(config)
    % 计算尺寸和中心
    dimX = size(config.PLstarCenter.X * 2, 1);
    dimY = size(config.PLstarCenter.Y * 2, 1);
    dim = max(dimX, dimY);
    
    waferCenter = struct('X', dim/2, 'Y', dim/2);
    
    % 计算毫米坐标
    xMm = ((1:dim) - waferCenter.X - 0.5) * config.PixelSizeMm;
    yMm = ((1:dim) - waferCenter.Y - 0.5) * config.PixelSizeMm;
    
    coords = struct('Dimension', dim, 'XMm', xMm, 'YMm', yMm);
end

%% 绘图函数
function plotMaps(maps, coords, config, fileName)
    % 创建新图形
    figure(config.FigureNumber); clf;
    set(gcf, 'Position', [100, 100, 1800, 400]);
    
    % 获取图名
    mapNames = fieldnames(maps);
    
    % 初始化坐标轴数组
    ax = zeros(1, length(mapNames));
    
    % 循环每个图进行绘制
    for i = 1:length(mapNames)
        % 获取当前图
        mapName = mapNames{i};
        currentMap = maps.(mapName);
        
        % 创建子图
        if length(mapNames) > 3
            ax(i) = subplot(2, 3, i);
        else
            ax(i) = subplot(1, length(mapNames), i);
        end
        
        % 绘制图
        if config.PlotInMm
            imagesc(coords.XMm, coords.YMm, currentMap);
        else
            imagesc(currentMap);
        end
        
        % 应用自定义函数（如果存在）
        if exist('func_ChangeColorForNaN', 'file') == 2
            func_ChangeColorForNaN(gca);
        end
        
        if exist('func_GetDataStatCurrROI', 'file') == 2
            func_GetDataStatCurrROI(gca, true, [5 95]);
        end
        
        % 设置标签
        if config.PlotInMm
            xlabel('x(mm)');
            ylabel('y(mm)');
        else
            xlabel('x(pixels)');
            ylabel('y(pixels)');
        end
        
        % 调整坐标轴并设置颜色图
        axis tight; axis equal;
        colormap('jet'); colorbar();
        
        % 设置坐标轴范围
        if config.PlotInMm
            axis([-config.WaferSizeMm/2 config.WaferSizeMm/2 -config.WaferSizeMm/2 config.WaferSizeMm/2]);
        else
            [height, width] = size(currentMap);
            axis([0 width 0 height]);
        end
        
        % 添加标题
        title(sprintf('%s', mapName), 'fontsize', 7);
        
        % 确保正常的XY轴方向
        axis xy;
    end
    
    % 链接所有坐标轴
    linkaxes(ax, 'xy');
    
    % 添加超级标题
    if exist('suptitle', 'file') == 2
        tt = {sprintf('Wafer: %s', config.WaferName), sprintf('File: %s', fileName)};
        suptitle(tt, 10);
    else
        % MATLAB R2018b及以上版本使用sgtitle
        sgtitle({sprintf('Wafer: %s', config.WaferName), sprintf('File: %s', fileName)}, 'FontSize', 10);
    end
    
    % 保存图形
    [~, nameOnly, ~] = fileparts(fileName);
    saveas(gcf, fullfile(config.OutputFolder, [nameOnly, '_plot.png']));
end

%% 手动生成带椭圆边界的PL Star
function img = generatePLStar(imageHeight, imageWidth, centerX, centerY, ellipseMinor, ellipseMajor, width, waferImg)
    % 初始化空二进制图像
    img = zeros(imageHeight, imageWidth, 'uint8');
    
    % 如果未提供wafer图像，则创建全黑图像
    if nargin < 8 || isempty(waferImg)
        waferImg = zeros(imageHeight, imageWidth, 'double');
    else
        waferImg = double(waferImg);
    end
    
    % 定义PL star的6个点的角度（度）
    angles = [0, 60, 120, 180, 240, 300];
    
    % 转换为弧度
    anglesRad = deg2rad(angles);
    
    % 根据非常长的线计算端点（比椭圆长得多）
    % 这确保我们可以找到与椭圆的交点
    maxLength = max(max(imageHeight, imageWidth), max(ellipseMajor, ellipseMinor) * 2);
    
    % 首先在所有6个方向上创建长线
    xTemp = zeros(1, length(angles));
    yTemp = zeros(1, length(angles));
    
    for i = 1:length(angles)
        xTemp(i) = round(centerX + maxLength * cos(anglesRad(i)));
        yTemp(i) = round(centerY + maxLength * sin(anglesRad(i)));
    end
    
    % 现在对每条线找到与椭圆的交点
    xEnd = zeros(1, length(angles));
    yEnd = zeros(1, length(angles));
    
    for i = 1:length(angles)
        % 找到从中心到(xTemp,yTemp)的线与椭圆的交点
        [xIntersect, yIntersect] = lineEllipseIntersection(centerX, centerY, xTemp(i), yTemp(i), ...
                                                          centerX, centerY, ellipseMinor, ellipseMajor);
        
        % 使用第一个交点（最接近中心）
        if ~isempty(xIntersect)
            xEnd(i) = round(xIntersect(1));
            yEnd(i) = round(yIntersect(1));
        else
            % 如果未找到交点的备用（使用足够大的maxLength应该不会发生）
            xEnd(i) = xTemp(i);
            yEnd(i) = yTemp(i);
        end
    end
    
    % 绘制每条线
    width = max(1, min(4, width)); % 确保宽度在1-4之间
    for i = 1:length(angles)
        img = drawLine(img, waferImg, centerX, centerY, xEnd(i), yEnd(i), width);
    end
end

%% 查找线和椭圆之间的交点
function [xIntersect, yIntersect] = lineEllipseIntersection(x1, y1, x2, y2, cx, cy, a, b)
    % 输入:
    %   (x1,y1)和(x2,y2)是线的端点
    %   (cx,cy)是椭圆的中心
    %   a是半短轴（X方向）
    %   b是半长轴（Y方向）
    
    % 平移以使椭圆以原点为中心
    x1 = x1 - cx;
    y1 = y1 - cy;
    x2 = x2 - cx;
    y2 = y2 - cy;
    
    % 线的参数方程：(x,y) = (x1,y1) + t*((x2-x1),(y2-y1))
    dx = x2 - x1;
    dy = y2 - y1;
    
    % 二次公式系数
    A = (dx*dx)/(a*a) + (dy*dy)/(b*b);
    B = 2*((x1*dx)/(a*a) + (y1*dy)/(b*b));
    C = (x1*x1)/(a*a) + (y1*y1)/(b*b) - 1;
    
    % 计算判别式
    discriminant = B*B - 4*A*C;
    
    % 如果判别式为负，则无交点
    if discriminant < 0
        xIntersect = [];
        yIntersect = [];
        return;
    end
    
    % 计算交点参数
    t1 = (-B + sqrt(discriminant)) / (2*A);
    t2 = (-B - sqrt(discriminant)) / (2*A);
    
    % 计算交点
    xIntersect = [x1 + t1*dx, x1 + t2*dx] + cx;
    yIntersect = [y1 + t1*dy, y1 + t2*dy] + cy;
    
    % 根据与原始点(x1,y1)的距离排序
    dist1 = (xIntersect(1) - (x1+cx))^2 + (yIntersect(1) - (y1+cy))^2;
    dist2 = (xIntersect(2) - (x1+cx))^2 + (yIntersect(2) - (y1+cy))^2;
    
    if dist2 < dist1
        xIntersect = [xIntersect(2), xIntersect(1)];
        yIntersect = [yIntersect(2), yIntersect(1)];
    end
end

%% 绘制线
function img = drawLine(img, waferImg, x1, y1, x2, y2, width)
    % 使用Bresenham算法获取线上的点
    [x, y] = bresenham(x1, y1, x2, y2);
    
    % 绘制每个点
    for i = 1:length(x)
        % 检查点是否在图像边界内
        if x(i) < 1 || x(i) > size(img, 2) || y(i) < 1 || y(i) > size(img, 1)
            continue;
        end
        
        % 如果遇到NaN则停止绘制
        if isnan(waferImg(y(i), x(i)))
            break;
        end
        
        % 用指定宽度绘制线
        for dx = -floor(width/2):floor(width/2)
            for dy = -floor(width/2):floor(width/2)
                % 计算新位置
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

%% Bresenham算法实现
function [x, y] = bresenham(x1, y1, x2, y2)
    % 舍入输入坐标以保持一致性
    x1 = round(x1); 
    x2 = round(x2); 
    y1 = round(y1); 
    y2 = round(y2);
    
    % 计算x和y方向的差异
    dx = abs(x2 - x1);
    dy = abs(y2 - y1);
    
    % 确定x和y的增量方向
    sx = sign(x2 - x1);
    sy = sign(y2 - y1);
    
    % 初始化误差项
    err = dx - dy;
    
    % 初始化空数组以存储线点
    x = [];
    y = [];
    
    % Bresenham算法的主循环
    while true
        % 存储当前点
        x = [x; x1];
        y = [y; y1];
        
        % 检查是否到达终点
        if (x1 == x2 && y1 == y2) || ...
           ((sx > 0 && x1 >= x2) && (sy > 0 && y1 >= y2)) || ...
           ((sx < 0 && x1 <= x2) && (sy < 0 && y1 <= y2))
            break;
        end
        
        % 计算决策参数
        e2 = 2 * err;
        
        % 如有必要，更新误差项和x坐标
        if e2 > -dy
            err = err - dy;
            x1 = x1 + sx;
        end
        
        % 如有必要，更新误差项和y坐标
        if e2 < dx
            err = err + dx;
            y1 = y1 + sy;
        end
    end
end

%% 填充PL Star结构
function finalImg = fillPLStarStructure(masking, waferImg)
    % 参数设置
    filterSize = 5;
    sigma = 1;
    thresholdLow = 0.0005 * 2;
    thresholdMed = 0.001 * 2;
    thresholdHigh = 0.003 * 2;
    
    % 创建高斯滤波器
    h = fspecial('gaussian', filterSize, sigma);
    backgroundSmoothed = imfilter(waferImg, h);
    nanMask = isnan(backgroundSmoothed);
    backgroundSmoothed(nanMask & ~isnan(waferImg)) = waferImg(nanMask & ~isnan(waferImg));

    diffImg = waferImg - backgroundSmoothed;
    noiseMean = nanmean(diffImg(masking==1));
    noiseStd = nanstd(diffImg(masking==1));

    % 打印噪声统计数据
    fprintf('噪声均值: %f\n', noiseMean);
    fprintf('噪声标准差: %f\n', noiseStd);
    
    % 复制原始图像
    finalImg = waferImg;
    
    % 查找mask等于1的点
    [rows, cols] = find(masking == 1);
    
    % 处理每个点
    for i = 1:length(rows)
        r = rows(i);
        c = cols(i);
        backgroundValue = backgroundSmoothed(r, c);
        randProb = rand();
        
        % 根据随机概率选择缩放因子
        if randProb < 0.3
            scalingFactor = (1 - thresholdMed + (thresholdMed - thresholdLow) * rand());
        else
            scalingFactor = (1 - thresholdHigh + (thresholdHigh - thresholdMed) * rand());
        end
        
        % 计算新值并添加噪声
        newValue = backgroundValue * scalingFactor;
        newValue = newValue + min(noiseStd, thresholdLow) * randn() * 0.1;
        finalImg(r, c) = newValue;
    end
end

%% 保存输出图
function saveOutputMaps(maps, waferInfo, fileName, config)
    % 创建输出文件名（保持与原始文件名的关联）
    [~, nameOnly, ~] = fileparts(fileName);
    outputFile = fullfile(config.OutputFolder, [nameOnly, '_PLStar.mat']);
    
    % 准备要保存的数据
    outputData = struct(...
        'MaskMap', maps.MaskMap, ...
        'SimulateMap', maps.SimulateMap, ...
        'WaferName', waferInfo.WaferName, ...
        'WaferSizeMm', waferInfo.WaferSizeMm, ...
        'PLStarCenter', config.PLstarCenter, ...
        'PLStarEllipse', config.PLstarEllipse, ...
        'PLStarWidth', config.PLstarWidth, ...
        'ProcessDate', datestr(now) ...
    );
    
    % 保存到.mat文件
    save(outputFile, 'outputData');
    fprintf('已保存PL Star数据到: %s\n', outputFile);
end
