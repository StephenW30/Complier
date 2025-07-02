# utils/transforms.py
import albumentations as A
from albumentations.pytorch import ToTensorV2
import cv2

def get_training_augmentation(config):
    """
    Get training data augmentation for single-channel wafer data
    
    Args:
        config: Configuration dictionary containing augmentation parameters
    
    Returns:
        A.Compose: Combined data augmentation transforms
    """
    
    # Basic geometric transforms - maintain image size
    transforms = []
    
    # 1. Flip transforms - add mirror data
    # Effect: Make model insensitive to defect position (left/right, up/down)
    if config['augmentation']['use_flip']:
        transforms.append(A.HorizontalFlip(p=config['augmentation']['horizontal_flip_p']))
        transforms.append(A.VerticalFlip(p=config['augmentation']['vertical_flip_p']))
    
    # 2. Contrast and brightness enhancement - core augmentation for wafer defect detection
    # Effect: Simulate different lighting conditions, enhance contrast between defects and background
    if config['augmentation']['use_contrast']:
        transforms.append(
            A.RandomBrightnessContrast(
                brightness_limit=config['augmentation']['brightness_range'],
                contrast_limit=config['augmentation']['contrast_range'], 
                p=config['augmentation']['contrast_p']
            )
        )
    
    # 3. Gamma correction - adjust overall brightness distribution
    # Effect: Simulate different exposure conditions, adapt to different wafer image brightness
    if config['augmentation']['use_gamma']:
        transforms.append(
            A.RandomGamma(
                gamma_limit=config['augmentation']['gamma_range'],
                p=config['augmentation']['gamma_p']
            )
        )
    
    # 4. CLAHE (Contrast Limited Adaptive Histogram Equalization) - important for single-channel images
    # Effect: Enhance local contrast, highlight subtle defects, especially suitable for wafer defect detection
    if config['augmentation']['use_clahe']:
        transforms.append(
            A.CLAHE(
                clip_limit=config['augmentation']['clahe_clip_limit'],
                tile_grid_size=config['augmentation']['clahe_tile_size'],
                p=config['augmentation']['clahe_p']
            )
        )
    
    # 5. Elastic deformation - simulate subtle deformation during wafer manufacturing
    # Effect: Add geometric diversity while maintaining basic defect shape characteristics
    if config['augmentation']['use_elastic']:
        transforms.append(
            A.OneOf([
                A.ElasticTransform(
                    alpha=config['augmentation']['elastic_alpha'],
                    sigma=config['augmentation']['elastic_sigma'],
                    alpha_affine=config['augmentation']['elastic_alpha_affine'],
                    border_mode=cv2.BORDER_REFLECT_101,
                    p=0.5
                ),
                A.GridDistortion(
                    num_steps=5,
                    distort_limit=0.1,
                    border_mode=cv2.BORDER_REFLECT_101,
                    p=0.5
                ),
                A.OpticalDistortion(
                    distort_limit=config['augmentation']['optical_distort_limit'],
                    shift_limit=config['augmentation']['optical_shift_limit'],
                    border_mode=cv2.BORDER_REFLECT_101,
                    p=0.5
                ),
            ], p=config['augmentation']['elastic_p'])
        )
    
    # 6. Noise and blur - simulate real acquisition environment
    # Effect: Improve model robustness to noise, simulate different image qualities
    if config['augmentation']['use_noise']:
        transforms.append(
            A.OneOf([
                # Gaussian noise - simulate sensor noise
                A.GaussNoise(
                    var_limit=config['augmentation']['gauss_noise_var'],
                    p=0.5
                ),
                # Gaussian blur - simulate slight defocus
                A.GaussianBlur(
                    blur_limit=config['augmentation']['gaussian_blur_limit'],
                    p=0.5
                ),
                # Motion blur - simulate slight vibration during acquisition
                A.MotionBlur(
                    blur_limit=config['augmentation']['motion_blur_limit'],
                    p=0.5
                ),
                # Median blur - reduce salt-and-pepper noise
                A.MedianBlur(
                    blur_limit=config['augmentation']['median_blur_limit'],
                    p=0.5
                ),
            ], p=config['augmentation']['noise_p'])
        )
    
    # 7. Sharpening - enhance edge details
    # Effect: Highlight defect edges, improve detail recognition capability
    if config['augmentation']['use_sharpen']:
        transforms.append(
            A.Sharpen(
                alpha=config['augmentation']['sharpen_alpha'],
                lightness=config['augmentation']['sharpen_lightness'],
                p=config['augmentation']['sharpen_p']
            )
        )
    
    # 8. Pixel-level transforms
    # Effect: Add pixel-level randomness, improve model generalization
    if config['augmentation']['use_pixel_transforms']:
        transforms.append(
            A.OneOf([
                # Random grid occlusion - simulate partially occluded regions
                A.CoarseDropout(
                    max_holes=config['augmentation']['coarse_dropout_holes'],
                    max_height=config['augmentation']['coarse_dropout_size'],
                    max_width=config['augmentation']['coarse_dropout_size'],
                    fill_value=0,
                    p=0.5
                ),
                # Random erasing - randomly occlude small regions
                A.Cutout(
                    num_holes=config['augmentation']['cutout_holes'],
                    max_h_size=config['augmentation']['cutout_size'],
                    max_w_size=config['augmentation']['cutout_size'],
                    fill_value=0,
                    p=0.5
                ),
            ], p=config['augmentation']['pixel_transforms_p'])
        )
    
    # 9. Normalization - unify data distribution
    # Effect: Standardize pixel values to [-1,1] or [0,1] range, stabilize training process
    if config['augmentation']['use_normalize']:
        transforms.append(
            A.Normalize(
                mean=config['augmentation']['normalize_mean'],
                std=config['augmentation']['normalize_std']
            )
        )
    
    return A.Compose(transforms)


def get_validation_augmentation(config):
    """
    Get validation data augmentation - only essential preprocessing
    
    Args:
        config: Configuration dictionary
    
    Returns:
        A.Compose: Validation transform composition
    """
    transforms = []
    
    # Only normalization for validation to maintain data consistency
    if config['augmentation']['use_normalize']:
        transforms.append(
            A.Normalize(
                mean=config['augmentation']['normalize_mean'],
                std=config['augmentation']['normalize_std']
            )
        )
    
    return A.Compose(transforms)


def get_test_augmentation(config):
    """
    Get test data augmentation - same as validation, no randomness
    
    Args:
        config: Configuration dictionary
    
    Returns:
        A.Compose: Test transform composition
    """
    return get_validation_augmentation(config)


# Default configuration examples
def get_default_wafer_config():
    """
    Get default configuration for wafer data augmentation
    
    Returns:
        dict: Default configuration dictionary
    """
    return {
        'augmentation': {
            # Basic settings
            'use_normalize': True,
            'normalize_mean': 0.5,    # Single-channel normalization mean
            'normalize_std': 0.5,     # Single-channel normalization std
            
            # Flip transforms
            'use_flip': True,
            'horizontal_flip_p': 0.5, # Horizontal flip probability
            'vertical_flip_p': 0.3,   # Vertical flip probability
            
            # Contrast and brightness
            'use_contrast': True,
            'brightness_range': 0.2,  # Brightness change range
            'contrast_range': 0.25,   # Contrast change range
            'contrast_p': 0.7,        # Contrast transform probability
            
            # Gamma correction
            'use_gamma': True,
            'gamma_range': (80, 120), # Gamma value range
            'gamma_p': 0.5,           # Gamma correction probability
            
            # CLAHE enhancement
            'use_clahe': True,
            'clahe_clip_limit': 2.0,  # CLAHE clipping limit
            'clahe_tile_size': (8, 8),# CLAHE grid size
            'clahe_p': 0.4,           # CLAHE probability
            
            # Elastic deformation
            'use_elastic': True,
            'elastic_alpha': 50,      # Elastic deformation strength
            'elastic_sigma': 5,       # Elastic deformation smoothness
            'elastic_alpha_affine': 5,# Affine transform strength
            'optical_distort_limit': 0.1,  # Optical distortion limit
            'optical_shift_limit': 0.1,    # Optical shift limit
            'elastic_p': 0.3,         # Elastic deformation probability
            
            # Noise and blur
            'use_noise': True,
            'gauss_noise_var': (10, 30),    # Gaussian noise variance range
            'gaussian_blur_limit': (3, 5),  # Gaussian blur kernel size
            'motion_blur_limit': 3,         # Motion blur limit
            'median_blur_limit': 3,         # Median blur limit
            'noise_p': 0.2,           # Noise probability
            
            # Sharpening
            'use_sharpen': True,
            'sharpen_alpha': (0.1, 0.3),    # Sharpening strength
            'sharpen_lightness': (0.8, 1.2), # Sharpening brightness adjustment
            'sharpen_p': 0.3,         # Sharpening probability
            
            # Pixel-level transforms
            'use_pixel_transforms': True,
            'coarse_dropout_holes': 3,      # Coarse dropout hole count
            'coarse_dropout_size': 8,       # Coarse dropout size
            'cutout_holes': 1,              # Cutout hole count
            'cutout_size': 16,              # Cutout size
            'pixel_transforms_p': 0.15,     # Pixel transform probability
        }
    }


# Light configuration - suitable for high-quality data
def get_light_wafer_config():
    """Light augmentation configuration"""
    config = get_default_wafer_config()
    config['augmentation'].update({
        'contrast_range': 0.15,
        'brightness_range': 0.1,
        'elastic_p': 0.1,
        'noise_p': 0.1,
        'pixel_transforms_p': 0.05,
    })
    return config


# Heavy augmentation configuration - suitable for data scarcity
def get_heavy_wafer_config():
    """Heavy augmentation configuration"""
    config = get_default_wafer_config()
    config['augmentation'].update({
        'contrast_range': 0.35,
        'brightness_range': 0.3,
        'contrast_p': 0.8,
        'elastic_p': 0.5,
        'noise_p': 0.4,
        'pixel_transforms_p': 0.25,
    })
    return config


# Usage example
if __name__ == "__main__":
    # Get different intensity configurations
    light_config = get_light_wafer_config()
    default_config = get_default_wafer_config()
    heavy_config = get_heavy_wafer_config()
    
    # Create transforms
    train_transform = get_training_augmentation(default_config)
    val_transform = get_validation_augmentation(default_config)
    
    print("Training transform created successfully")
    print("Validation transform created successfully")
    
    # Print configuration info
    print(f"\nDefault config includes {len([k for k, v in default_config['augmentation'].items() if k.startswith('use_') and v])} augmentation types")
