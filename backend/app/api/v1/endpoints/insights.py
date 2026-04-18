import json
import re
from datetime import date, datetime, timezone
from google import genai
from google.genai import types
from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from pydantic import BaseModel

from app.core.config import settings
from app.api.v1.deps import get_db, get_current_user
from app.models.user import User
from app.models.fitness import WorkoutSession, WorkoutStatus
from app.services.profile_service import profile_service
from app.services.fitness_service import fitness_service

router = APIRouter(prefix="/insights", tags=["Insights"])

client = genai.Client(api_key=settings.GEMINI_API_KEY) if settings.GEMINI_API_KEY else None

class InsightResponse(BaseModel):
    title: str
    description: str

@router.post("/generate", response_model=InsightResponse)
async def generate_dynamic_insight(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not client:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Inference engine is offline. API Key missing on server."
        )

    try:
        today = date.today()
        today_start = datetime.combine(today, datetime.min.time()).replace(tzinfo=timezone.utc)

        profile = await profile_service.get_or_create_profile(db, current_user)
        step_goal = profile.daily_step_goal or 10000
        activity_level = profile.activity_level.value if profile.activity_level else "moderately_active"

        steps_summary = await fitness_service.get_steps_summary(db, current_user.id, step_goal)
        steps = steps_summary.get("steps", 0)

        nutrition_summary = await fitness_service.get_nutrition_summary(db, current_user.id, today)
        calories_eaten = nutrition_summary.get("total_calories", 0.0)

        hydration_summary = await fitness_service.get_hydration_summary(db, current_user.id)
        water_litres = hydration_summary.get("total_l", 0.0)
        water_goal_litres = 2.5

        weekly_stats = await fitness_service.get_weekly_stats(db, current_user.id, step_goal)
        workouts_this_week = weekly_stats.get("workouts_completed", 0)

        result = await db.execute(
            select(func.sum(WorkoutSession.calories_burned))
            .where(
                WorkoutSession.user_id == current_user.id,
                WorkoutSession.status == WorkoutStatus.COMPLETED,
                WorkoutSession.started_at >= today_start
            )
        )
        calories_burned = result.scalar_one_or_none() or 0.0

    except Exception as e:
        print(f"Error fetching DB telemetry: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve user telemetry securely."
        )

    net_calories = calories_eaten - calories_burned

    prompt = f"""
    You are an objective, highly analytical system AI interpreting raw user telemetry.

    Live Backend Data:
    - Steps Logged: {steps} / {step_goal}
    - Caloric Intake: {calories_eaten} kcal
    - Caloric Expenditure: {calories_burned} kcal
    - Net Balance: {net_calories} kcal
    - Hydration: {water_litres}L / {water_goal_litres}L
    - Weekly Training Volume: {workouts_this_week} sessions
    - Configured Baseline Activity: {activity_level}

    Analyze this data payload and provide a concise, highly specific analysis.
    Constraints:
    1. Tone must be industrial, sophisticated, objective, and strictly professional.
    2. Do NOT use any emojis, clichés, slang, or overly enthusiastic exclamation marks.
    3. Focus strictly on the data and its physiological implications.

    Return strictly a JSON object with this exact schema:
    {{
      "title": "A precise 2-4 word analytical header",
      "description": "A 1-2 sentence objective analysis of their current metrics and a precise directive based on the telemetry."
    }}
    """

    try:
        # CORRECTED: Changed model target from gemini-2.0-flash to match the successful curl request
        response = await client.aio.models.generate_content(
            model="gemini-flash-latest", 
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json"
            )
        )

        if not response.text:
            raise ValueError("Empty response from inference engine.")

        # Robust parsing: strips markdown formatting if the model disobeys the mime-type
        raw_text = response.text.strip()
        if raw_text.startswith("```json"):
            raw_text = re.sub(r"^```json\n|\n```$", "", raw_text, flags=re.MULTILINE).strip()
        elif raw_text.startswith("```"):
            raw_text = re.sub(r"^```\n|\n```$", "", raw_text, flags=re.MULTILINE).strip()

        result_data = json.loads(raw_text)

        return InsightResponse(
            title=result_data.get("title", "Analysis Complete"),
            description=result_data.get("description", "Telemetry parsed successfully.")
        )

    except json.JSONDecodeError as e:
        print(f"JSON Parse Error. Raw response: {response.text}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to parse structured output from inference engine."
        )
    except Exception as e:
        err_str = str(e)
        print(f"LLM Generation Error (Direct from Google): {err_str}") 
        
        if "429" in err_str or "quota" in err_str.lower():
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Inference engine quota exhausted. Retry after a short interval."
            )
            
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to establish connection with the inference engine at this time."
        )