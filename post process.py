import cv2
import numpy as np
import matplotlib.pyplot as plt
from scipy.spatial.distance import cdist
from collections import defaultdict
import math

class PLstarDetector:
    def __init__(self, angle_tolerance=5, distance_tolerance=20, min_line_length=30, max_line_gap=10):
        """
        PLstar检测器初始化
        
        参数:
        - angle_tolerance: 角度容忍度（度）
        - distance_tolerance: 距离容忍度（像素）
        - min_line_length: 最小线段长度
        - max_line_gap: 最大线段间隙
        """
        self.expected_angles = [0, 60, 120, 180, 240, 300]  # PLstar的6个预期角度
        self.angle_tolerance = angle_tolerance
        self.distance_tolerance = distance_tolerance
        self.min_line_length = min_line_length
        self.max_line_gap = max_line_gap
        
    def preprocess_image(self, image):
        """预处理图像"""
        if len(image.shape) == 3:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        else:
            gray = image.copy()
        
        # 应用高斯模糊减少噪声
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        
        # 边缘检测
        edges = cv2.Canny(blurred, 50, 150, apertureSize=3)
        
        return edges
    
    def detect_lines_hough(self, edges):
        """使用霍夫变换检测线段"""
        # 概率霍夫变换检测线段
        lines = cv2.HoughLinesP(
            edges, 
            rho=1, 
            theta=np.pi/180, 
            threshold=50,
            minLineLength=self.min_line_length,
            maxLineGap=self.max_line_gap
        )
        
        return lines
    
    def calculate_line_angle(self, x1, y1, x2, y2):
        """计算线段角度（0-360度）"""
        angle = math.degrees(math.atan2(y2 - y1, x2 - x1))
        # 将角度转换为0-360度范围
        if angle < 0:
            angle += 360
        return angle
    
    def normalize_angle(self, angle):
        """将角度标准化到0-180度范围（因为线段方向性）"""
        if angle > 180:
            angle -= 180
        return angle
    
    def group_lines_by_angle(self, lines):
        """根据角度分组线段"""
        angle_groups = defaultdict(list)
        
        if lines is None:
            return angle_groups
        
        for line in lines:
            x1, y1, x2, y2 = line[0]
            angle = self.calculate_line_angle(x1, y1, x2, y2)
            normalized_angle = self.normalize_angle(angle)
            
            # 找到最接近的预期角度
            closest_expected = min(self.expected_angles, 
                                 key=lambda x: min(abs(normalized_angle - x), 
                                                  abs(normalized_angle - (x + 180) % 360)))
            
            # 检查是否在容忍范围内
            angle_diff = min(abs(normalized_angle - closest_expected),
                           abs(normalized_angle - (closest_expected + 180) % 360))
            
            if angle_diff <= self.angle_tolerance:
                angle_groups[closest_expected].append({
                    'line': line[0],
                    'angle': normalized_angle,
                    'center': ((x1 + x2) // 2, (y1 + y2) // 2),
                    'length': np.sqrt((x2 - x1)**2 + (y2 - y1)**2)
                })
        
        return angle_groups
    
    def find_intersection_point(self, line1, line2):
        """计算两条线段的交点"""
        x1, y1, x2, y2 = line1
        x3, y3, x4, y4 = line2
        
        denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
        if abs(denom) < 1e-10:
            return None
        
        t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
        u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom
        
        x = x1 + t * (x2 - x1)
        y = y1 + t * (y2 - y1)
        
        return (int(x), int(y))
    
    def find_star_center(self, angle_groups):
        """找到PLstar的中心点"""
        all_intersections = []
        
        # 计算所有线段对的交点
        group_keys = list(angle_groups.keys())
        for i in range(len(group_keys)):
            for j in range(i + 1, len(group_keys)):
                group1 = angle_groups[group_keys[i]]
                group2 = angle_groups[group_keys[j]]
                
                for line1_info in group1:
                    for line2_info in group2:
                        intersection = self.find_intersection_point(
                            line1_info['line'], line2_info['line']
                        )
                        if intersection:
                            all_intersections.append(intersection)
        
        if not all_intersections:
            return None
        
        # 使用聚类找到最可能的中心点
        intersections = np.array(all_intersections)
        
        # 简单的聚类：找到最密集的点
        if len(intersections) == 1:
            return intersections[0]
        
        # 计算所有点的中位数作为中心候选
        center_candidate = np.median(intersections, axis=0).astype(int)
        
        # 找到距离中心候选点最近的实际交点
        distances = cdist([center_candidate], intersections)[0]
        closest_idx = np.argmin(distances)
        
        return tuple(intersections[closest_idx])
    
    def validate_plstar(self, angle_groups, center):
        """验证是否为有效的PLstar"""
        if center is None:
            return False, []
        
        # 检查是否有足够的角度组
        if len(angle_groups) < 4:  # 至少需要4个方向
            return False, []
        
        valid_lines = []
        found_angles = set()
        
        for expected_angle in self.expected_angles:
            if expected_angle in angle_groups:
                # 为每个角度找到最接近中心的线段
                best_line = None
                min_distance = float('inf')
                
                for line_info in angle_groups[expected_angle]:
                    line = line_info['line']
                    x1, y1, x2, y2 = line
                    
                    # 计算线段到中心点的距离
                    distance = self.point_to_line_distance(center, (x1, y1, x2, y2))
                    
                    if distance < min_distance and distance < self.distance_tolerance:
                        min_distance = distance
                        best_line = line_info
                
                if best_line:
                    valid_lines.append(best_line)
                    found_angles.add(expected_angle)
        
        # 检查是否找到了至少4个不同角度的线段
        is_valid = len(found_angles) >= 4
        
        return is_valid, valid_lines
    
    def point_to_line_distance(self, point, line):
        """计算点到线段的距离"""
        px, py = point
        x1, y1, x2, y2 = line
        
        A = px - x1
        B = py - y1
        C = x2 - x1
        D = y2 - y1
        
        dot = A * C + B * D
        len_sq = C * C + D * D
        
        if len_sq == 0:
            return np.sqrt(A * A + B * B)
        
        param = dot / len_sq
        
        if param < 0:
            xx, yy = x1, y1
        elif param > 1:
            xx, yy = x2, y2
        else:
            xx = x1 + param * C
            yy = y1 + param * D
        
        dx = px - xx
        dy = py - yy
        return np.sqrt(dx * dx + dy * dy)
    
    def detect_plstar(self, image):
        """主要的PLstar检测函数"""
        # 预处理
        edges = self.preprocess_image(image)
        
        # 霍夫变换检测线段
        lines = self.detect_lines_hough(edges)
        
        if lines is None:
            return None, None, None
        
        # 按角度分组线段
        angle_groups = self.group_lines_by_angle(lines)
        
        # 找到星形中心
        center = self.find_star_center(angle_groups)
        
        # 验证PLstar
        is_valid, valid_lines = self.validate_plstar(angle_groups, center)
        
        if is_valid:
            return center, valid_lines, angle_groups
        else:
            return None, None, None
    
    def visualize_result(self, image, center, valid_lines, angle_groups):
        """可视化检测结果"""
        result_img = image.copy()
        if len(result_img.shape) == 2:
            result_img = cv2.cvtColor(result_img, cv2.COLOR_GRAY2BGR)
        
        # 绘制所有检测到的线段（灰色）
        if angle_groups:
            for angle, lines in angle_groups.items():
                for line_info in lines:
                    x1, y1, x2, y2 = line_info['line']
                    cv2.line(result_img, (x1, y1), (x2, y2), (128, 128, 128), 1)
        
        # 绘制有效的PLstar线段（绿色）
        if valid_lines:
            for line_info in valid_lines:
                x1, y1, x2, y2 = line_info['line']
                cv2.line(result_img, (x1, y1), (x2, y2), (0, 255, 0), 2)
        
        # 绘制中心点（红色）
        if center:
            cv2.circle(result_img, center, 5, (0, 0, 255), -1)
            cv2.circle(result_img, center, 10, (0, 0, 255), 2)
        
        return result_img

# 使用示例
def example_usage():
    """使用示例"""
    # 创建检测器实例
    detector = PLstarDetector(
        angle_tolerance=10,
        distance_tolerance=25,
        min_line_length=20,
        max_line_gap=15
    )
    
    # 假设您有一个图像（model_prediction_image）
    # image = cv2.imread('your_model_prediction.jpg')
    
    # 如果您的模型输出是二值化的结果，可以直接使用
    # 如果是概率图，需要先阈值化
    # threshold_image = (prediction > 0.5).astype(np.uint8) * 255
    
    # 检测PLstar
    # center, valid_lines, angle_groups = detector.detect_plstar(image)
    
    # if center is not None:
    #     print(f"检测到PLstar，中心点: {center}")
    #     print(f"有效线段数量: {len(valid_lines)}")
    #     
    #     # 可视化结果
    #     result_img = detector.visualize_result(image, center, valid_lines, angle_groups)
    #     
    #     # 显示结果
    #     plt.figure(figsize=(12, 6))
    #     plt.subplot(1, 2, 1)
    #     plt.imshow(image, cmap='gray')
    #     plt.title('原始图像')
    #     plt.axis('off')
    #     
    #     plt.subplot(1, 2, 2)
    #     plt.imshow(cv2.cvtColor(result_img, cv2.COLOR_BGR2RGB))
    #     plt.title('PLstar检测结果')
    #     plt.axis('off')
    #     plt.show()
    # else:
    #     print("未检测到有效的PLstar")

if __name__ == "__main__":
    example_usage()
