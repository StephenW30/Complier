import matplotlib.pyplot as plt
import cv2
import numpy as np
import math

def visualize_pl_star_detection_updated(hazemap, model_output, centers, kept_lines, title="PL Star Detection"):
    """
    Updated visualization for PL star detection pipeline.

    Parameters:
        hazemap: np.ndarray
            Original hazard map (float or uint8).
        model_output: np.ndarray
            Model output (float, assumed in [0,1]).
        centers: list of (x, y)
            Detected center points.
        kept_lines: list of (x1, y1, x2, y2, angle)
            Filtered line segments.
        title: str
            Plot title.
    """
    fig, axs = plt.subplots(1, 4, figsize=(28, 6))
    fig.suptitle(title, fontsize=18)

    # Plot 1: Original hazard map with colorbar
    im0 = axs[0].imshow(hazemap, cmap='viridis')
    axs[0].set_title("Original Hazard Map")
    axs[0].axis('off')
    plt.colorbar(im0, ax=axs[0], fraction=0.046, pad=0.04)

    # Plot 2: Thresholded model output
    thresholded_output = (model_output >= 0.5).astype(np.uint8)
    im1 = axs[1].imshow(thresholded_output, cmap='gray')
    axs[1].set_title("Thresholded Model Output (0.5)")
    axs[1].axis('off')
    plt.colorbar(im1, ax=axs[1], fraction=0.046, pad=0.04)

    # Plot 3: Recovered PL Star with center point markers
    overlay1 = cv2.cvtColor((thresholded_output * 255).astype(np.uint8), cv2.COLOR_GRAY2BGR)
    for x1, y1, x2, y2, _ in kept_lines:
        cv2.line(overlay1, (x1, y1), (x2, y2), (0, 0, 255), 1)
    for cx, cy in centers:
        cv2.drawMarker(overlay1, (int(cx), int(cy)), (0, 255, 0),
                       markerType=cv2.MARKER_CROSS, markerSize=20, thickness=2)
        cv2.putText(overlay1, f"({int(cx)}, {int(cy)})", (int(cx)+5, int(cy)-5),
                    fontFace=cv2.FONT_HERSHEY_SIMPLEX, fontScale=0.5,
                    color=(255, 255, 0), thickness=1)
    axs[2].imshow(overlay1)
    axs[2].set_title("Recovered PL Star Lines & Centers")
    axs[2].axis('off')

    # Plot 4: Overlay recovered lines and centers onto hazemap
    overlay2 = cv2.cvtColor((hazemap / hazemap.max() * 255).astype(np.uint8), cv2.COLOR_GRAY2BGR)
    for cx, cy in centers:
        for angle in [0, 60, 120, 180, 240, 300]:
            rad = math.radians(angle)
            gap_count = 0
            max_gap = 5
            for r in range(0, 300):
                x = int(cx + r * math.cos(rad))
                y = int(cy + r * math.sin(rad))
                if 0 <= x < overlay2.shape[1] and 0 <= y < overlay2.shape[0]:
                    if thresholded_output[y, x] > 0:
                        overlay2[y, x] = [0, 255, 255]
                        gap_count = 0
                    else:
                        gap_count += 1
                        if gap_count > max_gap:
                            break
                else:
                    break
    for cx, cy in centers:
        cv2.drawMarker(overlay2, (int(cx), int(cy)), (0, 255, 0),
                       markerType=cv2.MARKER_CROSS, markerSize=20, thickness=2)
    axs[3].imshow(overlay2)
    axs[3].set_title("Overlay on Hazard Map")
    axs[3].axis('off')

    plt.tight_layout(rect=[0, 0, 1, 0.95])
    plt.show()
