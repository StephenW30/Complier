import os
import shutil
import random
import glob
import re
from pathlib import Path

def split_dataset(simulation_dir, label_dir, output_dir, train_ratio=0.7, val_ratio=0.15, test_ratio=0.15):
    """
    将simulation_hazemap和label目录下的.mat数据划分并复制到initial_training目录下的train, val, test目录中
    
    参数:
        simulation_dir: simulation_hazemap目录的路径，包含图像数据（*_PLStar.mat格式）
        label_dir: label目录的路径，包含掩码数据（*_Mask.mat格式）
        output_dir: 输出目录的路径（initial_training）
        train_ratio: 训练集比例，默认为0.7
        val_ratio: 验证集比例，默认为0.15
        test_ratio: 测试集比例，默认为0.15
    """
    # 确保比例之和为1
    assert abs(train_ratio + val_ratio + test_ratio - 1.0) < 1e-5, "划分比例之和必须为1"
    
    # 创建目录结构
    for split in ['train', 'val', 'test']:
        for subdir in ['images', 'masks']:
            os.makedirs(os.path.join(output_dir, split, subdir), exist_ok=True)
    
    # 获取所有图像文件（*_PLStar.mat格式）
    image_files = sorted(glob.glob(os.path.join(simulation_dir, '**', '*_PLStar.mat'), recursive=True))
    
    # 确保找到了图像文件
    if not image_files:
        raise ValueError(f"在 {simulation_dir} 中未找到*_PLStar.mat格式的图像文件")
    
    # 随机打乱文件顺序以确保随机划分
    random.seed(42)  # 设定随机种子以确保可重复性
    random.shuffle(image_files)
    
    # 计算每个集合的大小
    num_files = len(image_files)
    num_train = int(train_ratio * num_files)
    num_val = int(val_ratio * num_files)
    
    # 划分数据集
    train_files = image_files[:num_train]
    val_files = image_files[num_train:num_train + num_val]
    test_files = image_files[num_train + num_val:]
    
    # 映射数据集划分
    split_mapping = {
        'train': train_files,
        'val': val_files,
        'test': test_files
    }
    
    # 复制文件到对应目录
    for split, files in split_mapping.items():
        print(f"正在处理 {split} 集，共 {len(files)} 个文件")
        
        for img_path in files:
            # 获取图像文件名
            img_name = os.path.basename(img_path)
            
            # 获取文件名前缀（去掉_PLStar.mat部分）
            base_name = img_name.replace('_PLStar.mat', '')
            
            # 复制图像文件到目标目录
            dst_img_path = os.path.join(output_dir, split, 'images', img_name)
            shutil.copy2(img_path, dst_img_path)
            print(f"复制图像: {img_path} -> {dst_img_path}")
            
            # 查找对应的掩码文件（同名但使用_Mask.mat后缀）
            mask_name = f"{base_name}_Mask.mat"
            mask_candidates = glob.glob(os.path.join(label_dir, '**', mask_name), recursive=True)
            
            if mask_candidates:
                mask_path = mask_candidates[0]  # 使用找到的第一个匹配项
                dst_mask_path = os.path.join(output_dir, split, 'masks', mask_name)
                shutil.copy2(mask_path, dst_mask_path)
                print(f"复制掩码: {mask_path} -> {dst_mask_path}")
            else:
                print(f"警告: 未找到图像 {img_name} 的对应掩码文件 {mask_name}")
    
    # 输出统计信息
    print("\n数据集划分完成:")
    print(f"训练集: {len(train_files)} 个文件")
    print(f"验证集: {len(val_files)} 个文件")
    print(f"测试集: {len(test_files)} 个文件")
    print(f"总计: {len(image_files)} 个文件")

if __name__ == "__main__":
    # 配置目录路径
    simulation_dir = "simulation_hazemap"  # 图像目录，包含*_PLStar.mat文件
    label_dir = "label"                    # 掩码目录，包含*_Mask.mat文件
    output_dir = "initial_training"        # 输出目录
    
    # 划分比例
    train_ratio = 0.7  # 70% 用于训练
    val_ratio = 0.15   # 15% 用于验证
    test_ratio = 0.15  # 15% 用于测试
    
    print("开始数据集划分...")
    print(f"将从 {simulation_dir} 读取 *_PLStar.mat 文件作为图像")
    print(f"将从 {label_dir} 读取 *_Mask.mat 文件作为掩码")
    print(f"输出目录: {output_dir}")
    print(f"划分比例: 训练集 {train_ratio*100}%, 验证集 {val_ratio*100}%, 测试集 {test_ratio*100}%")
    
    # 执行数据集划分
    split_dataset(simulation_dir, label_dir, output_dir, train_ratio, val_ratio, test_ratio)
