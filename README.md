# Detailed Comparison of Mask R-CNN, Cascade R-CNN, and HTC

## Mask R-CNN (2017)

Mask R-CNN extends Faster R-CNN by adding a mask prediction branch for instance segmentation.

**Architecture Details:**
- **Base Network**: Uses a backbone (typically ResNet or FPN) for feature extraction
- **RPN (Region Proposal Network)**: Generates region proposals like in Faster R-CNN
- **RoIAlign**: Replaces RoIPool with a precise alignment operation that preserves spatial information through bilinear interpolation
- **Network Heads**: Three parallel branches for:
  * Classification: Predicts object class
  * Bounding Box Regression: Refines box coordinates
  * Mask Prediction: Outputs a binary mask for each RoI (class-specific or class-agnostic)

**Key Innovations:**
- Decouples mask and class prediction (predicts masks for each class independently)
- Pixel-to-pixel alignment via RoIAlign allows accurate mask generation
- End-to-end training with multi-task loss (classification, box regression, and mask segmentation)
- Versatile framework adaptable to various tasks beyond instance segmentation

**Limitations:**
- Single-stage refinement may not be optimal for high-quality detection
- Limited information exchange between detection and segmentation tasks

## Cascade R-CNN (2018)

Cascade R-CNN addresses the mismatch between IoU thresholds during training and inference through a multi-stage detection paradigm.

**Architecture Details:**
- **Cascaded Structure**: Series of detectors (typically 3 stages) trained with increasing IoU thresholds (e.g., 0.5, 0.6, 0.7)
- **Progressive Refinement**: Each stage refines the outputs from the previous stage
- **Shared Features**: All cascade stages share the same backbone features

**Key Innovations:**
- Resampling mechanism that progressively improves proposal distribution quality
- Specialized detectors at each stage optimized for specific IoU thresholds
- Quality-aware sample assignment strategy
- Improved detection performance at high IoU thresholds (high-quality detection)

**Limitations:**
- Focused primarily on detection without addressing instance segmentation
- No direct information flow between detection stages beyond proposal refinement
- Increased computation due to multiple detection stages

## HTC (Hybrid Task Cascade) (2019)

HTC integrates both Mask R-CNN and Cascade R-CNN concepts while introducing novel information flow mechanisms.

**Architecture Details:**
- **Cascade Structure**: Multiple stages of detection and segmentation refinement
- **Interleaved Branches**: Detection and segmentation tasks interact within and across stages
- **Semantic Segmentation**: Additional branch providing contextual information
- **Progressive Feature Fusion**: Intermediate results are merged with features from previous stages

**Key Innovations:**
- **Interleaved Execution**: Detection features inform mask prediction and vice versa within each stage
- **Information Flow**: Direct connections between mask branches across different stages
- **Contextual Awareness**: Integration of semantic segmentation to enhance feature representation
- **Mask Information Propagation**: Previous stage mask predictions directly contribute to current stage features

**Performance Improvements:**
- Significant gains on COCO benchmarks over both Mask R-CNN (+1.5% AP) and Cascade Mask R-CNN (+0.8% AP)
- Especially effective for challenging instances (small objects, occlusions)
- Better mask boundary delineation through progressive refinement

**Implementation Details:**
- Can leverage various backbones (ResNet, ResNeXt, HRNet)
- Typically uses FPN (Feature Pyramid Network) for multi-scale feature representation
- Modular design allows flexible configuration of stages and information flow

This architecture series represents an evolution in instance segmentation approaches, with each model building upon and addressing limitations of its predecessors.

# Detailed Comparison of FCN, DeepLabv3, U-Net, Mask2Former, and OneFormer

## FCN (Fully Convolutional Network, 2015)

FCN was the first end-to-end CNN architecture for semantic segmentation that could handle inputs of arbitrary size.

**Architecture Details:**
- **Fully Convolutional Design**: Replaces fully connected layers with convolutional layers
- **Skip Connections**: Combines deep, coarse semantic information with shallow, fine appearance information
- **Upsampling**: Uses transposed convolutions to restore spatial dimensions after downsampling
- **Multiple Output Scales**: Produces predictions at different resolutions (FCN-32s, FCN-16s, FCN-8s)

**Key Innovations:**
- Pioneered pixel-to-pixel prediction using CNNs
- Introduced skip connections to preserve spatial information
- Enabled end-to-end training for semantic segmentation
- Transformed classification networks (VGG, AlexNet) into segmentation architectures

**Limitations:**
- Limited receptive field size constrains contextual understanding
- Coarse segmentation outputs, especially at object boundaries
- No mechanism to separate object instances (semantic segmentation only)

## DeepLabv3 (2017)

DeepLabv3 significantly improved semantic segmentation by addressing the limited receptive field issue.

**Architecture Details:**
- **Atrous (Dilated) Convolutions**: Expands receptive field without increasing parameters
- **Atrous Spatial Pyramid Pooling (ASPP)**: Multi-scale feature extraction at different dilation rates
- **Encoder-Decoder Structure**: Added in DeepLabv3+ for sharper object boundaries
- **Depthwise Separable Convolutions**: Improves efficiency (in DeepLabv3+)

**Key Innovations:**
- Effective multi-scale processing via ASPP
- Controlled downsampling with atrous convolutions preserves resolution
- Explicit modeling of long-range dependencies
- Balance between semantic context and spatial precision

**Limitations:**
- Complex architecture with multiple components
- Computationally intensive due to dilated convolutions
- Primarily designed for semantic segmentation, not instance-aware

## U-Net (2015)

U-Net was developed for biomedical image segmentation with limited training data.

**Architecture Details:**
- **U-shaped Architecture**: Symmetric encoder-decoder with a contracting path and an expansive path
- **Skip Connections**: Direct connections between corresponding encoder and decoder layers
- **Feature Concatenation**: Combines low-level spatial details with high-level semantic information
- **Extensive Data Augmentation**: Designed to work with limited training samples

**Key Innovations:**
- Elegant, symmetric architecture preserving spatial information
- Effective feature propagation via skip connections
- Strong performance with limited training data
- Context propagation through successive layers

**Limitations:**
- Originally designed for binary segmentation in medical imaging
- Basic architecture lacks global context modeling
- No specific mechanism for instance segmentation

## Mask2Former (2022)

Mask2Former unified various segmentation tasks (semantic, instance, panoptic) under a single architecture.

**Architecture Details:**
- **Transformer-based Design**: Uses a transformer decoder with masked attention
- **Mask Classification Approach**: Frames all segmentation problems as mask classification
- **Per-pixel Embedding + Queries**: Combines CNN features with transformer queries
- **Masked Attention**: Focuses transformer queries on relevant image regions

**Key Innovations:**
- Universal architecture for all segmentation tasks
- Masked attention mechanism improves efficiency and performance
- Query-based object handling enables object-centric processing
- Integration of transformer capabilities with CNN feature extraction

**Limitations:**
- Computationally intensive due to transformer components
- Complex training process
- Requires careful hyperparameter tuning

## OneFormer (2022)

OneFormer advanced the unified segmentation paradigm by introducing task-conditioned joint training.

**Architecture Details:**
- **Task-conditional Architecture**: Single model conditioned on task tokens
- **Joint Training**: Simultaneously trained on semantic, instance, and panoptic segmentation
- **Text-Image Integration**: Incorporates text embeddings for task specification
- **Unified Pixel-Level Contrastive Learning**: Aligns features across different tasks

**Key Innovations:**
- True multi-task learning with task token conditioning
- Shared feature space across segmentation paradigms
- Explicit modeling of task relationships
- Efficient inference with a single forward pass for any task

**Performance Improvements:**
- State-of-the-art results on semantic, instance, and panoptic segmentation
- Better generalization across datasets
- More parameter-efficient than task-specific models
- Improved zero-shot capabilities through text conditioning

**Implementation Details:**
- Uses Swin Transformer or ConvNeXt as backbone
- Integrates a transformer decoder with masked attention
- Incorporates text embeddings from CLIP or similar models
- Employs task-specific losses during joint training

This architectural evolution shows the progression from basic semantic segmentation (FCN) to specialized architectures (DeepLabv3, U-Net) and finally to unified frameworks (Mask2Former, OneFormer) that can handle multiple segmentation paradigms within a single model.




# Model Comparison Table

## Model Comparison

| Model | Architecture Features | Typical Input Dimensions | Open-Source Code | Selection Reasons / Non-Selection Reasons |
|-------|----------------------|--------------------------|------------------|------------------------------------------|
| FCN | Fully convolutional network, adapted from classification networks, without fully connected layers; outputs pixel-level predictions through upsampling layers; introduces skip connections to combine deep semantic and shallow detail information. | No fixed input size (model can process inputs of any size; typical training crop size around 512×512) | Yes (original authors' Caffe code and various reimplementations) | Simple and efficient baseline model; fewer parameters, easy to train on small datasets. However, lacks complex multi-scale feature extraction modules, may have insufficient performance for low-contrast subtle defects, and has less precise edge reconstruction capability compared to subsequent models. |
| U-Net | U-shaped encoder-decoder architecture, symmetric skip connections fuse features at various scales; contracting path captures context, expanding path enables precise localization. Excels at capturing fine-grained information, supports end-to-end pixel prediction. | Typically trained with image patches (such as 256×256 or 512×512); flexible input and output sizes (original paper: 512×512 prediction in <1 second). | Yes (authors provide Caffe implementation; implementations available in most deep learning frameworks) | Performs excellently with limited annotated data, can be trained from few samples through strong data augmentation. Skip connections preserve defect details, suitable for detecting low-contrast PL star defects. As an industry-standard model, it's easy to use and optimize. However, if wafer noise is excessive, U-Net alone may be susceptible to false detections, requiring good training strategies. |
| U-Net Variants | Improved U-Net architectures, including: ① UNet++ (nested multi-level skip connections, dense connections to reduce the semantic gap between encoder and decoder); ② Attention U-Net (attention gates added at skip connections to highlight target region features and suppress background interference); ③ U-Net with pretrained backbones (such as ResNet, DenseNet encoders to enhance feature extraction capabilities). These variants strengthen multi-scale feature fusion or attention mechanisms, improving segmentation accuracy. | Similar to U-Net (commonly 256×256 or 512×512 for training); need to appropriately meet the model's higher memory and computational requirements. | Yes (UNet++ authors provide code; Attention U-Net and others have open-source implementations) | When basic U-Net cannot fully detect low-contrast details in PL star defect detection, variants can be considered. UNet++ and others consistently improve segmentation performance across different datasets (especially for targets of different sizes), potentially more accurately depicting the fine ray structure of small defects; attention mechanisms help highlight defect signals from noise. However, these variants are more complex with more parameters, possibly requiring more data or regularization to prevent overfitting. With extremely limited real data, the balance between model complexity and data scale must be carefully considered. |
| DeepLabv3 | Based on convolutional backbones (commonly using ImageNet pretrained models like ResNet/Xception), introduces atrous convolutions to expand global receptive field; employs Atrous Spatial Pyramid Pooling (ASPP) module to extract multi-scale contextual features; removes CRF post-processing, outputs semantic segmentation results end-to-end. Can map features back to original image dimensions via 1×1 convolutions. | Flexible input sizes (fully convolutional structure); typical training crop sizes such as 513×513 (Pascal VOC) or 769×769 (Cityscapes) to cover large-scale context. | Yes (official TensorFlow implementation; widespread PyTorch third-party implementations) | For PL defects with radial patterns, DeepLabv3's ASPP provides rich multi-scale context, helpful for capturing defect features from small clusters to radial extensions. Pretrained backbone networks enhance feature generalization, beneficial for segmentation performance when real samples are limited. In practical applications, DeepLabv3 is considered a high-precision general segmentation model. The disadvantage is downsampled output features, potentially slightly blurring edge details (compared to U-Net's direct detail connections); if necessary, a simple decoder (DeepLabv3+) can improve small defect edge localization. Overall, it's a strong candidate for PL star detection tasks. |
| Mask2Former | New Transformer segmentation architecture, using mask attention Transformer decoder: extracts local features by limiting cross-attention to predicted mask regions. Represents different masks with a set of learnable queries, achieving unified processing of semantic, instance, and panoptic segmentation. Combines multi-scale features (typically using CNN or Swin Transformer backbone) to gradually refine output masks. | Variable input sizes (detection framework style training, commonly using high-resolution images with long edges of 800-1024); model has high memory requirements, requiring multi-GPU training (4×A100 can satisfy most setups). | Yes (Facebook Research provides Detectron2 code) | Mask2Former achieves current state-of-the-art accuracy on multiple segmentation benchmarks, for example, reaching 57.7% mIoU on ADE20K semantic segmentation, significantly surpassing previous architectures. For PL star defects, this global-local combined Transformer shows promise for detecting weak patterns: global attention focuses on six-directional radial morphology, while local masks finely delineate defect regions, improving signal-to-noise separation for low-contrast targets. However, its complex structure and large parameter count require substantial data support; with limited real data, extensive use of simulated data for training and prevention of overfitting is necessary. Additionally, training and inference costs are high, requiring evaluation of cost-effectiveness for actual deployment. Suitable for research pursuing maximum accuracy with abundant resources. |
| SegFormer | Pure Transformer segmentation model, comprising hierarchical vision Transformer encoder and lightweight all-MLP decoder head. The encoder (MiT) extracts multi-scale features through layer-by-layer downsampling, requiring no position encoding (consistent performance across different resolutions); decoder uses MLP to fuse features from each layer, achieving fusion of local and global information. Simple and efficient design, with parameter count adjustable according to model size (B0-B5). | Supports arbitrary input sizes (through padding to multiples of patch size); common training sizes include 512×512 or 1024×1024, balancing detail and global perspective. | Yes (authors provide code; integrated into libraries such as NVIDIA/millimeter segmentation) | SegFormer offers an excellent balance of accuracy and efficiency. For PL star detection, the pretrained Transformer encoder provides powerful feature representation capabilities, enabling transfer learning to defect patterns even with limited data; multi-scale feature fusion benefits simultaneous capture of small defect clusters and overall star structure. Compared to Mask2Former, SegFormer is structurally simpler and faster in inference, suitable for achieving high performance with limited data and computational resources. Research shows this model achieves leading accuracy across multiple datasets, with model size far smaller than comparable methods. Overall, SegFormer is highly suitable as the main model for this task, ensuring performance while reducing training difficulty. |

## Analysis of Each Model's Advantages and Disadvantages in PL Star Defect Detection

### FCN
FCN is the earliest proposed fully convolutional semantic segmentation model, with advantages in simple architecture and fast inference. It performs pixel-level classification directly through convolution and upsampling, and improves accuracy by fusing shallow and deep features. For low-contrast defects like PL stars, FCN can serve as a baseline model to verify feasibility, but due to the lack of more advanced multi-scale context modules, it may struggle to capture weak radial details, resulting in relatively limited performance.

### U-Net
U-Net adopts a symmetric encoder-decoder architecture, preserving high-resolution details through skip connections. Its strength lies in achieving good results with few training samples when combined with data augmentation. For PL star defects, U-Net can combine local details and global context to locate defect rays that are difficult to detect by the naked eye, maintaining strong robustness even against high-noise backgrounds. Overall, U-Net serves as a powerful baseline for this type of defect detection, easy to train and tune. However, if defect patterns are very small or background noise is complex, U-Net alone may not completely eliminate false detections and requires further improvements.

### U-Net Variants
Many U-Net variants address the above issues with improvements:

**UNet++** enhances different scale feature fusion through nested dense skip connections and multi-depth subnetworks. It typically achieves higher accuracy than the basic U-Net when more precise segmentation is required.

**Attention U-Net** introduces attention gating in the decoding stage, weighting and filtering skip connection features to highlight PL star defect areas and suppress background noise interference. This is particularly beneficial for low-contrast targets.

Other variants (such as ResU-Net with pretrained backbones, R2U-Net, etc.) enhance feature extraction depth or introduce recurrent and Transformer modules to further improve recognition capabilities.

In PL star detection, if the basic U-Net cannot fully detect defect morphology, these variants provide pathways to improve accuracy. For example, when defects present as fine radiating textures, UNet++'s multi-scale fusion and Attention U-Net's feature filtering may more accurately recover these structures. However, complex models are also more prone to overfitting, especially with very limited real annotated data. Therefore, when adopting U-Net variants, ensure sufficient training data (or utilize large amounts of simulated data) and apply regularization to prevent the model from memorizing noise patterns.

### DeepLabv3
DeepLabv3 represents a high-level semantic segmentation method based on convolutional neural networks. It uses atrous convolutions and ASPP modules to obtain multi-scale contextual information from images. For PL star defects, DeepLabv3 has several significant advantages:

**Multi-scale detection**: ASPP provides convolutions at different sampling rates, helping to simultaneously identify small defect clusters and longer radiating streaks.

**Pretrained features**: Using pretrained backbones like ResNet means the model can leverage pre-learned features even with limited data, improving generalization ability for low-contrast patterns.

**End-to-end optimization**: Without complicated post-processing, it directly outputs segmentation results, facilitating unified optimization of the training pipeline.

Experiments prove that DeepLabv3 performs well in both speed and accuracy. For wafer high-noise backgrounds, DeepLabv3's context awareness can mitigate false detections: the model can determine whether certain bright spots form meaningful "star" shapes based on surrounding areas. Its potential weakness is that output feature maps undergo multiple downsampling, potentially resulting in less refined edges. But this can be improved through DeepLabv3+ by incorporating low-level feature fusion. If computational resources and data permit, DeepLabv3 is worth trying, potentially achieving robust performance in this task.

### Mask2Former
Mask2Former is the latest Transformer architecture segmentation model, excelling in complex scenes. Its core idea is to combine query sequences with image features through mask-constrained cross-attention mechanisms, directly producing segmentation masks. For PL star defects, Mask2Former's appeal lies in:

**Global modeling capability**: Transformers can attend to global image information, potentially capturing the overall six-way radiation pattern that is difficult to discern by eye.

**Local detail delineation**: Mask attention ensures fine-grained feature extraction for each candidate defect region, not missing small defect clusters.

**High accuracy**: This model surpasses the accuracy of previous specialized methods in multiple segmentation tasks. If properly trained, it promises to provide minimal false negative and false positive rates.

However, Mask2Former's disadvantages must also be weighed: the model is very large, requiring substantial data and computational power for training. Even with 4×A100 GPUs, parameter tuning and training still consume considerable time. Furthermore, PL star defect detection is single-class semantic segmentation, not as complex as instance segmentation tasks, making such a heavy model potentially cost-ineffective. Mask2Former is a reasonable choice only when pursuing ultimate performance and having ample simulated data to augment the training set. With abundant resources, it can be a research candidate, but its inference speed and deployment difficulty need consideration in industrial applications.

### SegFormer
SegFormer is known for its more concise and efficient Transformer design, without complex decoders, instead using MLP for multi-layer feature fusion. For this task, SegFormer may be the most practical choice for several reasons:

**Pretrained advantage**: SegFormer's encoder is pretrained on data like ImageNet, providing good transfer capability for limited PL defect data. This helps the model recognize low-contrast patterns without learning basic features from scratch.

**Multi-scale features**: The hierarchical Transformer encoder provides feature maps at different scales, considering both local details and global structures, effectively recognizing both small defect clusters and longer star ray structures.

**Efficiency**: Compared to Mask2Former, SegFormer has a much smaller parameter count, is computation-friendly, and can train and infer faster. In a 4×A100 environment, it's even possible to try larger input resolutions or more thorough hyperparameter tuning, further improving segmentation results.

SegFormer has achieved comparable or even better results than more complex models on high-resolution segmentation benchmarks like Cityscapes. Therefore, in PL star defect detection, it promises to achieve near-top performance with lower development costs. Unless the unified instance handling functionality of Mask2Former is needed, SegFormer provides the best balance of performance, efficiency, and implementation difficulty.

## Model Applicability Recommendations

Based on the above comparisons, we recommend adopting models in tiers according to needs and resources for PL star defect detection tasks:

First, U-Net can be selected as a benchmark model for initial attempts. Its efficient use of small data volumes and grasp of details can quickly validate task difficulty. If U-Net cannot meet requirements in basic performance, more complex methods can be considered.

For current task challenges (low contrast, small sample, high noise), introducing pretrained segmentation models is crucial. Based on this, DeepLabv3 or SegFormer are ideal next choices. Both utilize encoders pretrained on large datasets: DeepLabv3 extracts reliable features through backbones like ResNet, while SegFormer provides global information through Transformer encoders. These two models are likely to achieve higher accuracy than U-Net trained purely from scratch.

SegFormer is especially recommended: it maintains high accuracy while being lightweight and less difficult to train, suitable for scenarios with limited real data combined with abundant simulated data. With 4×A100 hardware, SegFormer can leverage larger input sizes and batch sizes to enhance performance, making it a strong solution for engineering implementation.

U-Net variants (such as Attention U-Net or UNet++) can serve as enhancement means for the basic U-Net. If improved results are desired without significantly increasing complexity, these variants are worth trying. However, control of model complexity is necessary to avoid overfitting.

Mask2Former is suitable for research experiments requiring extremely high accuracy. With sufficient high-quality training data, it may detect the weakest defect signals. However, in practical projects, its training and inference costs are high, and it may be best used as an "upper limit" solution for comparison with lighter models.

In conclusion, the complexity of models should be balanced against data/computational power conditions in PL star defect detection. It is recommended to start with classic and mature architectures (such as U-Net series, DeepLabv3), achieve reliable baselines using pretraining and data augmentation, then attempt to introduce Transformer architectures (such as SegFormer) to further improve performance. If resources are abundant and maximum accuracy is needed, cutting-edge models like Mask2Former can be considered. Through progressive trials and comparisons, the above models can likely find the optimal solution that both accurately detects PL star defects and is efficiently feasible.


Here's your completed table in a format consistent with your existing entries:

| Model           | Architecture highlights                                                                                                                                                           | Input size                                                | Open-source code | Reason of choice (not)                                                                                                                                                             |
|-----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------|------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **FCN**         | Fully convolutional network adapted from classification networks without fully connected layers; outputs pixel-level predictions through upsampling layers;                       | No fixed input size                                       | Yes              | Simple and efficient baseline model, fewer parameters, easy to train on small datasets. However, lacks complex multi-scale feature extraction modules, may have insufficient performance.|
| **U-Net**       | U-shaped encoder-decoder architecture, symmetric skip connections fuse features at various scales; Downsampling path captures context, Upsampling path enables precise localization;| No fixed input size (typically at 256x256/512x512)        | Yes              | Performs excellently with limited annotated data, can be trained from few samples. Industry-standard, easy to use and optimize. However, if wafer noise is excessive, may cause false detections. |
| **Attention U-Net** | Adds attention gates to U-Net skip connections to highlight foreground features; improves feature selection by focusing on relevant defect regions, suppressing noisy backgrounds.  | Flexible input sizes (commonly 512x512 or patch-based)     | Yes              | Strongly recommended for tasks with noisy backgrounds; enhances defect edge clarity significantly. Relatively easy to train, ideal when thin defects are hard to distinguish from background noise.|
| **HR U-Net**    | Maintains high-resolution feature maps throughout; reduces downsampling operations to preserve fine details; designed specifically for preserving thin, detailed structures.      | Typically large input sizes or patches (1024x1024 recommended) | Yes              | Highly recommended for extremely thin (2-3px) defects. Ensures superior edge definition and fine detail retention. However, increased computational cost and GPU memory requirements.|
| **DeepLab V3**  | Based on convolutional backbones (using ImageNet pretrained models like ResNet); Introduces Atrous convolutions to expand global receptive field; Employs ASPP module for multi-scale contextual features. | Flexible input sizes (fully convolutional structure)      | Yes              | Recommended due to multi-scale feature extraction capability, good general performance, and robustness. Suitable for diverse defect scales, but might slightly blur very thin defects.|
| **Mask2Former** | Transformer-based, mask attention decoding; learns semantic, instance, and panoptic segmentation jointly; outstanding global-local feature fusion.                                 | Flexible input sizes (arbitrary, typically patch-based)   | Yes              | Not chosen due to high training complexity, longer training time, and significant computational demands. Best suited for scenarios with sufficient training data and compute resources.|
| **SegFormer**   | Transformer-based encoder with lightweight MLP decoder; integrates multi-scale transformer features effectively; excellent balance between performance and efficiency.            | Flexible input sizes (arbitrary input through padding)    | Yes              | Not chosen due to limited timeframe and considerable training consumption. Ideal when high efficiency with good accuracy is required but less suited for extremely thin defect detection.|

This format is consistent with your original entries, clearly highlighting each model's architecture and suitability for your PL star segmentation task.



Tasks Completed:

MATLAB Code Refactoring for PL Star Generation

Transformed the original code from single wafer processing to batch wafer simulation capability
Implemented automatic adjustment of PL star position and dimensions based on discussions with apps team
Identified several bugs that need future fixes


Literature Review on Shape Prior Integration in Neural Networks

Studied papers focused on incorporating shape priors into neural networks for segmentation tasks
Analyzed the SPM (Shape Prior Module) approach and its potential application to our work


Camouflage Object Detection Research

Analyzed relevant papers and datasets for camouflage object detection
Identified several SOTA models with features similar to our task requirements
Evaluated potential applicability to our specific detection challenges
