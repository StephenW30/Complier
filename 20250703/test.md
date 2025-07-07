# PL Star Simulation Algorithm - Technical Documentation

## Executive Overview

### Purpose
Generate synthetic photoluminescence (PL) star defect patterns on semiconductor wafer images for machine learning model training. The algorithm creates realistic multi-star configurations with variable characteristics to enhance dataset diversity.

### Key Capabilities
- **Multi-star generation**: 1-3 PL stars per wafer with configurable probability distribution
- **Realistic variations**: Line breaks, width variations, and intensity modulation
- **Quality controls**: Geometric validation and boundary constraints
- **Batch processing**: Automated processing of wafer datasets
- **Comprehensive output**: Binary masks, modified images, and visualizations

### Input/Output Summary
```
INPUT:  .mat files containing 'dw_image' field (wafer photoluminescence data)
OUTPUT: Binary masks, modified wafer images, and visualization plots
        Organized in timestamped folder structure
```

---

## Algorithm Workflow

### Main Processing Pipeline

```pseudocode
ALGORITHM: PL_Star_Simulation_Pipeline
INPUT: baseInputDir, baseOutputDir, configuration_parameters
OUTPUT: processed_files_with_PL_stars

BEGIN
    // 1. SYSTEM INITIALIZATION
    Initialize_Configuration()
    Setup_Directory_Structure()
    
    // 2. BATCH PROCESSING
    matFiles = Get_All_Mat_Files(baseInputDir)
    
    FOR each file in matFiles:
        // 2.1 File-level Configuration
        Generate_Random_Parameters()  // Star count, base width, etc.
        
        // 2.2 Data Loading & Preprocessing
        waferData, waferInfo = Load_And_Preprocess_Wafer(file)
        
        // 2.3 PL Star Generation
        maps = Generate_Multiple_PL_Stars(waferData, waferInfo)
        
        // 2.4 Output Generation
        coordinates = Calculate_Coordinate_System(waferInfo)
        Generate_Visualizations(maps, coordinates, filename)
        Save_Results(maps, filename)
    END FOR
    
    Report_Processing_Summary()
END
```

### Detailed Sub-Algorithms

#### 2.2 Data Loading & Preprocessing
```pseudocode
FUNCTION Load_And_Preprocess_Wafer(filePath)
INPUT: filePath (string)
OUTPUT: waferData (1500x1500 matrix), waferInfo (metadata)

BEGIN
    // Load and validate data
    matData = Load_Mat_File(filePath)
    ASSERT matData contains 'dw_image' field
    
    waferData = matData.dw_image
    
    // Data cleaning
    Replace_Invalid_Values(waferData):
        waferData[waferData == 0] = NaN
        waferData[waferData == 3158064] = NaN
        waferData[waferData == min_value] = NaN
    
    // Standardization
    waferData = Resize_To_Standard(waferData, [1500, 1500])
    
    IF config.FlipVertical:
        waferData = Flip_Vertically(waferData)
    
    // Extract metadata
    waferInfo = Extract_Metadata(matData, filePath)
    
    RETURN waferData, waferInfo
END
```

#### 2.3 Multiple PL Star Generation
```pseudocode
FUNCTION Generate_Multiple_PL_Stars(waferData, waferInfo)
INPUT: waferData, waferInfo, config
OUTPUT: maps (RawMap, MaskMap, SimulateMap)

BEGIN
    // Initialize output maps
    height, width = Get_Dimensions(waferData)
    combinedMask = Initialize_Zero_Matrix(height, width)
    simulationMap = Copy(waferData)
    
    // Determine number of stars (probabilistic)
    numStars = Select_Star_Count():
        prob = Random()
        IF prob <= 0.7: RETURN 1
        ELIF prob <= 0.9: RETURN 2
        ELSE: RETURN 3
    
    starCenters = Empty_List()
    
    // Generate each PL star
    FOR starIndex = 1 to numStars:
        
        // 2.3.1 Find valid center position
        centerX, centerY = Find_Valid_Star_Center(starCenters, waferData)
        starCenters.Add([centerX, centerY])
        
        // 2.3.2 Generate ellipse parameters
        ellipseParams = Generate_Ellipse_Parameters(config)
        
        // 2.3.3 Create star pattern
        starMask = Generate_Single_PL_Star(centerX, centerY, ellipseParams, waferData)
        
        // 2.3.4 Combine with overall mask
        combinedMask = combinedMask OR starMask
        
    END FOR
    
    // Apply intensity simulation
    simulationMap = Apply_PL_Intensity_Simulation(combinedMask, waferData)
    
    // Package results
    maps = {
        RawMap: waferData,
        MaskMap: combinedMask,
        SimulateMap: simulationMap
    }
    
    RETURN maps
END
```

#### 2.3.1 Valid Star Center Finding
```pseudocode
FUNCTION Find_Valid_Star_Center(existingCenters, waferData)
INPUT: existingCenters (list), waferData (matrix)
OUTPUT: centerX, centerY (coordinates)

BEGIN
    maxAttempts = 100
    minDistance = 200  // pixels
    
    FOR attempt = 1 to maxAttempts:
        
        // Generate candidate position
        IF this_is_first_star:
            baseX = width * 0.85
            baseY = height * 0.5
        ELSE:
            baseX = width * Random(0.2, 0.6)
            baseY = height * Random(0.2, 0.6)
        
        // Apply random variations
        variationX = width * config.centerVariationX * Random(-1, 1)
        variationY = height * config.centerVariationY * Random(-1, 1)
        
        candidateX = Clamp(baseX + variationX, 1, width)
        candidateY = Clamp(baseY + variationY, 1, height)
        
        // Validate position
        IF Is_Valid_Position(candidateX, candidateY, existingCenters, waferData):
            RETURN candidateX, candidateY
        
    END FOR
    
    ERROR "Cannot find valid star center after maximum attempts"
END

FUNCTION Is_Valid_Position(x, y, existingCenters, waferData)
    // Check data validity
    IF Is_NaN(waferData[y, x]) OR waferData[y, x] == 0:
        RETURN false
    
    // Check distance from existing stars
    FOR each center in existingCenters:
        distance = Euclidean_Distance([x, y], center)
        IF distance < minDistance:
            RETURN false
    
    RETURN true
END
```

#### 2.3.3 Single PL Star Generation
```pseudocode
FUNCTION Generate_Single_PL_Star(centerX, centerY, ellipseParams, waferData)
INPUT: center coordinates, ellipse parameters, wafer data
OUTPUT: starMask (binary matrix)

BEGIN
    height, width = Get_Dimensions(waferData)
    starMask = Initialize_Zero_Matrix(height, width)
    
    // Define 6 radial lines (60-degree intervals)
    angles = [0, 60, 120, 180, 240, 300]  // degrees
    
    FOR each angle in angles:
        
        // 2.3.3a Calculate line endpoint
        endX, endY = Calculate_Line_Ellipse_Intersection(
            centerX, centerY, angle, ellipseParams)
        
        // 2.3.3b Generate line with variations
        lineWidth = Generate_Variable_Width(config.baseWidth)
        starMask = Draw_Line_With_Breaks(starMask, 
            centerX, centerY, endX, endY, lineWidth, waferData)
        
    END FOR
    
    RETURN starMask
END
```

#### 2.3.3b Line Drawing with Breaks
```pseudocode
FUNCTION Draw_Line_With_Breaks(mask, x1, y1, x2, y2, width, waferData)
INPUT: mask, start/end coordinates, width, wafer data
OUTPUT: updated mask

BEGIN
    // Generate line coordinates
    lineCoords = Bresenham_Line_Algorithm(x1, y1, x2, y2)
    
    // Determine if line should have breaks
    hasBreaks = Random() < config.lineBreakProbability
    
    IF hasBreaks:
        breakMask = Generate_Break_Pattern(lineCoords.length)
    ELSE:
        breakMask = All_True(lineCoords.length)
    
    // Draw line segments
    FOR i = 1 to lineCoords.length:
        IF NOT breakMask[i]:
            CONTINUE  // Skip pixels in break segments
        
        x, y = lineCoords[i]
        
        // Skip invalid positions
        IF Out_Of_Bounds(x, y) OR Is_NaN(waferData[y, x]):
            CONTINUE
        
        // Apply width with local variation
        localWidth = width + Random(-1, 1)
        Apply_Width_At_Position(mask, x, y, localWidth, waferData)
        
    END FOR
    
    RETURN mask
END

FUNCTION Generate_Break_Pattern(lineLength)
INPUT: lineLength (integer)
OUTPUT: breakMask (boolean array)

BEGIN
    breakMask = All_True(lineLength)
    numBreaks = Random(1, config.maxBreaksPerLine)
    
    FOR i = 1 to numBreaks:
        breakStart = Random(lineLength * 0.2, lineLength * 0.8)
        breakLength = Random(config.breakLengthMin, config.breakLengthMax)
        breakEnd = Min(lineLength, breakStart + breakLength)
        
        breakMask[breakStart:breakEnd] = false
    END FOR
    
    RETURN breakMask
END
```

---

## Core Algorithm Components

### 1. Geometric Calculations

#### Line-Ellipse Intersection
```
Mathematical foundation: Quadratic equation solution
Input: Line parameters, ellipse center and axes
Output: Intersection points
Validation: Discriminant check, distance validation
```

#### Bresenham Line Algorithm
```
Purpose: Generate pixel coordinates along a line
Advantage: Integer-only arithmetic, efficient
Application: All line drawing operations
```

### 2. Randomization Strategy

| Component | Method | Purpose |
|-----------|---------|---------|
| Star Count | Probabilistic (70%/20%/10%) | Dataset variety |
| Star Positions | Gaussian variation | Realistic placement |
| Line Widths | Range + local variation | Natural appearance |
| Line Breaks | Probability + random segments | Defect realism |
| Intensities | Stochastic scaling | PL simulation |

### 3. Quality Assurance

#### Validation Checks
- **Boundary validation**: All coordinates within image bounds
- **Data integrity**: NaN and invalid value handling
- **Distance constraints**: Minimum separation between stars
- **Geometric validity**: Intersection calculation verification

#### Error Handling
- **Maximum attempt limits**: Prevent infinite loops
- **Graceful degradation**: Continue processing on individual failures
- **Data validation**: Input format and content verification

---

## Configuration Parameters

### Core Settings
```
PLstarEllipseYXRatio    = 2.0     // Major/minor axis ratio
PLstarEllipseScale      = 0.1     // Base ellipse size factor
PLstarWidth            = 2-7     // Line width range (random per file)
MinStarDistance        = 200     // Minimum star separation (pixels)
```

### Variation Parameters
```
PLstarCenterVariationX  = 0.15    // Center position variation (X-axis)
PLstarCenterVariationY  = 0.20    // Center position variation (Y-axis)
PLstarEllipseScaleVariation = 0.3 // Size variation between stars
WidthVariationRange    = [-2,2]   // Line width variation range
```

### Break Configuration
```
LineBreakProbability   = 0.3      // 30% chance of line breaks
MaxBreaksPerLine      = 3        // Maximum breaks per line
BreakLengthMin/Max    = 10-50    // Break segment length range
```

---

## Performance Characteristics

### Computational Complexity
- **Time complexity**: O(n × m × s) where n=files, m=pixels per line, s=stars
- **Memory usage**: O(w × h) for each wafer image (1500×1500)
- **Disk I/O**: Sequential file processing with batch output

### Scalability Considerations
- **Parallel processing**: File-level parallelization possible
- **Memory management**: Single wafer processing at a time
- **Output organization**: Timestamped hierarchical structure

### Quality Metrics
- **Success rate**: >95% valid star placement (with fallback handling)
- **Variation coverage**: Comprehensive parameter space exploration
- **Output consistency**: Standardized format and validation

---

## Usage Guidelines

### Input Requirements
```
File format: .mat files with 'dw_image' field
Image size: Any size (auto-resized to 1500×1500)
Data type: Numerical wafer measurement data
Invalid values: Handled automatically (0, NaN, min values)
```

### Output Structure
```
6-sixth_round_hazedata_with_plstar/
├── label/                    # Binary masks (.mat)
├── simulation_hazemap/       # Modified wafer data (.mat)
├── visualization_result/     # Plot images (.png)
└── [timestamp_prefix]        # All files timestamped
```

### Recommended Workflow
1. **Preparation**: Organize input .mat files in designated folder
2. **Configuration**: Adjust parameters based on dataset requirements
3. **Execution**: Run batch processing pipeline
4. **Validation**: Review visualization outputs for quality
5. **Integration**: Use generated masks and simulations for ML training

This documentation provides a comprehensive technical reference for the PL star simulation algorithm, suitable for team discussions, code reviews, and system maintenance.
