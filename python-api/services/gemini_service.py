"""
Gemini Service - AI-powered content generation
Uses gemini-1.5-flash (free tier: 15 req/min, 1M tokens/day)
"""
import os
import logging

logger = logging.getLogger(__name__)

try:
    import google.generativeai as genai
    genai.configure(api_key=os.getenv("GEMINI_API_KEY", ""))
    model = genai.GenerativeModel("gemini-1.5-flash")
    GEMINI_AVAILABLE = True
except Exception as e:
    logger.warning("Gemini not available: %s", e)
    GEMINI_AVAILABLE = False


def _safe_generate(prompt: str, fallback: str) -> str:
    """Call Gemini; return fallback if not configured or rate-limited."""
    if not GEMINI_AVAILABLE or not os.getenv("GEMINI_API_KEY"):
        return fallback
    try:
        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        logger.error("Gemini generation error: %s", e)
        return fallback


def generate_fresh_brainer(slide_text: str) -> str:
    """Generate ONE clarifying question (≤2 sentences) based on slide content."""
    prompt = f"""
Based on this lecture content, generate ONE clarifying question (under 2 sentences)
to help confused students refocus. Be specific to the content, not generic.
SLIDE CONTENT: {slide_text}
Return only the question itself, no preamble.
"""
    fallback = "Can you clarify the main concept we just covered and how it applies to the example?"
    return _safe_generate(prompt, fallback)


def generate_smart_notes(transcript: str, distraction_timestamps: list[str]) -> str:
    """
    Generate concise markdown study notes from transcript.
    Sections taught during distraction times get a ✱ marker.
    """
    ts = ", ".join(distraction_timestamps) if distraction_timestamps else "none"
    prompt = f"""
You are a study assistant. Generate concise study notes from this lecture transcript.
Format as clean markdown with headers and bullet points.
For any content taught at timestamps [{ts}] when the student was distracted,
start that section's heading or paragraph with the ✱ character at the very beginning of the line
(e.g. "✱ ## Section Title" or "✱ This topic was...") and add a plain-English re-explanation below it.

TRANSCRIPT:
{transcript}

Return only clean markdown. No preamble. Start with a ## header.
"""
    fallback = f"## Lecture Notes\n\n*Transcript unavailable — please review the recorded lecture.*\n"
    return _safe_generate(prompt, fallback)


def generate_intervention_plan(student_emotion_history: str) -> str:
    """Generate exactly 3 numbered intervention steps for a lecturer based on student's emotion pattern."""
    prompt = f"""
You are an academic advisor. A student has shown this emotion pattern across lectures:
{student_emotion_history}

Suggest exactly 3 concrete, actionable steps the LECTURER can take to help this student.
Each step should be specific and practical.
Return as a numbered markdown list (1. ... 2. ... 3. ...).
No preamble, no conclusion — just the 3 items.
"""
    fallback = (
        "1. Schedule a one-on-one check-in to understand the student's specific challenges.\n"
        "2. Provide supplementary materials or recorded explanations for the sessions with highest confusion.\n"
        "3. Assign a peer study partner from the same cohort who shows consistently high engagement."
    )
    return _safe_generate(prompt, fallback)
