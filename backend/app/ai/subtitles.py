"""Auto Subtitle Generation using faster-whisper.

Extracts audio from video, transcribes it, and generates an SRT file.
"""
import subprocess
import time
import os
from pathlib import Path


def _extract_audio(video_path: str, audio_path: str):
    """Extract audio from video using ffmpeg."""
    cmd = [
        "ffmpeg", "-y", "-i", video_path,
        "-vn", "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1",
        audio_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg audio extraction failed: {result.stderr[:500]}")


def _format_timestamp(seconds: float) -> str:
    """Convert seconds to SRT timestamp format HH:MM:SS,mmm."""
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    ms = int((seconds - int(seconds)) * 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def generate_subtitles(input_path: str, output_dir: str) -> dict:
    """Generate SRT subtitles from a video file.

    Returns metadata dict with subtitle content and paths.
    """
    from faster_whisper import WhisperModel

    start = time.time()
    input_p = Path(input_path)
    out_dir = Path(output_dir)

    # Step 1: Extract audio
    audio_path = str(out_dir / f"{input_p.stem}_audio.wav")
    _extract_audio(input_path, audio_path)

    # Step 2: Transcribe with faster-whisper (use 'base' model for speed) and translate to English
    model = WhisperModel("base", device="cpu", compute_type="int8")
    segments, info = model.transcribe(audio_path, beam_size=5, task="translate")

    # Step 3: Build SRT
    srt_lines = []
    subtitle_entries = []
    for i, seg in enumerate(segments, 1):
        start_ts = _format_timestamp(seg.start)
        end_ts = _format_timestamp(seg.end)
        text = seg.text.strip()
        srt_lines.append(f"{i}")
        srt_lines.append(f"{start_ts} --> {end_ts}")
        srt_lines.append(text)
        srt_lines.append("")
        subtitle_entries.append({
            "index": i,
            "start": round(seg.start, 2),
            "end": round(seg.end, 2),
            "text": text,
        })

    srt_content = "\n".join(srt_lines)
    srt_path = str(out_dir / f"{input_p.stem}.srt")
    with open(srt_path, "w", encoding="utf-8") as f:
        f.write(srt_content)

    # Clean up temp audio
    try:
        os.remove(audio_path)
    except OSError:
        pass

    elapsed = round(time.time() - start, 2)
    return {
        "processing_time_sec": elapsed,
        "language": info.language,
        "language_probability": round(info.language_probability, 2),
        "total_segments": len(subtitle_entries),
        "srt_path": srt_path,
        "subtitles": subtitle_entries,
        "srt_content": srt_content,
    }
