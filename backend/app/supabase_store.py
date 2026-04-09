from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from supabase import Client, create_client

from app.config import SUPABASE_SERVICE_KEY, SUPABASE_URL


def get_client() -> Client:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise RuntimeError(
            "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in the process "
            "environment (Railway: open the sync service → Variables → add both; "
            "redeploy). Names are case-sensitive."
        )
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


def upsert_professor(client: Client, row: dict[str, Any]) -> None:
    now = datetime.now(timezone.utc).isoformat()
    payload = {
        "cris_rp_id": row["cris_rp_id"],
        "name_en": row.get("name_en"),
        "name_zh": row.get("name_zh") or None,
        "titles": row.get("titles") or [],
        "faculty": row.get("faculty"),
        "department": row.get("department"),
        "research_interests": row.get("research_interests"),
        "profile_url": row.get("profile_url"),
        "display_heading": row.get("display_heading"),
        "publications": row.get("publications") or [],
        "external_relations": row.get("external_relations") or [],
        "university_responsibilities": row.get("university_responsibilities") or [],
        "grants": row.get("grants") or [],
        "synced_at": now,
        "updated_at": now,
    }
    client.table("professors").upsert(payload, on_conflict="cris_rp_id").execute()
