# utils/init_utils.py
import torch
import torch.nn as nn
import torch.nn.init as init
import math

class WeightInitializer:
    """Weight initialization class"""
    
    @staticmethod
    def he_normal_init(m):
        """He normal initialization (suitable for ReLU activation)"""
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
        """He uniform initialization"""
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
        """Xavier normal initialization (suitable for Sigmoid/Tanh activation)"""
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
        """Xavier uniform initialization"""
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
        """Orthogonal initialization"""
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
        Custom initialization for U-Net
        Combines multiple strategies for better training stability
        """
        if isinstance(m, nn.Conv2d):
            # Use He initialization for convolutional layers
            fan_in = m.weight.size(1) * m.weight.size(2) * m.weight.size(3)
            fan_out = m.weight.size(0) * m.weight.size(2) * m.weight.size(3)
            
            # Use improved He initialization
            std = math.sqrt(2.0 / fan_in)
            init.normal_(m.weight, 0, std)
            
            if m.bias is not None:
                init.constant_(m.bias, 0)
                
        elif isinstance(m, nn.ConvTranspose2d):
            # Special initialization for transposed convolution to avoid checkerboard artifacts
            fan_in = m.weight.size(1) * m.weight.size(2) * m.weight.size(3)
            std = math.sqrt(1.0 / fan_in)
            init.normal_(m.weight, 0, std)
            
            if m.bias is not None:
                init.constant_(m.bias, 0)
                
        elif isinstance(m, nn.BatchNorm2d):
            # Standard initialization for BatchNorm layers
            init.constant_(m.weight, 1)
            init.constant_(m.bias, 0)
            
        elif isinstance(m, nn.Linear):
            # Use Xavier initialization for linear layers
            init.xavier_normal_(m.weight)
            if m.bias is not None:
                init.constant_(m.bias, 0)
    
    @staticmethod
    def attention_specific_init(m):
        """
        Special initialization for attention mechanisms
        """
        if hasattr(m, '__class__') and 'Attention' in m.__class__.__name__:
            # Attention layer weights should be small to avoid over-focusing
            for param in m.parameters():
                if param.dim() > 1:
                    init.xavier_uniform_(param, gain=0.1)
                else:
                    init.constant_(param, 0)

def get_initializer(init_type='he_normal'):
    """
    Get initialization function
    
    Args:
        init_type (str): Initialization type
    
    Returns:
        function: Initialization function
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
        raise ValueError(f"Unsupported initialization type: {init_type}. Supported types: {list(initializers.keys())}")
    
    return initializers[init_type]

def initialize_model(model, init_type='he_normal', verbose=True):
    """
    Initialize weights for the entire model
    
    Args:
        model (nn.Module): Model to be initialized
        init_type (str): Initialization type
        verbose (bool): Whether to print initialization information
    
    Returns:
        nn.Module: Model after initialization
    """
    initializer = get_initializer(init_type)
    
    # Calculate weight statistics before and after initialization
    if verbose:
        print(f"Initializing model weights using {init_type}...")
        
        # Count model parameters
        total_params = sum(p.numel() for p in model.parameters())
        trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
        
        print(f"Total parameters: {total_params:,}")
        print(f"Trainable parameters: {trainable_params:,}")
    
    # Apply initialization
    model.apply(initializer)
    
    # Special initialization for attention layers
    model.apply(WeightInitializer.attention_specific_init)
    
    if verbose:
        # Print weight statistics after initialization
        print("Weight initialization completed!")
        
        # Check weight ranges of some key layers
        conv_weights = []
        bn_weights = []
        
        for name, param in model.named_parameters():
            if 'conv' in name.lower() and 'weight' in name:
                conv_weights.extend(param.data.flatten().tolist())
            elif 'bn' in name.lower() and 'weight' in name:
                bn_weights.extend(param.data.flatten().tolist())
        
        if conv_weights:
            conv_weights = torch.tensor(conv_weights)
            print(f"Conv layer weight range: [{conv_weights.min():.4f}, {conv_weights.max():.4f}], "
                  f"mean: {conv_weights.mean():.4f}, std: {conv_weights.std():.4f}")
        
        if bn_weights:
            bn_weights = torch.tensor(bn_weights)
            print(f"BatchNorm weight range: [{bn_weights.min():.4f}, {bn_weights.max():.4f}], "
                  f"mean: {bn_weights.mean():.4f}, std: {bn_weights.std():.4f}")
    
    return model
