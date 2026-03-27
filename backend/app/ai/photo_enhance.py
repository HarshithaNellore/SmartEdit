"""AI Photo Enhancement using OpenCV.

Applies CLAHE histogram equalization, sharpening, and denoising
to produce a visually improved output image.
"""
import cv2
import numpy as np
import time
from pathlib import Path


def enhance_photo(input_path: str, output_path: str) -> dict:
    """Enhance a photo using OpenCV processing pipeline.

    Returns metadata dict with processing details.
    """
    start = time.time()

    img = cv2.imread(input_path)
    if img is None:
        raise ValueError(f"Cannot read image: {input_path}")

    # 1. Denoise
    denoised = cv2.fastNlMeansDenoisingColored(img, None, 10, 10, 7, 21)

    # 2. Convert to LAB and apply CLAHE on L channel for adaptive contrast
    lab = cv2.cvtColor(denoised, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8))
    l = clahe.apply(l)
    lab = cv2.merge([l, a, b])
    enhanced = cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)

    # 3. Sharpen using unsharp mask
    gaussian = cv2.GaussianBlur(enhanced, (0, 0), 3)
    sharpened = cv2.addWeighted(enhanced, 1.5, gaussian, -0.5, 0)

    # 4. Slight saturation boost
    hsv = cv2.cvtColor(sharpened, cv2.COLOR_BGR2HSV).astype(np.float32)
    hsv[:, :, 1] = np.clip(hsv[:, :, 1] * 1.15, 0, 255)
    hsv = hsv.astype(np.uint8)
    result = cv2.cvtColor(hsv, cv2.COLOR_HSV2BGR)

    cv2.imwrite(output_path, result, [cv2.IMWRITE_JPEG_QUALITY, 95])

    elapsed = round(time.time() - start, 2)
    h, w = result.shape[:2]
    return {
        "processing_time_sec": elapsed,
        "resolution": f"{w}x{h}",
        "enhancements_applied": ["denoise", "clahe_contrast", "sharpen", "saturation_boost"],
    }
