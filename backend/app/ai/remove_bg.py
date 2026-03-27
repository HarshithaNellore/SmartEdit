"""Background Removal using rembg (U-2-Net).

Removes backgrounds from images and produces a transparent PNG.
"""
import time
from pathlib import Path


def remove_background(input_path: str, output_path: str) -> dict:
    """Remove background from an image using rembg.

    Returns metadata dict with processing details.
    """
    from rembg import remove
    from PIL import Image

    start = time.time()

    inp = Image.open(input_path)
    original_size = inp.size

    result = remove(inp)

    # Save as PNG to preserve transparency
    out_path = Path(output_path)
    if out_path.suffix.lower() != ".png":
        out_path = out_path.with_suffix(".png")

    result.save(str(out_path))

    elapsed = round(time.time() - start, 2)
    return {
        "processing_time_sec": elapsed,
        "resolution": f"{original_size[0]}x{original_size[1]}",
        "output_format": "PNG (transparent)",
        "output_path": str(out_path),
    }
