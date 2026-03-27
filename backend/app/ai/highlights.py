"""Highlight Detection using audio peaks and motion analysis.

Analyzes a video for audio intensity spikes and visual motion changes
to identify the most interesting moments.
"""
import cv2
import subprocess
import numpy as np
import time
import wave
import struct
from pathlib import Path


def _extract_audio_wav(video_path: str, audio_path: str):
    """Extract audio as WAV for analysis. Mutes errors if ffmpeg is missing."""
    import shutil
    if not shutil.which("ffmpeg"):
        return
        
    cmd = [
        "ffmpeg", "-y", "-i", video_path,
        "-vn", "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1",
        audio_path,
    ]
    try:
        subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except Exception:
        pass


def _analyze_audio_peaks(audio_path: str, window_sec: float = 1.0) -> list:
    """Analyze audio for volume peaks. Returns list of (time_sec, intensity)."""
    try:
        wf = wave.open(audio_path, "r")
    except Exception:
        return []

    sr = wf.getframerate()
    n_frames = wf.getnframes()
    raw = wf.readframes(n_frames)
    wf.close()

    samples = np.array(struct.unpack(f"<{n_frames}h", raw), dtype=np.float32)
    samples = np.abs(samples) / 32768.0  # Normalize

    window_size = int(sr * window_sec)
    peaks = []
    for i in range(0, len(samples) - window_size, window_size):
        chunk = samples[i:i + window_size]
        intensity = float(np.mean(chunk))
        t = i / sr
        peaks.append((round(t, 2), round(intensity, 4)))

    return peaks


def detect_highlights(input_path: str, output_dir: str, top_n: int = 5) -> dict:
    """Detect highlights in a video using audio peaks and motion analysis.

    Returns metadata dict with highlight timestamps.
    """
    start = time.time()

    cap = cv2.VideoCapture(input_path)
    if not cap.isOpened():
        raise ValueError(f"Cannot open video: {input_path}")

    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = total_frames / fps

    # 1. Motion analysis (frame diff)
    motion_scores = []
    prev_gray = None
    frame_idx = 0
    sample_interval = max(1, int(fps))  # Sample once per second

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        if frame_idx % sample_interval == 0:
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            gray = cv2.resize(gray, (320, 240))
            if prev_gray is not None:
                diff = cv2.absdiff(prev_gray, gray)
                score = float(np.mean(diff))
                t = frame_idx / fps
                motion_scores.append((round(t, 2), round(score, 4)))
            prev_gray = gray

        frame_idx += 1

    cap.release()

    # 2. Audio intensity analysis
    out_dir = Path(output_dir)
    audio_path = str(out_dir / "temp_highlight_audio.wav")
    _extract_audio_wav(input_path, audio_path)
    audio_peaks = _analyze_audio_peaks(audio_path)

    # Clean up temp audio
    import os
    try:
        os.remove(audio_path)
    except OSError:
        pass

    # 3. Combine scores: normalize and merge
    combined = {}
    if motion_scores:
        max_motion = max(s for _, s in motion_scores) or 1
        for t, s in motion_scores:
            combined[t] = combined.get(t, 0) + (s / max_motion) * 0.6

    if audio_peaks:
        max_audio = max(s for _, s in audio_peaks) or 1
        for t, s in audio_peaks:
            rounded_t = round(t)
            combined[rounded_t] = combined.get(rounded_t, 0) + (s / max_audio) * 0.4

    # Sort by score and pick top N
    sorted_highlights = sorted(combined.items(), key=lambda x: x[1], reverse=True)
    top_highlights = sorted_highlights[:top_n]

    highlights = []
    for i, (t, score) in enumerate(sorted(top_highlights, key=lambda x: x[0])):
        highlights.append({
            "index": i + 1,
            "timestamp_sec": t,
            "score": round(score, 3),
            "clip_start": max(0, t - 2),
            "clip_end": min(duration, t + 3),
        })

    elapsed = round(time.time() - start, 2)
    return {
        "processing_time_sec": elapsed,
        "video_duration_sec": round(duration, 2),
        "total_highlights": len(highlights),
        "highlights": highlights,
    }
