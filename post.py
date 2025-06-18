import cv2
import numpy as np
import math
from skimage.morphology import skeletonize
from sklearn.cluster import DBSCAN
import matplotlib.pyplot as plt

# === 主函数：检测 PL Star 中心点及线条 === #
def detect_pl_stars_debug(binary_mask,
                          hough_thresh=50, min_len=10, max_gap=3,
                          angle_tol=15, cluster_eps=10, cluster_min_pts=3):
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    closed = cv2.morphologyEx(binary_mask.astype(np.uint8), cv2.MORPH_CLOSE, kernel)
    skel = skeletonize(closed > 0).astype(np.uint8) * 255

    lines_p = cv2.HoughLinesP(skel, rho=1, theta=np.pi/180,
                              threshold=hough_thresh,
                              minLineLength=min_len,
                              maxLineGap=max_gap)
    kept = []
    if lines_p is not None:
        canonical = np.array([0.0, 60.0, 120.0])
        for x1, y1, x2, y2 in lines_p[:, 0, :]:
            ang = (math.degrees(math.atan2(y2 - y1, x2 - x1)) + 360) % 180
            diffs = np.abs(ang - canonical)
            diffs = np.minimum(diffs, 180 - diffs)
            idx = int(np.argmin(diffs))
            if diffs[idx] < angle_tol:
                kept.append((x1, y1, x2, y2, float(canonical[idx])))

    pts, dir_pairs = [], []
    lines_eq = []
    for x1, y1, x2, y2, ang0 in kept:
        a, b = y2 - y1, x1 - x2
        c = x2 * y1 - x1 * y2
        lines_eq.append((a, b, c, ang0))
    for i in range(len(lines_eq)):
        a1, b1, c1, d1 = lines_eq[i]
        for j in range(i + 1, len(lines_eq)):
            a2, b2, c2, d2 = lines_eq[j]
            D = a1 * b2 - a2 * b1
            if abs(D) < 1e-6:
                continue
            x = (b1 * c2 - b2 * c1) / D
            y = (c1 * a2 - c2 * a1) / D
            pts.append([x, y])
            dir_pairs.append((d1, d2))

    centers = []
    if pts:
        pts_arr = np.array(pts)
        clustering = DBSCAN(eps=cluster_eps, min_samples=cluster_min_pts).fit(pts_arr)
        for lbl in set(clustering.labels_):
            if lbl < 0:
                continue
            mask_lbl = clustering.labels_ == lbl
            dirs = set()
            for k, pair in enumerate(dir_pairs):
                if mask_lbl[k]:
                    dirs.update(pair)
            if len(dirs) >= 3:
                centroid = pts_arr[mask_lbl].mean(axis=0)
                centers.append((centroid[0], centroid[1]))

    return centers, kept, closed, skel

# === 横向可视化函数 === #
def visualize_pl_star_detection_horizontal(mask, centers, kept_lines, closed, skel, title="PL Star Detection"):
    fig, axs = plt.subplots(1, 4, figsize=(20, 5))  # 横向排列
    fig.suptitle(title, fontsize=18)

    axs[0].imshow(mask, cmap='gray')
    axs[0].set_title("Original Mask")
    axs[0].axis('off')

    axs[1].imshow(closed, cmap='gray')
    axs[1].set_title("After Closing")
    axs[1].axis('off')

    axs[2].imshow(skel, cmap='gray')
    axs[2].set_title("Skeleton")
    axs[2].axis('off')

    overlay = cv2.cvtColor(skel, cv2.COLOR_GRAY2BGR)
    for x1, y1, x2, y2, _ in kept_lines:
        cv2.line(overlay, (x1, y1), (x2, y2), (0, 0, 255), 1)
    for cx, cy in centers:
        cv2.drawMarker(overlay, (int(cx), int(cy)), (0, 255, 0),
                       markerType=cv2.MARKER_CROSS, markerSize=20, thickness=2)
    axs[3].imshow(overlay)
    axs[3].set_title("Detected Lines & Centers")
    axs[3].axis('off')

    plt.tight_layout(rect=[0, 0, 1, 0.93])
    plt.show()


centers, lines, closed, skel = detect_pl_stars_debug(mask)
visualize_pl_star_detection_horizontal(mask, centers, lines, closed, skel, title="Perfect PL Star")








import cv2
import numpy as np
import math
from skimage.morphology import skeletonize
from sklearn.cluster import DBSCAN
import matplotlib.pyplot as plt

# === 主函数：检测 PL Star 中心点及线条 === #
def detect_pl_stars_debug(binary_mask,
                          hough_thresh=50, min_len=10, max_gap=3,
                          angle_tol=15, cluster_eps=10, cluster_min_pts=3):
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    closed = cv2.morphologyEx(binary_mask.astype(np.uint8), cv2.MORPH_CLOSE, kernel)
    skel = skeletonize(closed > 0).astype(np.uint8) * 255

    lines_p = cv2.HoughLinesP(skel, rho=1, theta=np.pi/180,
                              threshold=hough_thresh,
                              minLineLength=min_len,
                              maxLineGap=max_gap)
    kept = []
    if lines_p is not None:
        canonical = np.array([0.0, 60.0, 120.0])
        for x1, y1, x2, y2 in lines_p[:, 0, :]:
            ang = (math.degrees(math.atan2(y2 - y1, x2 - x1)) + 360) % 180
            diffs = np.abs(ang - canonical)
            diffs = np.minimum(diffs, 180 - diffs)
            idx = int(np.argmin(diffs))
            if diffs[idx] < angle_tol:
                kept.append((x1, y1, x2, y2, float(canonical[idx])))

    pts, dir_pairs = [], []
    lines_eq = []
    for x1, y1, x2, y2, ang0 in kept:
        a, b = y2 - y1, x1 - x2
        c = x2 * y1 - x1 * y2
        lines_eq.append((a, b, c, ang0))
    for i in range(len(lines_eq)):
        a1, b1, c1, d1 = lines_eq[i]
        for j in range(i + 1, len(lines_eq)):
            a2, b2, c2, d2 = lines_eq[j]
            D = a1 * b2 - a2 * b1
            if abs(D) < 1e-6:
                continue
            x = (b1 * c2 - b2 * c1) / D
            y = (c1 * a2 - c2 * a1) / D
            pts.append([x, y])
            dir_pairs.append((d1, d2))

    centers = []
    if pts:
        pts_arr = np.array(pts)
        clustering = DBSCAN(eps=cluster_eps, min_samples=cluster_min_pts).fit(pts_arr)
        for lbl in set(clustering.labels_):
            if lbl < 0:
                continue
            mask_lbl = clustering.labels_ == lbl
            dirs = set()
            for k, pair in enumerate(dir_pairs):
                if mask_lbl[k]:
                    dirs.update(pair)
            if len(dirs) >= 3:
                centroid = pts_arr[mask_lbl].mean(axis=0)
                centers.append((centroid[0], centroid[1]))

    # 打印中心坐标
    if centers:
        print(f"[INFO] Detected {len(centers)} PL Star center(s):")
        for i, (x, y) in enumerate(centers):
            print(f"  → Center {i+1}: (x = {x:.1f}, y = {y:.1f})")
    else:
        print("[INFO] No PL Star centers detected.")

    return centers, kept, closed, skel

##########################################################################################################################################
def visualize_pl_star_detection_horizontal(mask, centers, kept_lines, closed, skel, title="PL Star Detection"):
    fig, axs = plt.subplots(1, 4, figsize=(20, 5))
    fig.suptitle(title, fontsize=18)

    axs[0].imshow(mask, cmap='gray')
    axs[0].set_title("Original Mask")
    axs[0].axis('off')

    axs[1].imshow(closed, cmap='gray')
    axs[1].set_title("After Closing")
    axs[1].axis('off')

    axs[2].imshow(skel, cmap='gray')
    axs[2].set_title("Skeleton")
    axs[2].axis('off')

    overlay = cv2.cvtColor(skel, cv2.COLOR_GRAY2BGR)
    for x1, y1, x2, y2, _ in kept_lines:
        cv2.line(overlay, (x1, y1), (x2, y2), (0, 0, 255), 1)
    for cx, cy in centers:
        cv2.drawMarker(overlay, (int(cx), int(cy)), (0, 255, 0),
                       markerType=cv2.MARKER_CROSS, markerSize=20, thickness=2)
        cv2.putText(overlay, f"({int(cx)}, {int(cy)})", (int(cx)+10, int(cy)-10),
                    fontFace=cv2.FONT_HERSHEY_SIMPLEX, fontScale=0.5, color=(255, 255, 0), thickness=1)
    axs[3].imshow(overlay)
    axs[3].set_title("Detected Lines & Centers")
    axs[3].axis('off')

    plt.tight_layout(rect=[0, 0, 1, 0.93])
    plt.show()

##########################################################################################################################################
####################### 找到断线
def visualize_pl_star_detection_with_star_lines(mask, centers, kept_lines, skel, title="PL Star Detection"):
    fig, axs = plt.subplots(1, 4, figsize=(24, 6))
    fig.suptitle(title, fontsize=18)

    axs[0].imshow(mask, cmap='gray')
    axs[0].set_title("Original Mask")
    axs[0].axis('off')

    axs[1].imshow(skel, cmap='gray')
    axs[1].set_title("Skeleton")
    axs[1].axis('off')

    # Detected lines + centers
    overlay1 = cv2.cvtColor(skel, cv2.COLOR_GRAY2BGR)
    for x1, y1, x2, y2, _ in kept_lines:
        cv2.line(overlay1, (x1, y1), (x2, y2), (0, 0, 255), 1)
    for cx, cy in centers:
        cv2.drawMarker(overlay1, (int(cx), int(cy)), (0, 255, 0),
                       markerType=cv2.MARKER_CROSS, markerSize=20, thickness=2)
        cv2.putText(overlay1, f"({int(cx)}, {int(cy)})", (int(cx) + 10, int(cy) - 10),
                    fontFace=cv2.FONT_HERSHEY_SIMPLEX, fontScale=0.5, color=(255, 255, 0), thickness=1)
    axs[2].imshow(overlay1)
    axs[2].set_title("Detected Lines & Centers")
    axs[2].axis('off')

    # Reverse lookup from center: draw ideal star lines from center on original mask
    overlay2 = cv2.cvtColor(mask * 255, cv2.COLOR_GRAY2BGR)
    for cx, cy in centers:
        for angle in [0, 60, 120, 180, 240, 300]:
            rad = math.radians(angle)
            for r in range(0, 300):
                x = int(cx + r * math.cos(rad))
                y = int(cy + r * math.sin(rad))
                if 0 <= x < mask.shape[1] and 0 <= y < mask.shape[0]:
                    if mask[y, x] > 0:
                        overlay2[y, x] = [0, 255, 255]  # yellow line
                    else:
                        break  # early stop if mask中断裂
    axs[3].imshow(overlay2)
    axs[3].set_title("Recovered PL Star Lines")
    axs[3].axis('off')

    plt.tight_layout(rect=[0, 0, 1, 0.93])
    plt.show()



    # Reverse lookup from center with gap tolerance
    overlay2 = cv2.cvtColor(mask * 255, cv2.COLOR_GRAY2BGR)
    for cx, cy in centers:
        for angle in [0, 60, 120, 180, 240, 300]:
            rad = math.radians(angle)
            gap_count = 0
            max_gap = 5  # 容许最多连续5像素中断
            for r in range(0, 300):
                x = int(cx + r * math.cos(rad))
                y = int(cy + r * math.sin(rad))
                if 0 <= x < mask.shape[1] and 0 <= y < mask.shape[0]:
                    if mask[y, x] > 0:
                        overlay2[y, x] = [0, 255, 255]  # yellow
                        gap_count = 0  # reset
                    else:
                        gap_count += 1
                        if gap_count > max_gap:
                            break  # too many gaps → stop
                else:
                    break



