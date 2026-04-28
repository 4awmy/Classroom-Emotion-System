from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter()

class GeminiQuestionRequest(BaseModel):
    lecture_id: str

@router.post("/question")
async def get_gemini_question(request: GeminiQuestionRequest):
    return {"question": "Can you clarify what Big O notation means for nested loops?"}

@router.get("/notes/{student_id}/{lecture_id}")
async def get_smart_notes(student_id: str, lecture_id: str):
    return {"markdown": f"## Lecture Notes for {lecture_id}\n\nThis lecture covered Big O notation and common complexity classes. \n\n✱ You missed the section on logarithmic time complexity while distracted."}

@router.get("/notes/{student_id}/plan")
async def get_intervention_plan(student_id: str):
    return {"markdown": "1. Schedule office hours to discuss recursion concepts.\n2. Review the recorded lecture for Week 3 specifically between 10:05 and 10:15.\n3. Complete the supplementary exercises on merge sort complexity."}
