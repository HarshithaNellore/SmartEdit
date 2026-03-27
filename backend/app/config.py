import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./smartcut.db")
JWT_SECRET = os.getenv("JWT_SECRET", "smartcut_super_secret_key_change_in_production_2024")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
JWT_EXPIRATION_MINUTES = int(os.getenv("JWT_EXPIRATION_MINUTES", "1440"))
PORT = int(os.getenv("PORT", "5000"))
