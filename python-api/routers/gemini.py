from fastapi import APIRouter, Response
from pydantic import BaseModel

router = APIRouter(tags=["Gemini / AI"])

class GeminiQuestionRequest(BaseModel):
    lecture_id: str

@router.post("/gemini/question")
async def get_gemini_question(request: GeminiQuestionRequest):
    return {"question": "What is the key difference between recursion and iteration?"}

@router.get("/notes/{student_id}/plan")
async def get_intervention_plan(student_id: str):
    markdown_content = "## Intervention Plan\n\n1. Review lecture recordings for weeks 3–4...\n2. ..."
    return Response(content=markdown_content, media_type="text/markdown")

@router.get("/notes/{student_id}/{lecture_id}")
async def get_smart_notes(student_id: str, lecture_id: str):
    markdown_content = "## Lecture Notes\n\n### Key Concepts\n...\n\n✱ **You missed this part:** ..."
    return Response(content=markdown_content, media_type="text/markdown")
