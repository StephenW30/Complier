# train.py
import os
import time
import yaml
import argparse
import numpy as np
from tqdm import tqdm
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torch.utils.tensorboard import SummaryWriter

from models.unet import UNet
from utils.dataset import SegmentationDataset
from utils.transforms import get_training_augmentation, get_validation_augmentation
from utils.metrics import calculate_metrics
from losses.loss_functions import get_loss_function
from utils.visualization import visualize_predictions

def parse_args():
    parser = argparse.ArgumentParser(description='Train U-Net model for segmentation')
    parser.add_argument('--config', type=str, default='configs/config.yaml', help='配置文件路径')
    parser.add_argument('--resume', type=str, default=None, help='恢复训练的检查点路径')
    return parser.parse_args()

def load_config(config_path):
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    return config

def get_lr_scheduler(optimizer, config):
    """获取学习率调度器"""
    scheduler_type = config['training']['lr_scheduler'].lower()
    
    if scheduler_type == 'reduce_on_plateau':
        return torch.optim.lr_scheduler.ReduceLROnPlateau(
            optimizer, 
            mode='min', 
            factor=config['training']['lr_factor'],
            patience=config['training']['lr_patience'],
            min_lr=1e-7,
            verbose=True
        )
    elif scheduler_type == 'cosine':
        return torch.optim.lr_scheduler.CosineAnnealingLR(
            optimizer,
            T_max=config['training']['epochs'],
            eta_min=1e-7
        )
    elif scheduler_type == 'step':
        return torch.optim.lr_scheduler.StepLR(
            optimizer,
            step_size=config['training']['lr_patience'],
            gamma=config['training']['lr_factor']
        )
    else:
        raise ValueError(f"不支持的调度器类型: {scheduler_type}")

def main():
    # 解析参数和配置
    args = parse_args()
    config = load_config(args.config)
    
    # 创建保存目录
    os.makedirs(config['checkpoints']['save_dir'], exist_ok=True)
    os.makedirs(config['visualization']['save_path'], exist_ok=True)
    
    # 设置设备
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f'使用设备: {device}')
    
    # 创建数据集
    train_transform = get_training_augmentation(config)
    val_transform = get_validation_augmentation(config)
    
    train_dataset = SegmentationDataset(
        img_dir=os.path.join(config['data']['train_path'], 'images'),
        mask_dir=os.path.join(config['data']['train_path'], 'masks'),
        transform=train_transform
    )
    
    val_dataset = SegmentationDataset(
        img_dir=os.path.join(config['data']['val_path'], 'images'),
        mask_dir=os.path.join(config['data']['val_path'], 'masks'),
        transform=val_transform
    )
    
    # 创建数据加载器
    train_loader = DataLoader(
        train_dataset,
        batch_size=config['data']['batch_size'],
        shuffle=True,
        num_workers=4,
        pin_memory=True,
        drop_last=True
    )
    
    val_loader = DataLoader(
        val_dataset,
        batch_size=config['data']['batch_size'],
        shuffle=False,
        num_workers=4,
        pin_memory=True
    )
    
    # 创建模型
    model = UNet(config).to(device)
    
    # 总参数数量
    total_params = sum(p.numel() for p in model.parameters())
    print(f'模型总参数: {total_params:,}')
    
    # 创建损失函数和优化器
    criterion = get_loss_function(config)
    optimizer = torch.optim.Adam(
        model.parameters(),
        lr=config['training']['lr'],
        weight_decay=config['training']['weight_decay']
    )
    
    # 学习率调度器
    scheduler = get_lr_scheduler(optimizer, config)
    
    # TensorBoard
    writer = SummaryWriter(log_dir='runs/experiment')
    
    # 初始化训练状态
    start_epoch = 0
    best_val_metric = 0 if config['checkpoints']['mode'] == 'max' else float('inf')
    early_stopping_counter = 0
    
    # 如果继续训练
    if args.resume:
        checkpoint = torch.load(args.resume)
        model.load_state_dict(checkpoint['model_state_dict'])
        optimizer.load_state_dict(checkpoint['optimizer_state_dict'])
        start_epoch = checkpoint['epoch'] + 1
        best_val_metric = checkpoint['best_val_metric']
        print(f'从 epoch {start_epoch} 恢复训练')
    
    # 训练循环
    for epoch in range(start_epoch, config['training']['epochs']):
        print(f'Epoch {epoch+1}/{config["training"]["epochs"]}')
        epoch_start_time = time.time()
        
        # 训练阶段
        model.train()
        train_loss = 0
        loss_components = {'bce': 0, 'dice': 0, 'focal': 0, 'tversky': 0}
        train_metrics = {metric: 0 for metric in config['evaluation']['metrics']}
        
        # 使用tqdm显示训练进度
        train_pbar = tqdm(train_loader, desc='训练')
        for batch_idx, (images, masks) in enumerate(train_pbar):
            images = images.to(device)
            masks = masks.to(device)
            
            # 前向传播
            outputs = model(images)
            
            # 计算损失
            if isinstance(criterion, nn.Module) and hasattr(criterion, 'forward'):
                # CombinedLoss返回多个损失
                if hasattr(criterion, 'bce'):
                    loss, components = criterion(outputs, masks)
                    # 更新损失组件
                    for k, v in components.items():
                        loss_components[k] += v
                else:
                    loss = criterion(outputs, masks)
            else:
                # 简单损失函数
                loss = criterion(outputs, masks)
            
            # 反向传播
            optimizer.zero_grad()
            loss.backward()
            
            # 梯度裁剪
            if config['training']['clip_grad_norm'] > 0:
                torch.nn.utils.clip_grad_norm_(
                    model.parameters(), 
                    max_norm=config['training']['clip_grad_norm']
                )
            
            optimizer.step()
            
            # 更新进度条
            train_loss += loss.item()
            avg_loss = train_loss / (batch_idx + 1)
            train_pbar.set_postfix({'loss': f'{avg_loss:.4f}'})
            
            # 计算训练指标
            with torch.no_grad():
                batch_metrics = calculate_metrics(
                    torch.sigmoid(outputs), 
                    masks, 
                    config['evaluation']['metrics']
                )
                for k, v in batch_metrics.items():
                    train_metrics[k] += v
                    
        # 计算训练平均值
        train_loss /= len(train_loader)
        for k in train_metrics:
            train_metrics[k] /= len(train_loader)
            
        # 记录到TensorBoard
        writer.add_scalar('Loss/train', train_loss, epoch)
        for k, v in train_metrics.items():
            writer.add_scalar(f'Metrics/{k}/train', v, epoch)
        for k, v in loss_components.items():
            if v > 0:  # 只记录使用的损失组件
                writer.add_scalar(f'Loss_components/{k}/train', v / len(train_loader), epoch)
        
        # 验证阶段
        model.eval()
        val_loss = 0
        val_metrics = {metric: 0 for metric in config['evaluation']['metrics']}
        
        with torch.no_grad():
            val_pbar = tqdm(val_loader, desc='验证')
            for batch_idx, (images, masks) in enumerate(val_pbar):
                images = images.to(device)
                masks = masks.to(device)
                
                # 前向传播
                outputs = model(images)
                
                # 计算损失
                if isinstance(criterion, nn.Module) and hasattr(criterion, 'forward'):
                    # CombinedLoss返回多个损失
                    if hasattr(criterion, 'bce'):
                        loss, _ = criterion(outputs, masks)
                    else:
                        loss = criterion(outputs, masks)
                else:
                    # 简单损失函数
                    loss = criterion(outputs, masks)
                
                val_loss += loss.item()
                avg_loss = val_loss / (batch_idx + 1)
                val_pbar.set_postfix({'loss': f'{avg_loss:.4f}'})
                
                # 计算验证指标
                batch_metrics = calculate_metrics(
                    torch.sigmoid(outputs), 
                    masks, 
                    config['evaluation']['metrics']
                )
                for k, v in batch_metrics.items():
                    val_metrics[k] += v
                
                # 保存部分预测结果用于可视化
                if batch_idx == 0 and epoch % 5 == 0:
                    visualize_predictions(
                        images.cpu(),
                        masks.cpu(),
                        torch.sigmoid(outputs).cpu(),
                        save_dir=config['visualization']['save_path'],
                        epoch=epoch,
                        num_examples=min(config['visualization']['num_examples'], images.size(0))
                    )
        
        # 计算验证平均值
        val_loss /= len(val_loader)
        for k in val_metrics:
            val_metrics[k] /= len(val_loader)
            
        # 记录到TensorBoard
        writer.add_scalar('Loss/val', val_loss, epoch)
        for k, v in val_metrics.items():
            writer.add_scalar(f'Metrics/{k}/val', v, epoch)
        
        # 更新学习率
        if config['training']['lr_scheduler'] == 'reduce_on_plateau':
            monitor_metric = val_loss
            if config['checkpoints']['monitor'] in val_metrics:
                monitor_metric = val_metrics[config['checkpoints']['monitor']]
                if config['checkpoints']['mode'] == 'max':
                    monitor_metric = -monitor_metric  # 对于最大化指标，转换为最小化问题
            scheduler.step(monitor_metric)
        else:
            scheduler.step()
        
        # 打印结果
        print(f'Epoch {epoch+1}/{config["training"]["epochs"]} 完成. 耗时: {time.time() - epoch_start_time:.2f}s')
        print(f'训练损失: {train_loss:.4f}')
        for k, v in train_metrics.items():
            print(f'训练 {k}: {v:.4f}')
        print(f'验证损失: {val_loss:.4f}')
        for k, v in val_metrics.items():
            print(f'验证 {k}: {v:.4f}')
        
        # 检查保存模型
        current_val_metric = val_metrics[config['checkpoints']['monitor']] if config['checkpoints']['monitor'] in val_metrics else val_loss
        
        # 根据模式确定是否保存
        is_best = False
        if config['checkpoints']['mode'] == 'max' and current_val_metric > best_val_metric:
            best_val_metric = current_val_metric
            is_best = True
            early_stopping_counter = 0
        elif config['checkpoints']['mode'] == 'min' and current_val_metric < best_val_metric:
            best_val_metric = current_val_metric
            is_best = True
            early_stopping_counter = 0
        else:
            early_stopping_counter += 1
        
        # 保存模型
        checkpoint = {
            'epoch': epoch,
            'model_state_dict': model.state_dict(),
            'optimizer_state_dict': optimizer.state_dict(),
            'best_val_metric': best_val_metric,
            'config': config
        }
        
        # 保存最新模型
        torch.save(checkpoint, os.path.join(config['checkpoints']['save_dir'], 'latest_model.pth'))
        
        # 如果是最佳模型，单独保存
        if is_best:
            torch.save(checkpoint, os.path.join(config['checkpoints']['save_dir'], 'best_model.pth'))
            print(f'保存最佳模型, {config["checkpoints"]["monitor"]} = {current_val_metric:.4f}')
        
        # 早停
        if early_stopping_counter >= config['training']['early_stopping']:
            print(f'{config["training"]["early_stopping"]} 个epoch没有改善，提前停止训练')
            break
    
    writer.close()
    print('训练完成!')

if __name__ == '__main__':
    main()
