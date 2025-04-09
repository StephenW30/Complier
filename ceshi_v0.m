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






import os
import numpy as np
import matplotlib.pyplot as plt
import torch
from torch.utils.data import DataLoader
from scipy.io import loadmat

# 导入修改后的数据集类
# 假设SegmentationDataset类在dataset.py文件中
from utils.dataset import SegmentationDataset

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

# 显示目录内容
def show_directory_content(dir_path):
    """显示指定目录中的文件"""
    print(f"\n目录 '{dir_path}' 中的文件:")
    files = sorted(os.listdir(dir_path))
    
    # 分类文件
    mat_files = [f for f in files if f.endswith('.mat')]
    image_files = [f for f in files if f.endswith(('.png', '.jpg', '.jpeg'))]
    other_files = [f for f in files if f not in mat_files and f not in image_files]
    
    if mat_files:
        print("\n.mat文件:")
        for f in mat_files:
            print(f"  - {f}")
        
        # 特别检查符合特定命名模式的.mat文件
        plstar_files = [f for f in mat_files if f.endswith('_PLStar.mat')]
        mask_files = [f for f in mat_files if f.endswith('_Mask.mat')]
        
        if plstar_files:
            print("\n  其中_PLStar.mat文件:")
            for f in plstar_files:
                print(f"    - {f}")
        
        if mask_files:
            print("\n  其中_Mask.mat文件:")
            for f in mask_files:
                print(f"    - {f}")
    
    if image_files:
        print("\n图像文件:")
        for f in image_files:
            print(f"  - {f}")
    
    if other_files:
        print("\n其他文件:")
        for f in other_files:
            print(f"  - {f}")

# 检查.mat文件内容
def check_mat_file(file_path):
    """检查.mat文件的内容和结构"""
    try:
        data = loadmat(file_path)
        print(f"\n检查.mat文件: {os.path.basename(file_path)}")
        
        # 打印文件中的所有变量名
        print("文件中的变量:")
        for key in data.keys():
            if not key.startswith('__'):  # 跳过内部变量
                var_shape = data[key].shape
                var_type = data[key].dtype
                print(f"  - {key}: 形状{var_shape}, 类型{var_type}")
                
                # 如果是我们期望的变量，显示更多信息
                if key in ['modifiedMap', 'maskMap']:
                    array_data = data[key]
                    print(f"    值范围: [{np.min(array_data)}, {np.max(array_data)}]")
                    
        return data
    except Exception as e:
        print(f"无法加载.mat文件 {file_path}: {str(e)}")
        return None

# 主测试函数
def test_dataset(img_dir, mask_dir=None):
    """测试数据集类与现有数据"""
    # 如果没有指定掩码目录，则使用与图像相同的目录
    if mask_dir is None:
        mask_dir = img_dir
    
    # 显示目录内容
    show_directory_content(img_dir)
    if img_dir != mask_dir:
        show_directory_content(mask_dir)
    
    # 检查第一个.mat文件的内容（如果存在）
    mat_files = [f for f in os.listdir(img_dir) if f.endswith('.mat')]
    if mat_files:
        sample_file = next((f for f in mat_files if f.endswith('_PLStar.mat')), mat_files[0])
        check_mat_file(os.path.join(img_dir, sample_file))
    
    # 创建数据集实例 (无数据增强)
    dataset = SegmentationDataset(
        img_dir=img_dir,
        mask_dir=mask_dir,
        transform=None
    )
    
    print(f"\n数据集大小: {len(dataset)}")
    
    # 创建DataLoader
    dataloader = DataLoader(dataset, batch_size=1, shuffle=False)
    
    # 测试前几个样本
    max_samples = min(3, len(dataset))  # 最多显示3个样本
    
    for i, (img, mask) in enumerate(dataloader):
        if i >= max_samples:
            break
            
        print(f"\n样本 {i+1}:")
        print(f"  图像形状: {img.shape}")
        print(f"  掩码形状: {mask.shape}")
        print(f"  图像值范围: [{img.min().item():.4f}, {img.max().item():.4f}]")
        print(f"  掩码值范围: [{mask.min().item():.4f}, {mask.max().item():.4f}]")
        
        # 可视化样本
        visualize_sample(img[0], mask[0], f"样本 {i+1}")

# 运行测试
if __name__ == "__main__":
    # 请替换为您的数据目录路径
    DATA_DIR = "./your_data_directory"
    
    # 如果图像和掩码在不同目录，可以分别指定
    # MASK_DIR = "./your_mask_directory"
    # test_dataset(DATA_DIR, MASK_DIR)
    
    # 如果图像和掩码在同一目录
    test_dataset(DATA_DIR)
