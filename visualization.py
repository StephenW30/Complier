# utils/visualization.py
import os
import matplotlib.pyplot as plt
import numpy as np
import torch

def denormalize(tensor, channels=1):
    """反归一化张量"""
    tensor = tensor.clone()
    if channels == 1:
        # 单通道图像
        tensor = tensor * 0.5 + 0.5
    else:
        # RGB图像
        mean = torch.tensor([0.485, 0.456, 0.406]).view(-1, 1, 1)
        std = torch.tensor([0.229, 0.224, 0.225]).view(-1, 1, 1)
        tensor = tensor * std + mean
    return tensor

def visualize_predictions(images, masks, predictions, save_dir, epoch, num_examples=4, channels=1):
    """可视化预测结果，支持单通道和三通道图像"""
    # 确保不超过批次大小
    num_examples = min(num_examples, images.size(0))
    
    plt.figure(figsize=(15, 5 * num_examples))
    
    for i in range(num_examples):
        # 原始图像
        plt.subplot(num_examples, 3, i*3 + 1)
        
        if channels == 1:
            # 单通道图像
            img = denormalize(images[i], channels).squeeze().numpy()
            plt.imshow(img, cmap='gray')
        else:
            # 三通道图像
            img = denormalize(images[i], channels).permute(1, 2, 0).numpy()
            img = np.clip(img, 0, 1)
            plt.imshow(img)
            
        plt.title('输入图像')
        plt.axis('off')
        
        # 真实掩码
        plt.subplot(num_examples, 3, i*3 + 2)
        mask = masks[i].squeeze().numpy()
        plt.imshow(mask, cmap='gray')
        plt.title('真实标签')
        plt.axis('off')
        
        # 预测掩码
        plt.subplot(num_examples, 3, i*3 + 3)
        pred = (predictions[i].squeeze() > 0.5).float().numpy()
        plt.imshow(pred, cmap='gray')
        plt.title('预测结果')
        plt.axis('off')
    
    plt.tight_layout()
    plt.savefig(os.path.join(save_dir, f'predictions_epoch_{epoch}.png'))
    plt.close()
