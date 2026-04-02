import os

from dotenv import load_dotenv

load_dotenv()

HKU_HUB_BASE = os.environ.get("HKU_HUB_BASE", "https://hub.hku.hk").rstrip("/")
SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
REQUEST_DELAY_SEC = float(os.environ.get("REQUEST_DELAY_SEC", "0.35"))
HTTP_TIMEOUT = float(os.environ.get("HTTP_TIMEOUT", "60"))
RESULTS_PER_PAGE = int(os.environ.get("RPP", "100"))
MAX_PROFESSORS = int(os.environ.get("MAX_PROFESSORS", "0"))
