# utils/init_utils.py
import torch
import torch.nn as nn
import torch.nn.init as init
import math

class WeightInitializer:
    """权重初始化类"""
    
    @staticmethod
    def he_normal_init(m):
        """He正态分布初始化（适用于ReLU激活）"""
        if isinstance(m, (nn.Conv2d, nn.ConvTranspose2d)):
            init.kaiming_normal_(m.weight, mode='fan_out', nonlinearity='relu')
            if m.bias is not None:
                init.constant_(m.bias, 0)
        elif isinstance(m, nn.BatchNorm2d):
            init.constant_(m.weight, 1)
            init.constant_(m.bias, 0)
        elif isinstance(m, nn.Linear):
            init.kaiming_normal_(m.weight, mode='fan_out', nonlinearity='relu')
            if m.bias is not None:
                init.constant_(m.bias, 0)
    
    @staticmethod
    def he_uniform_init(m):
        """He均匀分布初始化"""
        if isinstance(m, (nn.Conv2d, nn.ConvTranspose2d)):
            init.kaiming_uniform_(m.weight, mode='fan_out', nonlinearity='relu')
            if m.bias is not None:
                init.constant_(m.bias, 0)
        elif isinstance(m, nn.BatchNorm2d):
            init.constant_(m.weight, 1)
            init.constant_(m.bias, 0)
        elif isinstance(m, nn.Linear):
            init.kaiming_uniform_(m.weight, mode='fan_out', nonlinearity='relu')
            if m.bias is not None:
                init.constant_(m.bias, 0)
    
    @staticmethod
    def xavier_normal_init(m):
        """Xavier正态分布初始化（适用于Sigmoid/Tanh激活）"""
        if isinstance(m, (nn.Conv2d, nn.ConvTranspose2d)):
            init.xavier_normal_(m.weight)
            if m.bias is not None:
                init.constant_(m.bias, 0)
        elif isinstance(m, nn.BatchNorm2d):
            init.constant_(m.weight, 1)
            init.constant_(m.bias, 0)
        elif isinstance(m, nn.Linear):
            init.xavier_normal_(m.weight)
            if m.bias is not None:
                init.constant_(m.bias, 0)
    
    @staticmethod
    def xavier_uniform_init(m):
        """Xavier均匀分布初始化"""
        if isinstance(m, (nn.Conv2d, nn.ConvTranspose2d)):
            init.xavier_uniform_(m.weight)
            if m.bias is not None:
                init.constant_(m.bias, 0)
        elif isinstance(m, nn.BatchNorm2d):
            init.constant_(m.weight, 1)
            init.constant_(m.bias, 0)
        elif isinstance(m, nn.Linear):
            init.xavier_uniform_(m.weight)
            if m.bias is not None:
                init.constant_(m.bias, 0)
    
    @staticmethod
    def orthogonal_init(m):
        """正交初始化"""
        if isinstance(m, (nn.Conv2d, nn.ConvTranspose2d)):
            init.orthogonal_(m.weight)
            if m.bias is not None:
                init.constant_(m.bias, 0)
        elif isinstance(m, nn.BatchNorm2d):
            init.constant_(m.weight, 1)
            init.constant_(m.bias, 0)
        elif isinstance(m, nn.Linear):
            init.orthogonal_(m.weight)
            if m.bias is not None:
                init.constant_(m.bias, 0)
    
    @staticmethod
    def custom_unet_init(m):
        """
        针对U-Net的自定义初始化
        结合多种策略以获得更好的训练稳定性
        """
        if isinstance(m, nn.Conv2d):
            # 对于卷积层使用He初始化
            fan_in = m.weight.size(1) * m.weight.size(2) * m.weight.size(3)
            fan_out = m.weight.size(0) * m.weight.size(2) * m.weight.size(3)
            
            # 使用改进的He初始化
            std = math.sqrt(2.0 / fan_in)
            init.normal_(m.weight, 0, std)
            
            if m.bias is not None:
                init.constant_(m.bias, 0)
                
        elif isinstance(m, nn.ConvTranspose2d):
            # 对于转置卷积，使用特殊初始化以避免棋盘效应
            fan_in = m.weight.size(1) * m.weight.size(2) * m.weight.size(3)
            std = math.sqrt(1.0 / fan_in)
            init.normal_(m.weight, 0, std)
            
            if m.bias is not None:
                init.constant_(m.bias, 0)
                
        elif isinstance(m, nn.BatchNorm2d):
            # BatchNorm层标准初始化
            init.constant_(m.weight, 1)
            init.constant_(m.bias, 0)
            
        elif isinstance(m, nn.Linear):
            # 线性层使用Xavier初始化
            init.xavier_normal_(m.weight)
            if m.bias is not None:
                init.constant_(m.bias, 0)
    
    @staticmethod
    def attention_specific_init(m):
        """
        针对注意力机制的特殊初始化
        """
        if hasattr(m, '__class__') and 'Attention' in m.__class__.__name__:
            # 注意力层的权重应该较小，避免过度关注
            for param in m.parameters():
                if param.dim() > 1:
                    init.xavier_uniform_(param, gain=0.1)
                else:
                    init.constant_(param, 0)

def get_initializer(init_type='he_normal'):
    """
    获取初始化函数
    
    Args:
        init_type (str): 初始化类型
    
    Returns:
        function: 初始化函数
    """
    initializers = {
        'he_normal': WeightInitializer.he_normal_init,
        'he_uniform': WeightInitializer.he_uniform_init,
        'xavier_normal': WeightInitializer.xavier_normal_init,
        'xavier_uniform': WeightInitializer.xavier_uniform_init,
        'orthogonal': WeightInitializer.orthogonal_init,
        'custom_unet': WeightInitializer.custom_unet_init,
    }
    
    if init_type not in initializers:
        raise ValueError(f"不支持的初始化类型: {init_type}. 支持的类型: {list(initializers.keys())}")
    
    return initializers[init_type]

def initialize_model(model, init_type='he_normal', verbose=True):
    """
    初始化整个模型的权重
    
    Args:
        model (nn.Module): 待初始化的模型
        init_type (str): 初始化类型
        verbose (bool): 是否打印初始化信息
    
    Returns:
        nn.Module: 初始化后的模型
    """
    initializer = get_initializer(init_type)
    
    # 计算初始化前后的权重统计
    if verbose:
        print(f"使用 {init_type} 初始化模型权重...")
        
        # 统计模型参数
        total_params = sum(p.numel() for p in model.parameters())
        trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
        
        print(f"模型总参数: {total_params:,}")
        print(f"可训练参数: {trainable_params:,}")
    
    # 应用初始化
    model.apply(initializer)
    
    # 对注意力层进行特殊初始化
    model.apply(WeightInitializer.attention_specific_init)
    
    if verbose:
        # 打印初始化后的权重统计
        print("权重初始化完成!")
        
        # 检查一些关键层的权重范围
        conv_weights = []
        bn_weights = []
        
        for name, param in model.named_parameters():
            if 'conv' in name.lower() and 'weight' in name:
                conv_weights.extend(param.data.flatten().tolist())
            elif 'bn' in name.lower() and 'weight' in name:
                bn_weights.extend(param.data.flatten().tolist())
        
        if conv_weights:
            conv_weights = torch.tensor(conv_weights)
            print(f"卷积层权重范围: [{conv_weights.min():.4f}, {conv_weights.max():.4f}], "
                  f"均值: {conv_weights.mean():.4f}, 标准差: {conv_weights.std():.4f}")
        
        if bn_weights:
            bn_weights = torch.tensor(bn_weights)
            print(f"BatchNorm权重范围: [{bn_weights.min():.4f}, {bn_weights.max():.4f}], "
                  f"均值: {bn_weights.mean():.4f}, 标准差: {bn_weights.std():.4f}")
    
    return model
