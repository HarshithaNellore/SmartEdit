"""Flip image horizontally or vertically using OpenCV."""
import time
import cv2


def flip_image(input_path: str, output_path: str, direction: str = "horizontal") -> dict:
    """Flip an image.
    
    Args:
        direction: 'horizontal' (mirror), 'vertical', or 'both'
    """
    start = time.time()
    img = cv2.imread(input_path)
    if img is None:
        raise ValueError(f"Could not read image: {input_path}")

    if direction == "horizontal":
        flipped = cv2.flip(img, 1)
    elif direction == "vertical":
        flipped = cv2.flip(img, 0)
    elif direction == "both":
        flipped = cv2.flip(img, -1)
    else:
        flipped = cv2.flip(img, 1)  # default horizontal

    cv2.imwrite(output_path, flipped)
    elapsed = round(time.time() - start, 2)

    return {
        "processing_time": elapsed,
        "direction": direction,
        "output_path": output_path,
    }
