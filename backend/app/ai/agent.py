"""AI Agent — Smart natural language → tool pipeline with NEVER-FAIL logic.

Two parsing modes:
  1. LLM mode (Gemini) — handles ANY natural language, maps to closest tools
  2. Keyword fallback — regex-based detection

NEVER-FAIL RULE: If nothing matches, default to enhance + color correction.
"""
import os
import re
import json
import time
import uuid
import traceback
from pathlib import Path
from typing import List, Dict, Any

# ═══════════════════════════════════════════════════
#  SUPPORTED TOOLS (10 tools)
# ═══════════════════════════════════════════════════
SUPPORTED_TOOLS = {
    "enhance": {
        "description": "Enhance photo quality (lighting, sharpness, colors, denoise)",
        "media": "image",
        "output_ext": ".jpg",
    },
    "remove_background": {
        "description": "Remove background from image, make transparent PNG",
        "media": "image",
        "output_ext": ".png",
    },
    "flip": {
        "description": "Flip/mirror image horizontally or vertically",
        "media": "image",
        "output_ext": ".jpg",
    },
    "rotate": {
        "description": "Rotate image by degrees (90, 180, 270, or any angle)",
        "media": "image",
        "output_ext": ".jpg",
    },
    "color_grade": {
        "description": "Adjust brightness, contrast, saturation, warmth",
        "media": "image",
        "output_ext": ".jpg",
    },
    "blur_background": {
        "description": "Blur background while keeping subject sharp (portrait mode / bokeh)",
        "media": "image",
        "output_ext": ".jpg",
    },

    "reframe": {
        "description": "Smart crop/reframe video for 9:16, 1:1, 16:9 etc.",
        "media": "video",
        "output_ext": ".mp4",
    },
    "highlights": {
        "description": "Find highlight moments in video based on motion/audio",
        "media": "video",
        "output_ext": None,
    },
    "suggestions": {
        "description": "Get AI edit suggestions for media",
        "media": "any",
        "output_ext": None,
    },
}

# ═══════════════════════════════════════════════════
#  KEYWORD MAP (expanded)
# ═══════════════════════════════════════════════════
_KEYWORD_MAP = {
    # enhance
    "enhance":            "enhance",
    "improve":            "enhance",
    "fix":                "enhance",
    "brighten":           "enhance",
    "sharpen":            "enhance",
    "denoise":            "enhance",
    "better quality":     "enhance",
    "hd":                 "enhance",
    "clear":              "enhance",
    "fix lighting":       "enhance",
    # remove bg
    "remove background":  "remove_background",
    "remove bg":          "remove_background",
    "background removal": "remove_background",
    "cut out":            "remove_background",
    "transparent":        "remove_background",
    "no background":      "remove_background",
    "isolate subject":    "remove_background",
    # flip
    "flip":               "flip",
    "mirror":             "flip",
    "reverse":            "flip",
    "opposite direction": "flip",
    "change direction":   "flip",
    "look left":          "flip",
    "look right":         "flip",
    "face other way":     "flip",
    "turn around":        "flip",
    # rotate
    "rotate":             "rotate",
    "turn":               "rotate",
    "tilt":               "rotate",
    "sideways":           "rotate",
    "upside down":        "rotate",
    # color grading
    "color":              "color_grade",
    "brightness":         "color_grade",
    "contrast":           "color_grade",
    "saturation":         "color_grade",
    "warm":               "color_grade",
    "cool tone":          "color_grade",
    "color correct":      "color_grade",
    "color grade":        "color_grade",
    "vibrant":            "color_grade",
    "vivid":              "color_grade",
    "muted":              "color_grade",
    "desaturate":         "color_grade",
    # blur background
    "blur background":    "blur_background",
    "blur bg":            "blur_background",
    "bokeh":              "blur_background",
    "portrait mode":      "blur_background",
    "depth of field":     "blur_background",
    "background blur":    "blur_background",
    "soft background":    "blur_background",

    # reframe
    "reframe":            "reframe",
    "crop for":           "reframe",
    "vertical video":     "reframe",
    "9:16":               "reframe",
    "1:1":                "reframe",
    "instagram":          "reframe",
    "tiktok":             "reframe",
    "reels":              "reframe",
    # highlights
    "highlight":          "highlights",
    "best moments":       "highlights",
    "best parts":         "highlights",
    # suggestions
    "suggest":            "suggestions",
    "recommendation":     "suggestions",
    "tips":               "suggestions",
    "what should i":      "suggestions",
}


# ═══════════════════════════════════════════════════
#  PROMPT PARSING — LLM (Gemini)
# ═══════════════════════════════════════════════════

def parse_prompt_with_llm(prompt: str) -> Dict[str, Any]:
    """Use Gemini to convert ANY natural language into tool steps.
    
    Returns dict with 'steps' list and 'intent' explanation.
    NEVER returns empty — maps unknown requests to closest tools.
    """
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("NO_API_KEY")

    import google.generativeai as genai
    genai.configure(api_key=api_key)

    tool_list = ", ".join(SUPPORTED_TOOLS.keys())
    tool_descs = "\n".join(f"  - {k}: {v['description']}" for k, v in SUPPORTED_TOOLS.items())

    system_prompt = f"""You are an AI media editing assistant. Given ANY user editing request, 
you MUST return a JSON object with tool steps to execute.

AVAILABLE TOOLS:
{tool_descs}

TOOL PARAMETERS:
- flip: {{"direction": "horizontal" | "vertical"}}
- rotate: {{"angle": number}} (degrees)
- color_grade: {{"brightness": -100 to 100, "contrast": -100 to 100, "saturation": -100 to 100, "warmth": -50 to 50}}
- blur_background: {{"blur_strength": 15-51}}
- reframe: {{"aspect_ratio": "9:16" | "1:1" | "16:9"}}

CRITICAL RULES:
1. ALWAYS return valid JSON, never markdown.
2. NEVER return empty steps. If the request seems impossible, MAP IT to the closest tools.
3. For requests like "change head direction" or "make person look left" → use flip + enhance.
4. For generative/impossible requests → use enhance + color_grade as default, and explain in "fallback" field.
5. ALWAYS try to produce a visual change.

OUTPUT FORMAT (strict JSON, no code fences):
{{
  "steps": [
    {{"tool": "tool_name", "params": {{}}}}
  ],
  "intent": "short explanation of what will happen",
  "fallback": null
}}

If the request is truly impossible but you've mapped to closest tools, set:
"fallback": "explanation of what was done instead"

EXAMPLES:
- "change head direction" → steps: [flip horizontal, enhance], intent: "Mirroring the image to change direction"
- "make it look professional" → steps: [enhance, color_grade with +20 contrast +10 saturation], intent: "Professional look via enhancement and color correction"
- "make person younger" → steps: [enhance, color_grade with warm tone], fallback: "Age modification requires generative AI; applied enhancement and warmth instead"
"""

    model = genai.GenerativeModel("gemini-2.0-flash")
    response = model.generate_content(
        [system_prompt, f"User prompt: {prompt}"],
        generation_config=genai.types.GenerationConfig(
            temperature=0.1,
            max_output_tokens=800,
        ),
    )

    text = response.text.strip()
    # Strip markdown fences if present
    if text.startswith("```"):
        text = re.sub(r"^```\w*\n?", "", text)
        text = re.sub(r"\n?```$", "", text)
    text = text.strip()

    parsed = json.loads(text)

    steps = parsed.get("steps", [])
    intent = parsed.get("intent", "")
    fallback = parsed.get("fallback")

    # Validate steps
    validated = []
    for s in steps:
        tool = s.get("tool", "").strip()
        if tool in SUPPORTED_TOOLS:
            validated.append({"tool": tool, "params": s.get("params", {})})

    # NEVER-FAIL: if LLM returned empty or all invalid, default to enhance
    if not validated:
        validated = [
            {"tool": "enhance", "params": {}},
            {"tool": "color_grade", "params": {"brightness": 10, "contrast": 15, "saturation": 10}},
        ]
        if not fallback:
            fallback = "Could not map to specific tools; applied enhancement and color correction."

    return {
        "steps": validated,
        "intent": intent,
        "fallback": fallback,
    }


# ═══════════════════════════════════════════════════
#  PROMPT PARSING — Keyword fallback
# ═══════════════════════════════════════════════════

def parse_prompt_keywords(prompt: str) -> Dict[str, Any]:
    """Fallback: extract tool steps using keyword matching."""
    prompt_lower = prompt.lower()
    found_tools = []
    seen = set()

    sorted_keywords = sorted(_KEYWORD_MAP.keys(), key=len, reverse=True)

    for keyword in sorted_keywords:
        if keyword in prompt_lower:
            tool = _KEYWORD_MAP[keyword]
            if tool not in seen:
                seen.add(tool)
                params = {}
                # Try to extract params from prompt
                if tool == "flip":
                    if "vertical" in prompt_lower:
                        params["direction"] = "vertical"
                    else:
                        params["direction"] = "horizontal"
                elif tool == "rotate":
                    angle_match = re.search(r'(\d+)\s*(?:deg|°|degree)', prompt_lower)
                    params["angle"] = float(angle_match.group(1)) if angle_match else 90
                found_tools.append({"tool": tool, "params": params})

    return {
        "steps": found_tools,
        "intent": f"Matched keywords: {', '.join(seen)}" if found_tools else "",
        "fallback": None,
    }


# ═══════════════════════════════════════════════════
#  MAIN PARSER — LLM → Keywords → Default
# ═══════════════════════════════════════════════════

def parse_prompt(prompt: str) -> Dict[str, Any]:
    """Parse prompt. Tries LLM → keywords → default. NEVER returns empty steps."""

    # 1. Try LLM
    try:
        result = parse_prompt_with_llm(prompt)
        if result["steps"]:
            return result
    except RuntimeError as e:
        if "NO_API_KEY" not in str(e):
            traceback.print_exc()
    except Exception:
        traceback.print_exc()

    # 2. Try keyword matching
    result = parse_prompt_keywords(prompt)
    if result["steps"]:
        return result

    # 3. NEVER-FAIL DEFAULT: enhance + color correction
    return {
        "steps": [
            {"tool": "enhance", "params": {}},
            {"tool": "color_grade", "params": {"brightness": 10, "contrast": 15, "saturation": 10}},
        ],
        "intent": "Applied default enhancement and color correction",
        "fallback": "Could not parse specific instructions; applied general enhancement to improve the image.",
    }


# ═══════════════════════════════════════════════════
#  EXECUTION ENGINE
# ═══════════════════════════════════════════════════

def _run_tool(tool_name: str, input_path: str, output_dir: str, params: dict) -> Dict[str, Any]:
    """Execute a single tool and return result."""
    output_ext = SUPPORTED_TOOLS[tool_name].get("output_ext")
    output_path = os.path.join(output_dir, f"{uuid.uuid4().hex}{output_ext}") if output_ext else None

    if tool_name == "enhance":
        from .photo_enhance import enhance_photo
        meta = enhance_photo(input_path, output_path)
        return {"output_path": output_path, "metadata": meta}

    elif tool_name == "remove_background":
        from .remove_bg import remove_background
        meta = remove_background(input_path, output_path)
        return {"output_path": meta.get("output_path", output_path), "metadata": meta}

    elif tool_name == "flip":
        from .flip import flip_image
        direction = params.get("direction", "horizontal")
        meta = flip_image(input_path, output_path, direction)
        return {"output_path": output_path, "metadata": meta}

    elif tool_name == "rotate":
        from .rotate import rotate_image
        angle = float(params.get("angle", 90))
        meta = rotate_image(input_path, output_path, angle)
        return {"output_path": output_path, "metadata": meta}

    elif tool_name == "color_grade":
        from .color_grade import color_grade
        meta = color_grade(
            input_path, output_path,
            brightness=float(params.get("brightness", 0)),
            contrast=float(params.get("contrast", 0)),
            saturation=float(params.get("saturation", 0)),
            warmth=float(params.get("warmth", 0)),
        )
        return {"output_path": output_path, "metadata": meta}

    elif tool_name == "blur_background":
        from .blur_bg import blur_background
        strength = int(params.get("blur_strength", 25))
        meta = blur_background(input_path, output_path, strength)
        return {"output_path": output_path, "metadata": meta}



    elif tool_name == "reframe":
        from .reframe import reframe_video
        aspect = params.get("aspect_ratio", "9:16")
        meta = reframe_video(input_path, output_path, aspect)
        return {"output_path": output_path, "metadata": meta}

    elif tool_name == "highlights":
        from .highlights import detect_highlights
        meta = detect_highlights(input_path, output_dir)
        return {"output_path": None, "metadata": meta}

    elif tool_name == "suggestions":
        from .suggestions import generate_suggestions
        meta = generate_suggestions(input_path)
        return {"output_path": None, "metadata": meta}

    else:
        raise ValueError(f"Unknown tool: {tool_name}")


def execute_pipeline(input_path: str, steps: List[Dict[str, Any]], output_dir: str) -> Dict[str, Any]:
    """Execute tool steps sequentially. Each output feeds into next input."""
    pipeline_start = time.time()
    current_input = input_path
    step_logs = []
    final_output_path = None

    for i, step in enumerate(steps):
        tool_name = step["tool"]
        params = step.get("params", {})

        step_start = time.time()
        try:
            result = _run_tool(tool_name, current_input, output_dir, params)
            elapsed = round(time.time() - step_start, 2)

            step_log = {
                "step": i + 1,
                "tool": tool_name,
                "status": "success",
                "processing_time": elapsed,
                "has_output": False,
            }

            if result["output_path"] and os.path.exists(result["output_path"]):
                current_input = result["output_path"]
                final_output_path = result["output_path"]
                step_log["has_output"] = True

            step_log["metadata"] = result.get("metadata", {})
            step_logs.append(step_log)

        except Exception as e:
            traceback.print_exc()
            step_logs.append({
                "step": i + 1,
                "tool": tool_name,
                "status": "failed",
                "error": str(e),
            })

    total_time = round(time.time() - pipeline_start, 2)

    output_url = None
    if final_output_path and os.path.exists(final_output_path):
        output_url = f"/processed/{Path(final_output_path).name}"

    return {
        "status": "success",
        "output_url": output_url,
        "total_processing_time": total_time,
        "steps_executed": len(steps),
        "steps_succeeded": sum(1 for s in step_logs if s["status"] == "success"),
        "step_logs": step_logs,
    }
