"""Rotate image by arbitrary degrees using OpenCV."""
import time
import cv2


def rotate_image(input_path: str, output_path: str, angle: float = 90) -> dict:
    """Rotate an image by the given angle (degrees, counterclockwise).
    
    Common angles: 90, 180, 270, or any float.
    """
    start = time.time()
    img = cv2.imread(input_path)
    if img is None:
        raise ValueError(f"Could not read image: {input_path}")

    h, w = img.shape[:2]
    center = (w // 2, h // 2)

    # For 90/180/270 use fast rotation, otherwise affine
    if angle == 90:
        rotated = cv2.rotate(img, cv2.ROTATE_90_COUNTERCLOCKWISE)
    elif angle == 180:
        rotated = cv2.rotate(img, cv2.ROTATE_180)
    elif angle == 270:
        rotated = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    else:
        matrix = cv2.getRotationMatrix2D(center, angle, 1.0)
        rotated = cv2.warpAffine(img, matrix, (w, h), borderMode=cv2.BORDER_REPLICATE)

    cv2.imwrite(output_path, rotated)
    elapsed = round(time.time() - start, 2)

    return {
        "processing_time": elapsed,
        "angle": angle,
        "output_path": output_path,
    }
