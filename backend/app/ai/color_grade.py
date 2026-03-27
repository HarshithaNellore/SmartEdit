"""Basic color grading: brightness, contrast, saturation adjustments."""
import time
import cv2
import numpy as np


def color_grade(input_path: str, output_path: str,
                brightness: float = 0, contrast: float = 0,
                saturation: float = 0, warmth: float = 0) -> dict:
    """Apply color grading adjustments to an image.
    
    Args:
        brightness: -100 to +100 (0 = no change)
        contrast:   -100 to +100 (0 = no change)
        saturation: -100 to +100 (0 = no change)
        warmth:     -50 to +50   (0 = no change, positive = warmer)
    """
    start = time.time()
    img = cv2.imread(input_path)
    if img is None:
        raise ValueError(f"Could not read image: {input_path}")

    result = img.astype(np.float32)

    # Brightness
    if brightness != 0:
        result = result + brightness
        result = np.clip(result, 0, 255)

    # Contrast
    if contrast != 0:
        factor = (100 + contrast) / 100.0
        result = 128 + factor * (result - 128)
        result = np.clip(result, 0, 255)

    # Convert to uint8 for HSV conversion
    result = result.astype(np.uint8)

    # Saturation
    if saturation != 0:
        hsv = cv2.cvtColor(result, cv2.COLOR_BGR2HSV).astype(np.float32)
        factor = (100 + saturation) / 100.0
        hsv[:, :, 1] = np.clip(hsv[:, :, 1] * factor, 0, 255)
        result = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR)

    # Warmth (shift blue/red channels)
    if warmth != 0:
        result = result.astype(np.float32)
        result[:, :, 2] = np.clip(result[:, :, 2] + warmth, 0, 255)  # Red
        result[:, :, 0] = np.clip(result[:, :, 0] - warmth * 0.5, 0, 255)  # Blue
        result = result.astype(np.uint8)

    cv2.imwrite(output_path, result)
    elapsed = round(time.time() - start, 2)

    return {
        "processing_time": elapsed,
        "brightness": brightness,
        "contrast": contrast,
        "saturation": saturation,
        "warmth": warmth,
        "output_path": output_path,
    }
