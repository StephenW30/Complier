%% PL Star Analysis Script
% 清理工作区并关闭所有图形
clear all; close all; clc;
addpath('D:\stephen\git_Toolbox');  % 添加工具箱路径

%% 主脚本
% 设置全局常量和配置参数
CONFIG = struct(...
    'FigureNumber', 100, ...                       % 图形编号
    'FolderPath', 'D:\StephenPL starldatalsurface Inspection(0)_2025-02-01-19-10-39 SuperFine1Res', ...
    'HazeMapFile', 'P2cHaze_Grp[1]FT[MED]Res[100]ch[2]_03_Nppm', ...
    'PixelSizeMm', 0.1, ...                        % 像素尺寸(mm)
    'WaferName', 'sc1 Wolfspeed', ...              % 晶圆名称
    'WaferSizeMm', 150, ...                        % 晶圆尺寸(mm)
    'PlotInMm', false, ...                         % 是否以mm为单位绘图
    'Resolution', 'SuperFine1', ...                % 分辨率设置
    'IsAPS1', false, ...                           % APS1标志
    'PLstarCenter', struct('X', 764, 'Y', 1412), ... % PL星中心坐标
    'PLstarLength', 100, ...                       % PL星中心到外顶点的长度
    'PLstarWidth', 5 ...                           % PL星线条宽度
);

% 加载原始数据
rawMap = loadRawData(CONFIG);

% 生成PL星图
maps = generatePLStarMaps(rawMap, CONFIG);

% 计算坐标
coords = calculateCoordinates(CONFIG);

% 绘制地图
plotMaps(maps, coords, CONFIG);

%% 加载数据函数
function rawData = loadRawData(config)
    % 构建完整文件路径
    filePath = fullfile(config.FolderPath, [config.HazeMapFile, '.raw']);
    
    % 加载原始数据
    rawData = openraw(filePath);
    
    % 将0值替换为NaN
    rawData(rawData == 0) = nan;
    
    % 如果不是APS1，则上下翻转数据
    if ~config.IsAPS1
        rawData = flipud(rawData);
    end
end

%% 生成和处理PL星图像
function maps = generatePLStarMaps(rawMap, config)
    maps = struct();
    
    % 设置图像尺寸
    imageSize = 1500;
    
    % 生成PL星掩码
    maskMap = generatePLStar(imageSize, config.PLstarCenter.X, config.PLstarCenter.Y, ...
                            config.PLstarLength, config.PLstarWidth, rawMap);
    
    % 模拟填充PL星结构
    simulateMap = fillPLStarStructure(maskMap, rawMap);
    
    % 保存所有地图
    maps.RawMap = rawMap;
    maps.MaskMap = maskMap;
    maps.SimulateMap = simulateMap;
end

%% 计算绘图坐标
function coords = calculateCoordinates(config)
    % 计算尺寸和中心
    dim = config.WaferSizeMm / config.PixelSizeMm;
    waferCenter = struct('X', dim/2, 'Y', dim/2);
    
    % 计算mm坐标
    xMm = ((1:dim) - waferCenter.X - 0.5) * config.PixelSizeMm;
    yMm = ((1:dim) - waferCenter.Y - 0.5) * config.PixelSizeMm;
    
    coords = struct('Dimension', dim, 'XMm', xMm, 'YMm', yMm);
end

%% 绘图函数
function plotMaps(maps, coords, config)
    % 创建新图形
    figure(config.FigureNumber); clf;
    
    % 获取地图名称
    mapNames = fieldnames(maps);
    
    % 初始化轴数组
    ax = zeros(1, length(mapNames));
    
    % 遍历每个地图进行绘图
    for i = 1:length(mapNames)
        % 获取当前地图
        mapName = mapNames{i};
        currentMap = maps.(mapName);
        
        % 创建子图
        if length(mapNames) > 3
            ax(i) = subplot(2, 3, i);
        else
            ax(i) = subplot(1, length(mapNames), i);
        end
        
        % 绘制地图
        if config.PlotInMm
            imagesc(coords.XMm, coords.YMm, currentMap);
        else
            imagesc(currentMap);
        end
        
        % 应用自定义函数
        func_ChangeColorForNaN(gca);
        func_GetDataStatCurrROI(gca, true, [5 95]);
        
        % 设置标签
        if config.PlotInMm
            xlabel('x(mm)');
            ylabel('y(mm)');
        else
            xlabel('x(pixels)');
            ylabel('y(pixels)');
        end
        
        % 调整轴并设置颜色映射
        axis tight; axis equal;
        colormap('jet'); colorbar();
        
        % 设置轴范围
        if config.PlotInMm
            axis([-config.WaferSizeMm/2 config.WaferSizeMm/2 -config.WaferSizeMm/2 config.WaferSizeMm/2]);
        else
            axis([0 coords.Dimension 0 coords.Dimension]);
        end
        
        % 添加标题
        title(sprintf('%s', mapName), 'fontsize', 7);
        
        % 确保正常XY轴方向
        axis xy;
    end
    
    % 链接所有轴
    linkaxes(ax, 'xy');
    
    % 添加超标题
    tt = {sprintf('%s', config.FolderPath), sprintf('%s', config.HazeMapFile)};
    suptitle(tt, 10);
end

%% 辅助函数

% 填充PL星结构
function finalImg = fillPLStarStructure(masking, waferImg)
    % 参数设置
    filterSize = 5;
    sigma = 1;
    noiseLevel = 0.0002;
    thresholdLow = 0.0005;
    thresholdMed = 0.001;
    thresholdHigh = 0.003;
    
    % 创建高斯滤波器
    h = fspecial('gaussian', filterSize, sigma);
    backgroundSmoothed = imfilter(waferImg, h);
    
    % 复制原始图像
    finalImg = waferImg;
    
    % 找出掩码中值为1的点
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
        newValue = newValue + noiseLevel * rand();
        finalImg(r, c) = newValue;
    end
end

% 手动生成PL星
function img = generatePLStar(imageSize, centerX, centerY, length, width, waferImg)
    % 初始化空白二值图像
    img = zeros(imageSize, imageSize, 'uint8');
    
    % 如果未提供晶圆图像，则创建全黑图像
    if nargin < 6 || isempty(waferImg)
        waferImg = zeros(imageSize, imageSize, 'double');
    else
        waferImg = double(waferImg);
    end
    
    % 定义PL星6个点的角度（度）
    angles = [0, 60, 120, 180, 240, 300];
    
    % 转换为弧度
    anglesRad = deg2rad(angles);
    
    % 计算每条线的终点坐标
    xEnd = round(centerX + length * cos(anglesRad));
    yEnd = round(centerY + length * sin(anglesRad));
    
    % 绘制每条线
    for i = 1:6
        img = drawLine(img, waferImg, centerX, centerY, xEnd(i), yEnd(i), width);
    end
end

% 绘制线条
function img = drawLine(img, waferImg, x1, y1, x2, y2, width)
    % 使用Bresenham算法获取线上的点
    [x, y] = bresenham(x1, y1, x2, y2);
    
    % 绘制每个点
    for i = 1:length(x)
        % 检查点是否在图像边界内
        if x(i) < 1 || x(i) > size(img, 2) || y(i) < 1 || y(i) > size(img, 1)
            continue;
        end
        
        % 如果遇到NaN值，停止绘制
        if isnan(waferImg(y(i), x(i)))
            break;
        end
        
        % 绘制指定宽度的线
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

% Bresenham算法实现
function [x, y] = bresenham(x1, y1, x2, y2)
    % 四舍五入输入坐标以保持一致性
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
    
    % 初始化空数组以存储线上的点
    x = [];
    y = [];
    
    % Bresenham算法的主循环
    while true
        % 存储当前点
        x = [x; x1];
        y = [y; y1];
        
        % 检查是否已到达终点
        if (x1 == x2 && y1 == y2) || ...
           ((sx > 0 && x1 >= x2) && (sy > 0 && y1 >= y2)) || ...
           ((sx < 0 && x1 <= x2) && (sy < 0 && y1 <= y2))
            break;
        end
        
        % 计算决策参数
        e2 = 2 * err;
        
        % 如果需要，更新误差项和x坐标
        if e2 > -dy
            err = err - dy;
            x1 = x1 + sx;
        end
        
        % 如果需要，更新误差项和y坐标
        if e2 < dx
            err = err + dx;
            y1 = y1 + sy;
        end
    end
end
