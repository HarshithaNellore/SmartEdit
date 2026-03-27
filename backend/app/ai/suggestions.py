"""Smart Edit Suggestions — AI-powered video analysis.

Analyzes a video and produces structured JSON suggestions for cuts,
transitions, filters, and improvements.
"""
import cv2
import numpy as np
import time
from pathlib import Path


def generate_suggestions(input_path: str) -> dict:
    """Analyze a video and generate editing suggestions.

    Returns structured JSON with cuts, highlights, and suggestions.
    """
    start = time.time()

    cap = cv2.VideoCapture(input_path)
    if not cap.isOpened():
        raise ValueError(f"Cannot open video: {input_path}")

    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = total_frames / fps

    # Analyze brightness, contrast, and motion across sampled frames
    sample_interval = max(1, int(fps * 2))  # Every 2 seconds
    brightness_values = []
    contrast_values = []
    motion_values = []
    prev_gray = None

    frame_idx = 0
    while True:
        ret, frame = cap.read()
        if not ret:
            break

        if frame_idx % sample_interval == 0:
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            small = cv2.resize(gray, (160, 120))

            brightness_values.append((frame_idx / fps, float(np.mean(small))))
            contrast_values.append((frame_idx / fps, float(np.std(small))))

            if prev_gray is not None:
                diff = cv2.absdiff(prev_gray, small)
                motion_values.append((frame_idx / fps, float(np.mean(diff))))

            prev_gray = small

        frame_idx += 1

    cap.release()

    # Generate suggestions based on analysis
    suggestions = []
    cuts = []
    highlights = []

    # Brightness suggestions
    if brightness_values:
        avg_brightness = np.mean([b for _, b in brightness_values])
        if avg_brightness < 80:
            suggestions.append({
                "type": "filter",
                "suggestion": "Video appears dark. Consider increasing brightness by 15-20%.",
                "confidence": 0.85,
            })
        elif avg_brightness > 200:
            suggestions.append({
                "type": "filter",
                "suggestion": "Video appears overexposed. Consider reducing brightness.",
                "confidence": 0.8,
            })

    # Contrast suggestions
    if contrast_values:
        avg_contrast = np.mean([c for _, c in contrast_values])
        if avg_contrast < 30:
            suggestions.append({
                "type": "filter",
                "suggestion": "Low contrast detected. Apply a contrast boost filter for more vivid output.",
                "confidence": 0.75,
            })

    # Motion-based cut suggestions
    if motion_values:
        max_motion = max(m for _, m in motion_values) or 1
        for t, m in motion_values:
            normalized = m / max_motion
            if normalized > 0.7:
                cuts.append({
                    "timestamp_sec": round(t, 2),
                    "reason": "High motion detected — potential scene transition point",
                    "score": round(normalized, 2),
                })
            if normalized > 0.8:
                highlights.append({
                    "timestamp_sec": round(t, 2),
                    "reason": "Peak action moment",
                    "score": round(normalized, 2),
                })

    # General suggestions
    if duration > 60:
        suggestions.append({
            "type": "edit",
            "suggestion": f"Video is {round(duration)}s long. Consider trimming to under 60s for social media.",
            "confidence": 0.7,
        })

    if w < 1080:
        suggestions.append({
            "type": "quality",
            "suggestion": f"Resolution is {w}x{h}. Consider AI upscaling for sharper output.",
            "confidence": 0.65,
        })

    aspect = round(w / h, 2) if h > 0 else 0
    if 1.7 < aspect < 1.8:
        suggestions.append({
            "type": "reframe",
            "suggestion": "Video is 16:9. Use Smart Reframe for vertical (9:16) social media crops.",
            "confidence": 0.8,
        })

    # Always add a transition suggestion if there are cuts
    if len(cuts) >= 2:
        suggestions.append({
            "type": "transition",
            "suggestion": f"Found {len(cuts)} potential cut points. Add crossfade transitions for smoother flow.",
            "confidence": 0.7,
        })

    elapsed = round(time.time() - start, 2)
    return {
        "processing_time_sec": elapsed,
        "video_info": {
            "duration_sec": round(duration, 2),
            "resolution": f"{w}x{h}",
            "fps": round(fps, 1),
            "total_frames": total_frames,
        },
        "cuts": cuts[:10],
        "highlights": highlights[:5],
        "suggestions": suggestions,
    }
