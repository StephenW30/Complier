# utils/seed_utils.py
import os
import random
import numpy as np
import torch
import torch.backends.cudnn as cudnn

def set_seed(seed=42, deterministic=True):
    """
    设置随机种子以确保实验的可重现性
    
    Args:
        seed (int): 随机种子值
        deterministic (bool): 是否使用确定性算法
    """
    # Python随机种子
    random.seed(seed)
    
    # NumPy随机种子
    np.random.seed(seed)
    
    # PyTorch随机种子
    torch.manual_seed(seed)
    
    # CUDA随机种子
    if torch.cuda.is_available():
        torch.cuda.manual_seed(seed)
        torch.cuda.manual_seed_all(seed)  # 多GPU情况
    
    # 设置环境变量
    os.environ['PYTHONHASHSEED'] = str(seed)
    
    if deterministic:
        # 确保CUDA操作的确定性
        torch.backends.cudnn.deterministic = True
        torch.backends.cudnn.benchmark = False
        
        # 设置PyTorch的确定性算法
        torch.use_deterministic_algorithms(True, warn_only=True)
        
        # 设置环境变量以确保某些操作的确定性
        os.environ['CUBLAS_WORKSPACE_CONFIG'] = ':4096:8'
    else:
        # 允许CuDNN优化以提高性能
        torch.backends.cudnn.deterministic = False
        torch.backends.cudnn.benchmark = True

def worker_init_fn(worker_id):
    """
    DataLoader工作进程的随机种子初始化函数
    确保不同worker使用不同但可重现的随机种子
    """
    worker_seed = torch.initial_seed() % 2**32
    np.random.seed(worker_seed)
    random.seed(worker_seed)

def get_generator(seed=None):
    """
    获取PyTorch生成器，用于DataLoader
    """
    if seed is not None:
        generator = torch.Generator()
        generator.manual_seed(seed)
        return generator
    return None
