function [waferData, waferInfo] = loadMatData(filePath)
    % Load the .mat file
    matData = load(filePath);
    
    % Initialize waferInfo structure
    waferInfo = struct();
    
    % Get the field names in the .mat file
    fieldNames = fieldnames(matData);
    
    % Look for wafer data - typically the largest numerical array
    waferData = [];
    maxSize = 0;
    
    for i = 1:length(fieldNames)
        currentField = matData.(fieldNames{i});
        
        % Check if it's a numeric array
        if isnumeric(currentField) && ndims(currentField) == 2
            currentSize = numel(currentField);
            if currentSize > maxSize
                waferData = currentField;
                maxSize = currentSize;
            end
        end
    end
    
    % If no suitable data found, throw an error
    if isempty(waferData)
        error('Could not find wafer data in file: %s', filePath);
    end
    
    % Get wafer dimensions
    waferInfo.Shape = size(waferData);  % [height, width]
    
    % Extract wafer name - use filename if no name field found
    waferInfo.Name = [];
    for i = 1:length(fieldNames)
        if strcmpi(fieldNames{i}, 'name') || strcmpi(fieldNames{i}, 'waferName')
            if ischar(matData.(fieldNames{i}))
                waferInfo.Name = matData.(fieldNames{i});
                break;
            end
        end
    end
    
    if isempty(waferInfo.Name)
        [~, waferInfo.Name, ~] = fileparts(filePath);
    end
    
    % Replace 0 values with NaN
    waferData(waferData == 0) = nan;
    
    % Look for pixel size information
    waferInfo.PixelSizeMm = 0.1;  % Default value
    for i = 1:length(fieldNames)
        if strcmpi(fieldNames{i}, 'pixelSize') || strcmpi(fieldNames{i}, 'pixelSizeMm')
            if isnumeric(matData.(fieldNames{i})) && isscalar(matData.(fieldNames{i}))
                waferInfo.PixelSizeMm = matData.(fieldNames{i});
                break;
            end
        end
    end
    
    % Display found information
    fprintf('Loaded file: %s\n', filePath);
    fprintf('  Wafer name: %s\n', waferInfo.Name);
    fprintf('  Dimensions: %d x %d\n', waferInfo.Shape(1), waferInfo.Shape(2));
    fprintf('  Pixel size: %.4f mm\n', waferInfo.PixelSizeMm);
end





import os
import numpy as np
import matplotlib.pyplot as plt
from scipy.io import savemat
import torch
from torch.utils.data import DataLoader
import cv2
import albumentations as A
from albumentations.pytorch import ToTensorV2

# 导入修改后的数据集类
# 假设SegmentationDataset类在dataset.py文件中
from utils.dataset import SegmentationDataset

# 创建测试数据函数
def create_test_data(test_dir):
    """创建用于测试的数据文件"""
    # 创建测试目录（如果不存在）
    os.makedirs(test_dir, exist_ok=True)
    
    # 创建一个简单的灰度图像和掩码
    img = np.zeros((100, 100), dtype=np.uint8)
    img[25:75, 25:75] = 128  # 中间区域灰色
    
    mask = np.zeros((100, 100), dtype=np.uint8)
    mask[30:70, 30:70] = 255  # 中间区域白色（表示前景）
    
    # 保存为PNG文件
    cv2.imwrite(os.path.join(test_dir, 'test_image.png'), img)
    cv2.imwrite(os.path.join(test_dir, 'test_mask.png'), mask)
    
    # 创建特定命名模式的.mat文件
    base_name = 'test_sample'
    
    # 保存PLStar.mat文件
    data_dict = {'modifiedMap': img}
    savemat(os.path.join(test_dir, f'{base_name}_PLStar.mat'), data_dict)
    
    # 保存Mask.mat文件
    mask_dict = {'maskMap': mask}
    savemat(os.path.join(test_dir, f'{base_name}_Mask.mat'), mask_dict)
    
    print(f"测试数据已创建在: {test_dir}")

# 可视化函数
def visualize_sample(img, mask, title="样本可视化"):
    """可视化一个样本（图像和掩码）"""
    fig, axes = plt.subplots(1, 2, figsize=(10, 5))
    
    # 如果是PyTorch张量，转换为numpy数组
    if isinstance(img, torch.Tensor):
        img = img.numpy()
        # 如果是多通道图像 [C,H,W]，转换为 [H,W,C]
        if img.shape[0] in [1, 3]:
            img = np.transpose(img, (1, 2, 0))
        # 如果是单通道，去掉通道维度
        if img.shape[-1] == 1:
            img = img.squeeze(-1)
    
    if isinstance(mask, torch.Tensor):
        mask = mask.numpy()
        if mask.shape[0] == 1:  # [1,H,W] -> [H,W]
            mask = mask.squeeze(0)
    
    # 显示图像
    axes[0].imshow(img, cmap='gray')
    axes[0].set_title('图像')
    axes[0].axis('off')
    
    # 显示掩码
    axes[1].imshow(mask, cmap='gray')
    axes[1].set_title('掩码')
    axes[1].axis('off')
    
    plt.suptitle(title)
    plt.tight_layout()
    plt.show()

# 主测试函数
def test_dataset(data_dir, use_transform=False):
    """测试数据集类"""
    # 定义简单的数据变换（可选）
    if use_transform:
        transform = A.Compose([
            A.Resize(64, 64),
            A.HorizontalFlip(p=0.5),
            A.Normalize(mean=[0.5], std=[0.5]),
        ])
    else:
        transform = None
    
    # 创建数据集实例
    dataset = SegmentationDataset(
        img_dir=data_dir,
        mask_dir=data_dir,  # 使用相同目录以简化测试
        transform=transform
    )
    
    print(f"数据集大小: {len(dataset)}")
    
    # 创建DataLoader
    dataloader = DataLoader(dataset, batch_size=1, shuffle=False)
    
    # 遍历数据集中的样本
    for i, (img, mask) in enumerate(dataloader):
        print(f"样本 {i+1}:")
        print(f"  图像形状: {img.shape}")
        print(f"  掩码形状: {mask.shape}")
        print(f"  图像值范围: [{img.min().item()}, {img.max().item()}]")
        print(f"  掩码值范围: [{mask.min().item()}, {mask.max().item()}]")
        
        # 可视化样本
        visualize_sample(img[0], mask[0], f"样本 {i+1}")

# 运行测试
if __name__ == "__main__":
    # 测试目录
    TEST_DIR = "./test_segmentation_data"
    
    # 创建测试数据
    create_test_data(TEST_DIR)
    
    # 测试数据集
    print("\n==== 测试不带数据增强 ====")
    test_dataset(TEST_DIR, use_transform=False)
    
    print("\n==== 测试带数据增强 ====")
    test_dataset(TEST_DIR, use_transform=True)
