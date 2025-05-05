function scratched_wafer = generate_wafer_scratches(wafer_image, num_scratches, min_radius_factor, max_radius_factor)
% GENERATE_WAFER_SCRATCHES Generate scratches on a wafer image
%
% Parameters:
%   wafer_image - Single-channel wafer image with NaN background values
%   num_scratches - Number of scratches to generate. If empty, randomly generates 0-9 scratches
%   min_radius_factor - Minimum factor to multiply the distance between points for radius (default: 10)
%   max_radius_factor - Maximum factor to multiply the distance between points for radius (default: 30)
%
% Returns:
%   scratched_wafer - Wafer image with simulated scratches

    % Set default values if not provided
    if nargin < 2 || isempty(num_scratches)
        num_scratches = randi([0, 9]);
    end
    
    if nargin < 3 || isempty(min_radius_factor)
        min_radius_factor = 10;
    end
    
    if nargin < 4 || isempty(max_radius_factor)
        max_radius_factor = 30;
    end
    
    % Make a copy of the image
    scratched_wafer = wafer_image;
    
    % Create a mask for the wafer (non-NaN areas)
    wafer_mask = ~isnan(wafer_image);
    
    % Get image dimensions
    [height, width] = size(wafer_image);
    
    % For each scratch
    for i = 1:num_scratches
        % Get random scratch width (1-3 pixels)
        scratch_width = randi([1, 3]);
        
        % Generate random relative positions
        % Keep trying until we get points on the wafer
        valid_points = false;
        attempts = 0;
        
        while ~valid_points && attempts < 100
            % Generate relative positions
            rel_x0 = rand();
            rel_y0 = rand();
            rel_x1 = rand();
            rel_y1 = rand();
            
            % Calculate absolute pixel positions
            x0 = round(rel_x0 * width);
            y0 = round(rel_y0 * height);
            x1 = round(rel_x1 * width);
            y1 = round(rel_y1 * height);
            
            % Ensure valid indices (MATLAB uses 1-based indexing)
            x0 = max(1, min(width, x0));
            y0 = max(1, min(height, y0));
            x1 = max(1, min(width, x1));
            y1 = max(1, min(height, y1));
            
            % Check if both points are on the wafer
            if wafer_mask(y0, x0) && wafer_mask(y1, x1)
                % Check if points are sufficiently far apart
                dist = sqrt((x1 - x0)^2 + (y1 - y0)^2);
                if dist > 10  % Minimum distance to ensure meaningful scratches
                    valid_points = true;
                end
            end
            
            attempts = attempts + 1;
        end
        
        if ~valid_points
            continue;  % Skip this scratch if we couldn't find valid points
        end
        
        % Calculate midpoint
        xm = (x0 + x1) / 2;
        ym = (y0 + y1) / 2;
        
        % Calculate perpendicular vector
        dx = x1 - x0;
        dy = y1 - y0;
        distance = sqrt(dx^2 + dy^2);
        
        % Perpendicular unit vector
        perp_dx = -dy / distance;
        perp_dy = dx / distance;
        
        % Calculate radius (much larger than the distance)
        radius = distance * (min_radius_factor + (max_radius_factor - min_radius_factor) * rand());
        
        % Calculate center candidates
        center_distance = sqrt(radius^2 - (distance/2)^2);
        cx1 = xm + perp_dx * center_distance;
        cy1 = ym + perp_dy * center_distance;
        cx2 = xm - perp_dx * center_distance;
        cy2 = ym - perp_dy * center_distance;
        
        % Choose center with 50% probability for each
        if rand() < 0.5
            center_x = cx1;
            center_y = cy1;
        else
            center_x = cx2;
            center_y = cy2;
        end
        
        % Calculate angles from center to the points
        angle0 = atan2(y0 - center_y, x0 - center_x);
        angle1 = atan2(y1 - center_y, x1 - center_x);
        
        % Ensure we take the shorter arc
        if abs(angle1 - angle0) > pi
            if angle0 < angle1
                angle0 = angle0 + 2 * pi;
            else
                angle1 = angle1 + 2 * pi;
            end
        end
        
        % Draw the arc using the modified Bresenham algorithm
        scratched_wafer = draw_arc(scratched_wafer, center_x, center_y, radius, angle0, angle1, scratch_width, wafer_mask);
    end
end

function image = draw_arc(image, center_x, center_y, radius, start_angle, end_angle, width, mask)
% DRAW_ARC Draw an arc on the image
%
% Parameters:
%   image - Image to draw on
%   center_x, center_y - Center coordinates of the circle
%   radius - Radius of the circle
%   start_angle, end_angle - Start and end angles in radians
%   width - Width of the scratch in pixels
%   mask - Boolean mask of valid drawing areas
%
% Returns:
%   image - Updated image with the arc drawn

    % Ensure angles are in ascending order
    if start_angle > end_angle
        temp = start_angle;
        start_angle = end_angle;
        end_angle = temp;
    end
    
    % Determine number of steps for smooth arc
    arc_length = radius * abs(end_angle - start_angle);
    steps = max(100, round(arc_length));
    
    % Generate points along the arc
    for i = 0:steps
        t = i / steps;
        angle = start_angle + t * (end_angle - start_angle);
        
        x = center_x + radius * cos(angle);
        y = center_y + radius * sin(angle);
        
        % Round to nearest pixel
        px = round(x);
        py = round(y);
        
        % Draw the point with specified width
        image = draw_scratch_point(image, px, py, width, mask);
    end
end

function image = draw_scratch_point(image, x, y, width, mask)
% DRAW_SCRATCH_POINT Draw a scratch point with specified width
%
% Parameters:
%   image - Image to draw on
%   x, y - Coordinates of the point
%   width - Width of the scratch
%   mask - Boolean mask of valid drawing areas
%
% Returns:
%   image - Updated image with the scratch point drawn

    [height, width_img] = size(image);
    half_width = floor(width / 2);
    
    % Determine scratch value
    scratch_value = 0;  % Black scratch
    
    % Draw the point and its neighborhood according to width
    for dy = -half_width:half_width
        for dx = -half_width:half_width
            nx = x + dx;
            ny = y + dy;
            
            % Check bounds (MATLAB uses 1-based indexing)
            if nx >= 1 && nx <= width_img && ny >= 1 && ny <= height
                % Only draw on the wafer (non-NaN regions)
                if mask(ny, nx)
                    image(ny, nx) = scratch_value;
                end
            end
        end
    end
end

function wafer = create_sample_wafer(size, radius_factor)
% CREATE_SAMPLE_WAFER Create a sample wafer image for demonstration
%
% Parameters:
%   size - Size of the image (size x size)
%   radius_factor - Factor to determine wafer radius as a fraction of image size
%
% Returns:
%   wafer - Sample wafer image with NaN background

    if nargin < 1 || isempty(size)
        size = 512;
    end
    
    if nargin < 2 || isempty(radius_factor)
        radius_factor = 0.8;
    end
    
    % Create a blank image with NaN values
    wafer = nan(size, size);
    
    % Create a circular wafer
    center = size / 2;
    radius = round(size * radius_factor / 2);
    
    % Create meshgrid for coordinates
    [x, y] = meshgrid(1:size, 1:size);
    
    % Calculate distance from center
    mask = (x - center).^2 + (y - center).^2 <= radius^2;
    
    % Fill the wafer with random pixel values
    wafer(mask) = 100 + 100 * rand(sum(mask(:)), 1);
end

function visualize_wafer_with_scratches(original_wafer, scratched_wafer)
% VISUALIZE_WAFER_WITH_SCRATCHES Visualize the original and scratched wafer images side by side
%
% Parameters:
%   original_wafer - Original wafer image
%   scratched_wafer - Wafer image with scratches

    figure('Position', [100, 100, 1200, 600]);
    
    % Plot original wafer
    subplot(1, 2, 1);
    imagesc(original_wafer);
    colormap('gray');
    colorbar;
    title('Original Wafer');
    axis equal;
    axis tight;
    
    % Plot scratched wafer
    subplot(1, 2, 2);
    imagesc(scratched_wafer);
    colormap('gray');
    colorbar;
    title('Scratched Wafer');
    axis equal;
    axis tight;
end

% Main script for wafer scratch simulation demonstration

% Create a sample wafer image
wafer_image = create_sample_wafer(1000);

% Generate scratches (for example, 5 scratches)
scratched_wafer = generate_wafer_scratches(wafer_image, 5);

% Visualize results
visualize_wafer_with_scratches(wafer_image, scratched_wafer);
