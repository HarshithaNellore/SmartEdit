"""Object Tracking using OpenCV CSRT tracker.

Tracks a selected object (auto-detected or center region) across video frames
and outputs a video with bounding box overlay.
"""
import cv2
import time
from pathlib import Path


def track_object(input_path: str, output_path: str) -> dict:
    """Track the most prominent object in a video using CSRT tracker.

    Auto-selects a face or center region as the initial bounding box.
    Returns metadata dict with tracking details.
    """
    start = time.time()

    cap = cv2.VideoCapture(input_path)
    if not cap.isOpened():
        raise ValueError(f"Cannot open video: {input_path}")

    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    ret, first_frame = cap.read()
    if not ret:
        raise ValueError("Cannot read first frame")

    # Auto-detect initial bbox: try face detection first
    face_cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )
    gray = cv2.cvtColor(first_frame, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, 1.1, 5, minSize=(40, 40))

    if len(faces) > 0:
        areas = [fw * fh for (fx, fy, fw, fh) in faces]
        bbox = tuple(faces[areas.index(max(areas))])
        detection_method = "face_detection"
    else:
        # Fallback: track center 30% region
        bw, bh = int(w * 0.3), int(h * 0.3)
        bbox = (w // 2 - bw // 2, h // 2 - bh // 2, bw, bh)
        detection_method = "center_region"

    # Initialize tracker
    tracker = cv2.TrackerCSRT_create()
    tracker.init(first_frame, bbox)

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(output_path, fourcc, fps, (w, h))

    # Draw on first frame
    x, y, bw, bh = [int(v) for v in bbox]
    cv2.rectangle(first_frame, (x, y), (x + bw, y + bh), (0, 255, 0), 2)
    cv2.putText(first_frame, "Tracking", (x, y - 10),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
    writer.write(first_frame)

    tracked_frames = 1
    lost_count = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        success, box = tracker.update(frame)
        if success:
            x, y, bw, bh = [int(v) for v in box]
            cv2.rectangle(frame, (x, y), (x + bw, y + bh), (0, 255, 0), 2)
            cv2.putText(frame, "Tracking", (x, y - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
            tracked_frames += 1
        else:
            cv2.putText(frame, "Lost", (20, 40),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
            lost_count += 1

        writer.write(frame)

    cap.release()
    writer.release()

    elapsed = round(time.time() - start, 2)
    return {
        "processing_time_sec": elapsed,
        "detection_method": detection_method,
        "initial_bbox": {"x": bbox[0], "y": bbox[1], "w": bbox[2], "h": bbox[3]},
        "total_frames": total_frames,
        "tracked_frames": tracked_frames,
        "lost_frames": lost_count,
        "tracking_accuracy": round(tracked_frames / max(total_frames, 1) * 100, 1),
    }
