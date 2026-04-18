from fastapi import APIRouter
from app.api.v1.endpoints import auth, profile, messaging, social, trainer, notifications, admin, fitness, insights

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(profile.router)
api_router.include_router(messaging.router)
api_router.include_router(social.router)
api_router.include_router(trainer.router)
api_router.include_router(notifications.router)
api_router.include_router(admin.router)
api_router.include_router(fitness.router)
api_router.include_router(insights.router)