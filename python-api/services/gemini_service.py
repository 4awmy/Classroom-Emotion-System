import google.generativeai as genai
import os
from dotenv import load_dotenv

load_dotenv()

genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
model = genai.GenerativeModel("gemini-1.5-flash")

def generate_smart_notes(transcript: str, distraction_timestamps: list[str]) -> str:
    """
    Generates concise study notes from a lecture transcript with special markers
    for sections where the student was distracted.
    """
    if not transcript:
        return "No transcript available for this lecture."
        
    ts = ", ".join(distraction_timestamps) if distraction_timestamps else "None"
    
    prompt = f"""
You are a study assistant. Generate concise study notes from the lecture transcript.
For content taught during these timestamps when the student was distracted: [{ts}],
add a ✱ marker and a plain-English re-explanation.
TRANSCRIPT: {transcript}
Return only clean markdown.
"""
    try:
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        return f"Error generating notes: {str(e)}"

def generate_fresh_brainer(slide_text: str) -> str:
    """
    Generates a single clarifying question to help confused students refocus.
    """
    if not slide_text:
        return "What is the core concept being discussed right now?"
        
    prompt = f"""
Based on this lecture content, generate ONE clarifying question (under 2 sentences)
to help confused students refocus.
SLIDE CONTENT: {slide_text}
"""
    try:
        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        return "Can you explain the main idea of this slide in your own words?"

def generate_intervention_plan(student_emotion_history: str) -> str:
    """
    Suggests 3 actionable steps for a lecturer to support a student based on their emotion patterns.
    """
    if not student_emotion_history:
        return "1. Schedule a check-in.\n2. Review attendance.\n3. Provide extra resources."
        
    prompt = f"""
You are an academic advisor. A student has shown this emotion pattern across lectures:
{student_emotion_history}
Suggest exactly 3 concrete, actionable steps the lecturer can take.
Return as a numbered markdown list.
"""
    try:
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        return "1. Review recent quiz performance.\n2. Recommend office hours.\n3. Pair with a peer mentor."
