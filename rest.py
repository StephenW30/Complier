import os
import cv2
import numpy as np
import torch
from torch.utils.data import Dataset
from scipy.io import loadmat

class SegmentationDataset(Dataset):
    def __init__(self, img_dir, mask_dir, transform=None):
        """
        初始化分割数据集，支持多种文件格式
        
        Args:
            img_dir: 输入图像目录（支持.png, .jpg, .jpeg, .mat文件）
            mask_dir: 掩码图像目录（支持.png, .jpg, .jpeg, .mat文件）
            transform: 数据增强转换
        """
        self.img_dir = img_dir
        self.mask_dir = mask_dir
        self.transform = transform
        
        # 获取所有支持的图像文件名
        self.img_files = []
        
        # 遍历目录中的文件
        all_files = sorted(os.listdir(img_dir))
        for f in all_files:
            if f.endswith(('.png', '.jpg', '.jpeg')):
                self.img_files.append(f)
            elif f.endswith('_PLStar.mat'):  # 特殊处理以_PLStar.mat结尾的文件
                self.img_files.append(f)
        
    def __len__(self):
        return len(self.img_files)
    
    def __getitem__(self, idx):
        # 获取文件名
        file_name = self.img_files[idx]
        file_ext = os.path.splitext(file_name)[1].lower()
        
        # 加载图像数据
        img_path = os.path.join(self.img_dir, file_name)
        
        # 根据文件扩展名决定如何加载
        if file_ext == '.mat':
            # 从.mat文件加载数据
            img_data = loadmat(img_path)
            img = img_data['modifiedMap']
            
            # 确定掩码文件路径
            if file_name.endswith('_PLStar.mat'):
                # 将 _PLStar.mat 替换为 _Mask.mat 得到对应的掩码文件名
                base_name = file_name[:-11]  # 去掉 _PLStar.mat
                mask_file = base_name + '_Mask.mat'
                mask_path = os.path.join(self.mask_dir, mask_file)
            else:
                # 如果不是特定命名模式，则尝试使用同名文件
                mask_path = os.path.join(self.mask_dir, file_name)
            
            mask_data = loadmat(mask_path)
            mask = mask_data['maskMap']
        else:
            # 加载图像文件
            img = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)  # 默认读取为灰度图
            
            # 构建掩码文件名
            # 尝试查找具有相同基本名称但可能有不同扩展名的掩码文件
            base_name = os.path.splitext(file_name)[0]
            mask_candidates = [
                os.path.join(self.mask_dir, base_name + ext)
                for ext in ['.png', '.jpg', '.jpeg', '.mat']
            ]
            
            # 找到第一个存在的掩码文件
            mask_path = None
            for candidate in mask_candidates:
                if os.path.exists(candidate):
                    mask_path = candidate
                    break
                    
            if mask_path is None:
                # 如果找不到对应的掩码文件，尝试查找相同文件名的掩码
                mask_path = os.path.join(self.mask_dir, file_name)
                
            # 根据掩码文件扩展名加载
            mask_ext = os.path.splitext(mask_path)[1].lower()
            if mask_ext == '.mat':
                mask_data = loadmat(mask_path)
                mask = mask_data['maskMap']
            else:
                mask = cv2.imread(mask_path, cv2.IMREAD_GRAYSCALE)
        
        # 确保图像是灰度图
        if img is None:
            raise RuntimeError(f"无法加载图像: {img_path}")
        if mask is None:
            raise RuntimeError(f"无法加载掩码: {mask_path}")
            
        # 确保数据是正确的维度
        # 如果图像有3个通道但实际是灰度图（所有通道相同），则转换为单通道
        if len(img.shape) == 3 and img.shape[2] == 3:
            if np.allclose(img[:,:,0], img[:,:,1]) and np.allclose(img[:,:,0], img[:,:,2]):
                img = img[:,:,0]
                
        # 确保掩码是灰度图
        if len(mask.shape) == 3:
            mask = mask[:,:,0]
            
        # 数据增强
        if self.transform:
            # 确保图像有正确的格式供albumentations处理
            if len(img.shape) == 2:
                img_for_transform = np.expand_dims(img, axis=2)  # [H,W] -> [H,W,1]
            else:
                img_for_transform = img
                
            transformed = self.transform(image=img_for_transform, mask=mask)
            img = transformed['image']
            mask = transformed['mask']
            
            # 如果是灰度图像，可能会被转换成[H,W,1]，需要转回[H,W]
            if img.shape[2] == 1:
                img = img[:,:,0]
                
        # 转换为PyTorch张量
        # 对于灰度图，确保维度为[1,H,W]
        if len(img.shape) == 2:
            img = torch.from_numpy(img).float().unsqueeze(0)
        else:
            img = torch.from_numpy(img.transpose(2, 0, 1)).float()
            
        # 对掩码进行同样处理
        mask = torch.from_numpy(mask).float().unsqueeze(0)  # [H,W] -> [1,H,W]
        
        # 归一化到[0,1]范围（如果需要）
        if img.max() > 1.0:
            img = img / 255.0
        if mask.max() > 1.0:
            mask = mask / 255.0
        
        return img, mask




# losses/loss_functions.py
import torch
import torch.nn as nn
import torch.nn.functional as F

class DiceLoss(nn.Module):
    def __init__(self, smooth=1.0, activation='sigmoid'):
        super(DiceLoss, self).__init__()
        self.smooth = smooth
        self.activation = activation
        
    def forward(self, pred, target):
        if self.activation == 'sigmoid':
            pred = torch.sigmoid(pred)
        
        # 展平预测和目标
        pred = pred.view(-1)
        target = target.view(-1)
        
        intersection = (pred * target).sum()
        dice = (2.0 * intersection + self.smooth) / (pred.sum() + target.sum() + self.smooth)
        return 1.0 - dice

class FocalLoss(nn.Module):
    def __init__(self, alpha=0.25, gamma=2.0, reduction='mean'):
        super(FocalLoss, self).__init__()
        self.alpha = alpha
        self.gamma = gamma
        self.reduction = reduction
        
    def forward(self, pred, target):
        # 应用sigmoid激活
        pred_prob = torch.sigmoid(pred)
        
        # 计算BCE
        bce = F.binary_cross_entropy_with_logits(pred, target, reduction='none')
        
        # 计算focal权重
        pt = target * pred_prob + (1 - target) * (1 - pred_prob)
        focal_weight = (1 - pt) ** self.gamma
        
        # 应用alpha
        alpha_weight = target * self.alpha + (1 - target) * (1 - self.alpha)
        
        # 计算最终loss
        loss = alpha_weight * focal_weight * bce
        
        if self.reduction == 'mean':
            return loss.mean()
        elif self.reduction == 'sum':
            return loss.sum()
        else:
            return loss

class TverskyLoss(nn.Module):
    def __init__(self, alpha=0.5, beta=0.5, smooth=1.0):
        super(TverskyLoss, self).__init__()
        self.alpha = alpha
        self.beta = beta
        self.smooth = smooth
        
    def forward(self, pred, target):
        pred = torch.sigmoid(pred)
        
        # 展平预测和目标
        pred = pred.view(-1)
        target = target.view(-1)
        
        # True Positive, False Positive, False Negative
        TP = (pred * target).sum()
        FP = (pred * (1 - target)).sum()
        FN = ((1 - pred) * target).sum()
        
        # Tversky指数
        tversky = (TP + self.smooth) / (TP + self.alpha * FP + self.beta * FN + self.smooth)
        return 1 - tversky

class CombinedLoss(nn.Module):
    def __init__(self, config):
        super(CombinedLoss, self).__init__()
        # 加载配置
        self.dice_weight = config['loss']['dice_weight']
        self.bce_weight = config['loss']['bce_weight']
        self.focal_weight = config['loss']['focal_weight']
        
        # 初始化各损失组件
        self.bce = nn.BCEWithLogitsLoss()
        self.dice = DiceLoss()
        self.focal = FocalLoss(
            alpha=config['loss']['focal_alpha'],
            gamma=config['loss']['focal_gamma']
        )
        self.tversky = TverskyLoss(
            alpha=config['loss']['tversky_alpha'],
            beta=config['loss']['tversky_beta']
        )
    
    def forward(self, pred, target):
        # 计算各组件损失
        bce_loss = self.bce(pred, target)
        dice_loss = self.dice(pred, target)
        focal_loss = self.focal(pred, target)
        tversky_loss = self.tversky(pred, target)
        
        # 组合损失
        loss = (self.bce_weight * bce_loss + 
                self.dice_weight * dice_loss + 
                self.focal_weight * focal_loss +
                (1 - self.bce_weight - self.dice_weight - self.focal_weight) * tversky_loss)
        
        return loss, {
            'bce': bce_loss.item(),
            'dice': dice_loss.item(),
            'focal': focal_loss.item(),
            'tversky': tversky_loss.item()
        }

def get_loss_function(config):
    """根据配置获取损失函数"""
    loss_type = config['loss']['type'].lower()
    
    if loss_type == 'bce':
        return nn.BCEWithLogitsLoss()
    elif loss_type == 'dice':
        return DiceLoss()
    elif loss_type == 'focal':
        return FocalLoss(
            alpha=config['loss']['focal_alpha'],
            gamma=config['loss']['focal_gamma']
        )
    elif loss_type == 'tversky':
        return TverskyLoss(
            alpha=config['loss']['tversky_alpha'],
            beta=config['loss']['tversky_beta']
        )
    elif loss_type == 'combined':
        return CombinedLoss(config)
    else:
        raise ValueError(f"不支持的损失函数类型: {loss_type}")









# utils/metrics.py
import torch
import numpy as np
from sklearn.metrics import precision_score, recall_score, accuracy_score

def dice_coefficient(y_pred, y_true, smooth=1e-7):
    """计算Dice系数"""
    # 确保为二进制
    y_pred = (y_pred > 0.5).float()
    y_true = (y_true > 0.5).float()
    
    # 压平数据
    y_pred = y_pred.view(-1)
    y_true = y_true.view(-1)
    
    # 计算交集和合集
    intersection = (y_pred * y_true).sum()
    return (2. * intersection + smooth) / (y_pred.sum() + y_true.sum() + smooth)

def iou_score(y_pred, y_true, smooth=1e-7):
    """计算IoU/Jaccard指数"""
    # 确保为二进制
    y_pred = (y_pred > 0.5).float()
    y_true = (y_true > 0.5).float()
    
    # 压平数据
    y_pred = y_pred.view(-1)
    y_true = y_true.view(-1)
    
    # 计算交集和合集
    intersection = (y_pred * y_true).sum()
    union = y_pred.sum() + y_true.sum() - intersection
    return (intersection + smooth) / (union + smooth)

def precision(y_pred, y_true):
    """计算精确率"""
    y_pred = (y_pred > 0.5).float().cpu().numpy().flatten()
    y_true = y_true.cpu().numpy().flatten()
    return precision_score(y_true, y_pred, zero_division=1)

def recall(y_pred, y_true):
    """计算召回率"""
    y_pred = (y_pred > 0.5).float().cpu().numpy().flatten()
    y_true = y_true.cpu().numpy().flatten()
    return recall_score(y_true, y_pred, zero_division=1)

def accuracy(y_pred, y_true):
    """计算准确率"""
    y_pred = (y_pred > 0.5).float().cpu().numpy().flatten()
    y_true = y_true.cpu().numpy().flatten()
    return accuracy_score(y_true, y_pred)

def calculate_metrics(y_pred, y_true, metrics_list):
    """计算多个评估指标"""
    results = {}
    
    for metric in metrics_list:
        if metric == 'dice':
            results['dice'] = dice_coefficient(y_pred, y_true).item()
        elif metric == 'iou':
            results['iou'] = iou_score(y_pred, y_true).item()
        elif metric == 'precision':
            results['precision'] = precision(y_pred, y_true)
        elif metric == 'recall':
            results['recall'] = recall(y_pred, y_true)
        elif metric == 'accuracy':
            results['accuracy'] = accuracy(y_pred, y_true)
    
    return results










