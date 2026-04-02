from __future__ import annotations

import argparse
import logging
import sys

from bs4 import BeautifulSoup

from app.config import HKU_HUB_BASE, MAX_PROFESSORS
from app.hku_client import HKUHubClient
from app.parsers import (
    parse_generic_sections,
    parse_grants,
    parse_namecard,
    parse_publications,
)
from app.supabase_store import get_client, upsert_professor

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger(__name__)


def enrich_and_save(client_hub: HKUHubClient, sb, listing: dict, *, details: bool) -> None:
    cris_id = listing["cris_rp_id"]
    profile_url = f"{HKU_HUB_BASE}/cris/rp/{cris_id}"

    row = {
        **listing,
        "profile_url": profile_url,
        "titles": [],
        "faculty": None,
        "display_heading": None,
        "publications": [],
        "external_relations": [],
        "university_responsibilities": [],
        "grants": [],
    }

    if not details:
        upsert_professor(sb, row)
        return

    main_html = client_hub.fetch_profile_main(cris_id)
    card = parse_namecard(BeautifulSoup(main_html, "html.parser"))
    row["titles"] = card["titles"]
    row["faculty"] = card["faculty"] or None
    row["department"] = card["department"] or listing.get("department")
    row["display_heading"] = card["display_heading"]

    pub_html = client_hub.fetch_profile_tab(cris_id, "publications")
    row["publications"] = parse_publications(pub_html)

    ext_html = client_hub.fetch_profile_tab(cris_id, "external")
    row["external_relations"] = parse_generic_sections(ext_html)

    ach_html = client_hub.fetch_profile_tab(cris_id, "achievements")
    row["university_responsibilities"] = parse_generic_sections(ach_html)

    grants_html = client_hub.fetch_profile_tab(cris_id, "grants")
    row["grants"] = parse_grants(grants_html)

    upsert_professor(sb, row)


def run(*, list_only: bool = False, max_n: int | None = None) -> None:
    limit = max_n if max_n is not None else (MAX_PROFESSORS or None)
    sb = get_client()
    hub = HKUHubClient()
    try:
        count = 0
        for listing in hub.iter_all_staff_listings():
            enrich_and_save(hub, sb, listing, details=not list_only)
            count += 1
            if count % 25 == 0:
                log.info("Synced %s professors", count)
            if limit is not None and count >= limit:
                break
        log.info("Done. Total: %s (list_only=%s)", count, list_only)
    finally:
        hub.close()


def main() -> None:
    p = argparse.ArgumentParser(description="Sync HKU Scholars Hub staff into Supabase")
    p.add_argument(
        "--list-only",
        action="store_true",
        help="Only upsert listing fields (name, dept from search); skip profile tabs",
    )
    p.add_argument("--max", type=int, default=None, help="Max professors to process (for testing)")
    args = p.parse_args()
    run(list_only=args.list_only, max_n=args.max)


if __name__ == "__main__":
    main()
