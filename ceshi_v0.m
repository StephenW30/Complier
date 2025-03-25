function [waferData, waferInfo] = loadMatData(filePath)
    % Load the .mat file
    matData = load(filePath);
    
    % Initialize waferInfo structure
    waferInfo = struct();
    
    % Get the field names in the .mat file
    fieldNames = fieldnames(matData);
    
    % Look for wafer data - typically the largest numerical array
    waferData = [];
    maxSize = 0;
    
    for i = 1:length(fieldNames)
        currentField = matData.(fieldNames{i});
        
        % Check if it's a numeric array
        if isnumeric(currentField) && ndims(currentField) == 2
            currentSize = numel(currentField);
            if currentSize > maxSize
                waferData = currentField;
                maxSize = currentSize;
            end
        end
    end
    
    % If no suitable data found, throw an error
    if isempty(waferData)
        error('Could not find wafer data in file: %s', filePath);
    end
    
    % Get wafer dimensions
    waferInfo.Shape = size(waferData);  % [height, width]
    
    % Extract wafer name - use filename if no name field found
    waferInfo.Name = [];
    for i = 1:length(fieldNames)
        if strcmpi(fieldNames{i}, 'name') || strcmpi(fieldNames{i}, 'waferName')
            if ischar(matData.(fieldNames{i}))
                waferInfo.Name = matData.(fieldNames{i});
                break;
            end
        end
    end
    
    if isempty(waferInfo.Name)
        [~, waferInfo.Name, ~] = fileparts(filePath);
    end
    
    % Replace 0 values with NaN
    waferData(waferData == 0) = nan;
    
    % Look for pixel size information
    waferInfo.PixelSizeMm = 0.1;  % Default value
    for i = 1:length(fieldNames)
        if strcmpi(fieldNames{i}, 'pixelSize') || strcmpi(fieldNames{i}, 'pixelSizeMm')
            if isnumeric(matData.(fieldNames{i})) && isscalar(matData.(fieldNames{i}))
                waferInfo.PixelSizeMm = matData.(fieldNames{i});
                break;
            end
        end
    end
    
    % Display found information
    fprintf('Loaded file: %s\n', filePath);
    fprintf('  Wafer name: %s\n', waferInfo.Name);
    fprintf('  Dimensions: %d x %d\n', waferInfo.Shape(1), waferInfo.Shape(2));
    fprintf('  Pixel size: %.4f mm\n', waferInfo.PixelSizeMm);
end
