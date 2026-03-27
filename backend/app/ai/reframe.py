"""Smart Auto-Reframe using OpenCV face/object detection.

Dynamically crops video to keep the subject centered for a target aspect ratio.
"""
import cv2
import time
import subprocess
from pathlib import Path


def reframe_video(input_path: str, output_path: str, aspect_ratio: str = "9:16") -> dict:
    """Reframe a video to a target aspect ratio using face detection.

    Returns metadata dict with processing details.
    """
    start = time.time()

    # Parse target aspect ratio
    ar_map = {"9:16": 9 / 16, "1:1": 1.0, "16:9": 16 / 9}
    target_ar = ar_map.get(aspect_ratio, 9 / 16)

    cap = cv2.VideoCapture(input_path)
    if not cap.isOpened():
        raise ValueError(f"Cannot open video: {input_path}")

    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    orig_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    orig_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    # Calculate output dimensions
    if target_ar < orig_w / orig_h:
        out_h = orig_h
        out_w = int(orig_h * target_ar)
    else:
        out_w = orig_w
        out_h = int(orig_w / target_ar)

    # Load face detector
    face_cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(output_path, fourcc, fps, (out_w, out_h))

    last_cx, last_cy = orig_w // 2, orig_h // 2
    smooth_alpha = 0.15  # Smoothing factor

    frame_idx = 0
    while True:
        ret, frame = cap.read()
        if not ret:
            break

        # Detect faces every 5 frames for performance
        if frame_idx % 5 == 0:
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = face_cascade.detectMultiScale(gray, 1.1, 5, minSize=(40, 40))
            if len(faces) > 0:
                # Use the largest face
                areas = [w * h for (x, y, w, h) in faces]
                largest = faces[areas.index(max(areas))]
                fx, fy, fw, fh = largest
                target_cx = fx + fw // 2
                target_cy = fy + fh // 2
                # Smooth the center point
                last_cx = int(last_cx + smooth_alpha * (target_cx - last_cx))
                last_cy = int(last_cy + smooth_alpha * (target_cy - last_cy))

        # Compute crop region centered on detected subject
        x1 = max(0, min(last_cx - out_w // 2, orig_w - out_w))
        y1 = max(0, min(last_cy - out_h // 2, orig_h - out_h))

        cropped = frame[y1:y1 + out_h, x1:x1 + out_w]
        if cropped.shape[1] != out_w or cropped.shape[0] != out_h:
            cropped = cv2.resize(cropped, (out_w, out_h))

        writer.write(cropped)
        frame_idx += 1

    cap.release()
    writer.release()

    elapsed = round(time.time() - start, 2)
    return {
        "processing_time_sec": elapsed,
        "original_resolution": f"{orig_w}x{orig_h}",
        "output_resolution": f"{out_w}x{out_h}",
        "aspect_ratio": aspect_ratio,
        "total_frames": total_frames,
    }
