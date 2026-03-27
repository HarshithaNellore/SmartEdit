"""AI Feature API Routes for SmartCut.

Provides 8 endpoints for real AI-powered media processing.
All endpoints accept file uploads and return processed results.
"""
import os
import uuid
import time
import traceback
from pathlib import Path
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse

router = APIRouter(prefix="/api/ai", tags=["AI Features"])

# Output directory for processed files
PROCESSED_DIR = Path(__file__).parent.parent.parent / "processed"
UPLOAD_DIR = Path(__file__).parent.parent.parent / "uploads"
PROCESSED_DIR.mkdir(exist_ok=True)
UPLOAD_DIR.mkdir(exist_ok=True)


def _save_upload(file: UploadFile) -> str:
    """Save uploaded file and return its path."""
    ext = Path(file.filename or "file").suffix or ".bin"
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = UPLOAD_DIR / filename
    with open(filepath, "wb") as f:
        content = file.file.read()
        f.write(content)
    return str(filepath)


def _output_path(suffix: str) -> str:
    """Generate a unique output path."""
    return str(PROCESSED_DIR / f"{uuid.uuid4().hex}{suffix}")


# ─────────────────────────────────────────────
# 1. Photo Enhancement
# ─────────────────────────────────────────────
@router.post("/photo-enhance")
async def photo_enhance(file: UploadFile = File(...)):
    try:
        input_path = _save_upload(file)
        output_path = _output_path(".jpg")

        from ..ai.photo_enhance import enhance_photo
        metadata = enhance_photo(input_path, output_path)

        output_filename = Path(output_path).name
        return JSONResponse({
            "status": "success",
            "output_url": f"/processed/{output_filename}",
            "metadata": metadata,
        })
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ─────────────────────────────────────────────
# 2. Background Removal
# ─────────────────────────────────────────────
@router.post("/remove-bg")
async def remove_bg(file: UploadFile = File(...)):
    try:
        input_path = _save_upload(file)
        output_path = _output_path(".png")

        from ..ai.remove_bg import remove_background
        metadata = remove_background(input_path, output_path)

        # rembg may change extension to .png
        actual_output = metadata.get("output_path", output_path)
        output_filename = Path(actual_output).name
        return JSONResponse({
            "status": "success",
            "output_url": f"/processed/{output_filename}",
            "metadata": metadata,
        })
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ─────────────────────────────────────────────
# 3. Auto Subtitle Generation
# ─────────────────────────────────────────────
@router.post("/subtitles")
async def auto_subtitles(file: UploadFile = File(...)):
    try:
        input_path = _save_upload(file)

        from ..ai.subtitles import generate_subtitles
        metadata = generate_subtitles(input_path, str(PROCESSED_DIR))

        srt_filename = Path(metadata["srt_path"]).name
        return JSONResponse({
            "status": "success",
            "output_url": f"/processed/{srt_filename}",
            "metadata": metadata,
        })
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))



# ─────────────────────────────────────────────
# 5. Smart Auto-Reframe
# ─────────────────────────────────────────────
@router.post("/reframe")
async def reframe(
    file: UploadFile = File(...),
    aspect_ratio: str = Form("9:16"),
):
    try:
        input_path = _save_upload(file)
        output_path = _output_path(".mp4")

        from ..ai.reframe import reframe_video
        metadata = reframe_video(input_path, output_path, aspect_ratio)

        output_filename = Path(output_path).name
        return JSONResponse({
            "status": "success",
            "output_url": f"/processed/{output_filename}",
            "metadata": metadata,
        })
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ─────────────────────────────────────────────
# 6. Object Tracking
# ─────────────────────────────────────────────
@router.post("/track")
async def track(file: UploadFile = File(...)):
    try:
        input_path = _save_upload(file)
        output_path = _output_path(".mp4")

        from ..ai.track import track_object
        metadata = track_object(input_path, output_path)

        output_filename = Path(output_path).name
        return JSONResponse({
            "status": "success",
            "output_url": f"/processed/{output_filename}",
            "metadata": metadata,
        })
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ─────────────────────────────────────────────
# 7. Highlight Detection
# ─────────────────────────────────────────────
@router.post("/highlights")
async def highlights(file: UploadFile = File(...)):
    try:
        input_path = _save_upload(file)

        from ..ai.highlights import detect_highlights
        metadata = detect_highlights(input_path, str(PROCESSED_DIR))

        return JSONResponse({
            "status": "success",
            "output_url": None,
            "metadata": metadata,
        })
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ─────────────────────────────────────────────
# 8. Smart Edit Suggestions
# ─────────────────────────────────────────────
@router.post("/suggestions")
async def suggestions(file: UploadFile = File(...)):
    try:
        input_path = _save_upload(file)

        from ..ai.suggestions import generate_suggestions
        metadata = generate_suggestions(input_path)

        return JSONResponse({
            "status": "success",
            "output_url": None,
            "metadata": metadata,
        })
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ─────────────────────────────────────────────
# 9. AI Agent — Natural Language Editing (Never-Fail)
# ─────────────────────────────────────────────
@router.post("/agent-edit")
async def agent_edit(
    file: UploadFile = File(...),
    prompt: str = Form(...),
):
    """AI Agent: parse ANY natural language prompt and ALWAYS return output."""
    try:
        input_path = _save_upload(file)

        from ..ai.agent import parse_prompt, execute_pipeline

        # 1. Parse prompt — NEVER returns empty steps
        parsed = parse_prompt(prompt)
        steps = parsed["steps"]
        intent = parsed.get("intent", "")
        fallback = parsed.get("fallback")

        # 2. Execute pipeline
        result = execute_pipeline(input_path, steps, str(PROCESSED_DIR))

        return JSONResponse({
            "status": result["status"],
            "output_url": result.get("output_url"),
            "total_processing_time": result["total_processing_time"],
            "steps_executed": result["steps_executed"],
            "steps_succeeded": result["steps_succeeded"],
            "step_logs": result["step_logs"],
            "parsed_steps": [s["tool"] for s in steps],
            "intent": intent,
            "fallback": fallback,
            "message": fallback or f"Applied {result['steps_succeeded']} edits successfully",
        })
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

