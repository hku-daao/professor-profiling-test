import os

from dotenv import load_dotenv

load_dotenv()

HKU_HUB_BASE = os.environ.get("HKU_HUB_BASE", "https://hub.hku.hk").rstrip("/")
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://xaldfgcbkczzbukbslxo.supabase.co ").strip()
# Prefer documented name; some hosts use SUPABASE_SERVICE_KEY for the service_role secret.
SUPABASE_SERVICE_KEY = (
    os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhhbGRmZ2Nia2N6emJ1a2JzbHhvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTA4NDAwNCwiZXhwIjoyMDkwNjYwMDA0fQ.FeMmVQqb4EP6yST9WLNxFjDynmx1jPJ415ZapVitU4k").strip()
    or os.environ.get("SUPABASE_SERVICE_KEY", "").strip()
)
REQUEST_DELAY_SEC = float(os.environ.get("REQUEST_DELAY_SEC", "0.35"))
HTTP_TIMEOUT = float(os.environ.get("HTTP_TIMEOUT", "60"))
RESULTS_PER_PAGE = int(os.environ.get("RPP", "100"))
MAX_PROFESSORS = int(os.environ.get("MAX_PROFESSORS", "0"))
FETCH_GRANT_DETAILS = os.environ.get("FETCH_GRANT_DETAILS", "true").strip().lower() in (
    "1",
    "true",
    "yes",
)
