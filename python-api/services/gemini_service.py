import google.generativeai as genai
import os
from typing import List
from datetime import datetime

# Initialize Gemini
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel('gemini-1.5-flash')
else:
    model = None

async def generate_smart_notes(transcript: str, distraction_ts: List[datetime]) -> str:
    """
    Generates smart notes with ✱ markers for distracted moments.
    """
    if not model:
        return "## AI Notes (Fallback)\n\nGemini API not configured. Here is the raw transcript:\n\n" + transcript

    prompt = f"""
    You are an AI learning assistant. I will provide a lecture transcript and a list of timestamps when the student was distracted.
    Your task:
    1. Summarize the lecture into clear, structured markdown notes.
    2. Identify the sections corresponding to the distracted timestamps.
    3. For those specific sections, provide a more detailed "re-explanation" and mark the line with a '✱' at the very beginning of the line.

    Transcript: {transcript}
    Distraction Timestamps: {[ts.isoformat() for ts in distraction_ts]}

    Output markdown format.
    """

    try:
        response = await model.generate_content_async(prompt)
        return response.text
    except Exception as e:
        return f"Error generating notes: {e}"

async def generate_fresh_brainer(slide_text: str) -> str:
    """
    Generates a clarifying question based on slide content.
    """
    if not model:
        return "Can you clarify the last point discussed?"

    prompt = f"""
    Based on the following lecture slide text, generate ONE thought-provoking or clarifying question
    that a lecturer can ask the class to check for understanding.
    Keep it to maximum 2 sentences.

    Slide Text: {slide_text}
    """

    try:
        response = await model.generate_content_async(prompt)
        return response.text.strip()
    except Exception as e:
        return "Can you explain the main concept on this slide in your own words?"

async def generate_intervention_plan(emotion_history: List[dict]) -> str:
    """
    Generates a 3-step intervention plan based on student emotion trends.
    """
    if not model:
        return "1. Review recent lecture materials.\n2. Participate more in class discussions.\n3. Visit office hours for clarification."

    prompt = f"""
    Analyze the following student emotion history (list of detected emotions and timestamps).
    Generate a personalized 3-step numbered list intervention plan to help them improve their engagement and understanding.

    History: {emotion_history}

    Output exactly 3 numbered items in markdown.
    """

    try:
        response = await model.generate_content_async(prompt)
        return response.text
    except Exception as e:
        return "1. Schedule a 1-on-1 with the instructor.\n2. Review the confusing topics identified by AI.\n3. Form a study group with peers."
