"""Blur background while keeping foreground subject sharp.

Uses rembg for mask generation + Gaussian blur on background.
"""
import time
import cv2
import numpy as np


def blur_background(input_path: str, output_path: str, blur_strength: int = 25) -> dict:
    """Blur the background of an image while keeping the subject sharp.
    
    Uses a simple edge-detection + GrabCut approach, falling back to
    center-weighted mask if detection fails.
    """
    start = time.time()
    img = cv2.imread(input_path)
    if img is None:
        raise ValueError(f"Could not read image: {input_path}")

    h, w = img.shape[:2]

    try:
        # Try rembg for accurate foreground mask
        from rembg import remove
        from PIL import Image
        import io

        pil_img = Image.open(input_path).convert("RGBA")
        result_pil = remove(pil_img)

        # Extract alpha channel as mask
        alpha = np.array(result_pil)[:, :, 3]
        mask = (alpha > 128).astype(np.uint8) * 255

    except Exception:
        # Fallback: center-weighted elliptical mask
        mask = np.zeros((h, w), dtype=np.uint8)
        center_x, center_y = w // 2, h // 2
        axes = (int(w * 0.35), int(h * 0.45))
        cv2.ellipse(mask, (center_x, center_y), axes, 0, 0, 360, 255, -1)
        mask = cv2.GaussianBlur(mask, (31, 31), 0)

    # Ensure blur_strength is odd
    if blur_strength % 2 == 0:
        blur_strength += 1

    # Create blurred version
    blurred = cv2.GaussianBlur(img, (blur_strength, blur_strength), 0)

    # Blend: foreground from original, background from blurred
    mask_3ch = cv2.merge([mask, mask, mask]).astype(np.float32) / 255.0
    result = (img.astype(np.float32) * mask_3ch + blurred.astype(np.float32) * (1 - mask_3ch))
    result = result.astype(np.uint8)

    cv2.imwrite(output_path, result)
    elapsed = round(time.time() - start, 2)

    return {
        "processing_time": elapsed,
        "blur_strength": blur_strength,
        "output_path": output_path,
    }
