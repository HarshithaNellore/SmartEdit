"""Scene Detection using PySceneDetect.

Detects scene/cut changes in a video and returns timestamps.
"""
import time
from pathlib import Path


def detect_scenes(input_path: str, output_dir: str, threshold: float = 27.0) -> dict:
    """Detect scene changes in a video.

    Returns metadata dict with scene boundaries.
    """
    from scenedetect import open_video, SceneManager
    from scenedetect.detectors import ContentDetector

    start = time.time()

    video = open_video(input_path)
    scene_manager = SceneManager()
    scene_manager.add_detector(ContentDetector(threshold=threshold))

    scene_manager.detect_scenes(video)
    scene_list = scene_manager.get_scene_list()

    scenes = []
    for i, (scene_start, scene_end) in enumerate(scene_list):
        scenes.append({
            "index": i + 1,
            "start_time": round(scene_start.get_seconds(), 2),
            "end_time": round(scene_end.get_seconds(), 2),
            "start_timecode": str(scene_start),
            "end_timecode": str(scene_end),
            "duration_sec": round(scene_end.get_seconds() - scene_start.get_seconds(), 2),
        })

    elapsed = round(time.time() - start, 2)
    return {
        "processing_time_sec": elapsed,
        "total_scenes": len(scenes),
        "threshold_used": threshold,
        "scenes": scenes,
    }
