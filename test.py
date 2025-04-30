# inference.py
import os
import argparse
import yaml
import cv2
import torch
import numpy as np
from tqdm import tqdm

from utils.model_factory import create_model

def parse_args():
    parser = argparse.ArgumentParser(description='U-Net推理脚本')
    parser.add_argument('--config', type=str, default='configs/config.yaml', help='配置文件路径')
    parser.add_argument('--checkpoint', type=str, required=True, help='模型检查点路径')
    parser.add_argument('--input', type=str, required=True, help='输入图像目录或单个图像')
    parser.add_argument('--output', type=str, default='results/predictions', help='输出目录')
    parser.add_argument('--threshold', type=float, default=0.5, help='分割阈值')
    parser.add_argument('--overlay', action='store_true', help='是否叠加显示预测结果')
    return parser.parse_args()

def preprocess_image(image, config):
    """预处理图像"""
    # 调整图像大小
    h, w = config['data']['img_size']
    channels = config['data']['channels']
    
    # 调整大小
    image = cv2.resize(image, (w, h))
    
    # 确保正确的通道数
    if channels == 1 and len(image.shape) == 3:
        image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        image = np.expand_dims(image, axis=-1)  # 添加通道维度
    elif channels == 1 and len(image.shape) == 2:
        image = np.expand_dims(image, axis=-1)  # 添加通道维度
    elif channels == 3 and len(image.shape) == 2:
        image = cv2.cvtColor(image, cv2.COLOR_GRAY2BGR)
    
    # 归一化
    if channels == 1:
        image = (image / 255.0 - 0.5) / 0.5
    else:
        mean = np.array([0.485, 0.456, 0.406])
        std = np.array([0.229, 0.224, 0.225])
        image = (image / 255.0 - mean) / std
    
    # 转换为PyTorch张量 [C,H,W]
    if channels == 1:
        image = torch.from_numpy(image.transpose(2, 0, 1)).float()
    else:
        image = torch.from_numpy(image.transpose(2, 0, 1)).float()
        
    return image.unsqueeze(0)  # 添加批次维度 [1,C,H,W]

def postprocess_prediction(prediction, original_height, original_width, threshold=0.5):
    """后处理预测结果"""
    pred_mask = (prediction > threshold).astype(np.uint8) * 255
    
    # 调整回原始大小
    if pred_mask.shape[:2] != (original_height, original_width):
        pred_mask = cv2.resize(
            pred_mask, 
            (original_width, original_height), 
            interpolation=cv2.INTER_NEAREST
        )
    
    return pred_mask

def create_overlay(image, mask, alpha=0.5, color=(0, 255, 0)):
    """创建叠加可视化"""
    # 确保图像是彩色的
    if len(image.shape) == 2:
        image = cv2.cvtColor(image, cv2.COLOR_GRAY2BGR)
    
    mask_rgb = np.zeros_like(image)
    mask_rgb[mask > 0] = color
    
    overlay = cv2.addWeighted(image, 1, mask_rgb, alpha, 0)
    return overlay

def main():
    # 解析参数
    args = parse_args()
    
    # 创建输出目录
    os.makedirs(args.output, exist_ok=True)
    
    # 加载配置
    with open(args.config, 'r') as f:
        config = yaml.safe_load(f)
    
    # 设置设备
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    
    # 加载模型
    model = create_model(config).to(device)
    checkpoint = torch.load(args.checkpoint, map_location=device)
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()
    
    # 确定输入是目录还是单个文件
    if os.path.isdir(args.input):
        # 处理目录中的所有图像
        image_files = [f for f in os.listdir(args.input) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.tif'))]
        image_paths = [os.path.join(args.input, f) for f in image_files]
    else:
        # 处理单个图像
        image_files = [os.path.basename(args.input)]
        image_paths = [args.input]
    
    # 逐个处理图像
    with torch.no_grad():
        for image_path, image_file in tqdm(zip(image_paths, image_files), desc='推理', total=len(image_paths)):
            # 读取图像
            if config['data']['channels'] == 1:
                # 单通道读取
                image = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
                original_image = image.copy()  # 保存原始图像用于可视化
                if image is None:  # 某些格式可能需要特殊处理
                    image = cv2.imread(image_path)
                    image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
                    original_image = image.copy()
            else:
                # RGB读取
                image = cv2.imread(image_path)
                original_image = image.copy()
                image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            
            original_height, original_width = image.shape[:2]
            
            # 预处理
            input_tensor = preprocess_image(image, config)
            input_tensor = input_tensor.to(device)
            
            # 推理 - 设置training=False
            output = model(input_tensor, training=False)
            
            # 如果模型未使用输出激活，则添加sigmoid
            if not config['model']['use_output_activation']:
                output = torch.sigmoid(output)
                
            pred = output.cpu().squeeze().numpy()
            
            # 后处理
            pred_mask = postprocess_prediction(
                pred, 
                original_height, 
                original_width, 
                threshold=args.threshold
            )
            
            # 保存结果
            base_name = os.path.splitext(image_file)[0]
            
            # 保存掩码
            mask_path = os.path.join(args.output, f'{base_name}_mask.png')
            cv2.imwrite(mask_path, pred_mask)
            
            # 如果需要叠加显示
            if args.overlay:
                overlay = create_overlay(original_image, pred_mask)
                overlay_path = os.path.join(args.output, f'{base_name}_overlay.png')
                cv2.imwrite(overlay_path, overlay)
            
    print(f'推理结果已保存到 {args.output}')

if __name__ == '__main__':
    main()
