import google.generativeai as genai
import os
from typing import List
from datetime import datetime

# Initialize Gemini
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel(os.getenv("GEMINI_MODEL", "gemini-2.5-flash"))
else:
    model = None

def generate_smart_notes(transcript: str, distraction_ts: List[datetime], wrong_topics: List[str] = None) -> str:
    """
    Generates smart notes with ✱ markers for distracted moments and targeted highlights for missed topics.
    """
    if not model:
        return "## AI Notes (Fallback)\n\nGemini API not configured. Here is the raw transcript:\n\n" + transcript

    struggle_context = f"\n- The student explicitly struggled with these topics in live quizzes: {', '.join(wrong_topics)}" if wrong_topics else ""

    prompt = f"""
    You are an AI learning assistant. I will provide a lecture transcript and data about a student's performance.
    Your task:
    1. Summarize the lecture into clear, structured markdown notes.
    2. Identify the sections corresponding to the distracted timestamps provided.
    3. Identify the sections corresponding to the topics they struggled with: {struggle_context}
    4. For those specific sections, provide a more detailed "re-explanation" and mark the line with a '*' at the very beginning of the line.

    Transcript: {transcript}
    Distraction Timestamps: {[ts.isoformat() for ts in distraction_ts]}

    Output markdown format.
    """

    try:
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        return f"Error generating notes: {e}"

def generate_refresher(previous_transcript: str) -> str:
    """
    Generates a concise 3-sentence refresher summary of the previous lecture.
    """
    if not model:
        return "Last session, we discussed the core concepts. Please refer to your notes for a recap."

    prompt = f"""
    Based on the following transcript from the PREVIOUS lecture, generate a concise 3-sentence "Refresher" summary.
    This will be shown to students at the start of today's class.

    Previous Lecture Text: {previous_transcript}
    """

    try:
        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        return "We reviewed the foundational materials in the last session. Ready to begin today's topic."

def generate_comprehension_check(material_text: str) -> dict:
    """
    Generates a Multiple Choice Question (MCQ) based on material text.
    Returns a dict: { "question": str, "options": list, "correct_option": int, "topic": str }
    """
    if not model:
        return {
            "question": "What was the main focus of the last few slides?",
            "options": ["Implementation Details", "Theoretical Background", "Performance Analysis"],
            "correct_option": 0,
            "topic": "General Overview"
        }

    prompt = f"""
    Based on the following lecture material text, generate ONE high-quality Multiple Choice Question (MCQ).
    
    The response MUST be a valid JSON object with exactly these fields:
    1. "question": The question text.
    2. "options": A list of exactly 3 plausible options.
    3. "correct_option": The 0-based index of the correct option in the list.
    4. "topic": A 1-2 word label for the specific concept being tested.

    Material Text: {material_text[:5000]}  # Truncate to avoid token limits

    Output ONLY the JSON object.
    """

    try:
        response = model.generate_content(prompt)
        raw = response.text.strip()
        if "```json" in raw:
            raw = raw.split("```json")[1].split("```")[0].strip()
        elif "```" in raw:
            raw = raw.split("```")[1].strip()
        
        import json
        return json.loads(raw)
    except Exception as e:
        print(f"[GEMINI] MCQ generation failed: {e}")
        return {
            "question": "Which of these concepts is most critical for the next section?",
            "options": ["Core Logic", "Edge Cases", "Data Flow"],
            "correct_option": 0,
            "topic": "Next Steps"
        }

def generate_fresh_brainer(slide_text: str) -> str:
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
        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        return "Can you explain the main concept on this slide in your own words?"

def generate_intervention_plan(emotion_history: List[dict]) -> str:
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
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        return "1. Schedule a 1-on-1 with the instructor.\n2. Review the confusing topics identified by AI.\n3. Form a study group with peers."
