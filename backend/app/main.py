from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from .database import engine, Base, get_db
from .routes.auth_routes import router as auth_router
from .routes.project_routes import router as project_router
from .routes.ai_routes import router as ai_router
from .routes.collaboration_routes import router as collab_router
from .routes.email_routes import router as email_router
from .seed import seed_default_user

# Create all tables on startup
Base.metadata.create_all(bind=engine)

# Seed default user for testing
db = next(get_db())
try:
    seed_default_user(db)
finally:
    db.close()

app = FastAPI(
    title="SmartCut API",
    description="Backend API for SmartCut — AI-Powered Photo & Video Editor",
    version="1.0.0",
)

# CORS — allow Flutter app from any origin during development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount routers
app.include_router(auth_router)
app.include_router(project_router)
app.include_router(ai_router)
app.include_router(collab_router)
app.include_router(email_router)

# Serve processed AI outputs as static files
processed_dir = Path(__file__).parent.parent / "processed"
processed_dir.mkdir(exist_ok=True)
app.mount("/processed", StaticFiles(directory=str(processed_dir)), name="processed")


@app.get("/")
def root():
    return {"message": "SmartCut API is running 🚀", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "healthy"}
