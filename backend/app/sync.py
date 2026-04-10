from __future__ import annotations

import argparse
import logging
import sys
from urllib.parse import urlparse

from bs4 import BeautifulSoup

from app.config import FETCH_GRANT_DETAILS, HKU_HUB_BASE, MAX_PROFESSORS
from app.hku_client import HKUHubClient
from app.parsers import (
    parse_generic_sections,
    parse_grant_project_detail,
    parse_grants,
    parse_item_abstract,
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


def _project_path_on_hub(project_url: str) -> str | None:
    p = urlparse((project_url or "").strip())
    base_host = urlparse(HKU_HUB_BASE).netloc
    host = p.netloc or base_host
    if host != base_host:
        return None
    path = (p.path or "").split("?")[0].rstrip("/")
    if not path.startswith("/cris/project/"):
        return None
    slug = path.removeprefix("/cris/project/").strip("/")
    return path if slug else None


def _handle_path_on_hub(pub_url: str) -> str | None:
    p = urlparse((pub_url or "").strip())
    base_host = urlparse(HKU_HUB_BASE).netloc
    host = p.netloc or base_host
    if host != base_host:
        return None
    path = (p.path or "").split("?")[0]
    if not path.startswith("/handle/"):
        return None
    return path or None


def _attach_publication_abstracts(hub: HKUHubClient, pubs: list[dict[str, str]]) -> None:
    for pub in pubs:
        path = _handle_path_on_hub(pub.get("url", ""))
        if not path:
            continue
        try:
            item_html = hub.get_text(path)
            abstract = parse_item_abstract(item_html)
            if abstract:
                pub["abstract"] = abstract
        except Exception as e:
            log.debug("Abstract fetch failed for %s: %s", path, e)


def _attach_grant_details(hub: HKUHubClient, grants: list) -> None:
    for g in grants:
        url = (g.get("url") or "").strip() or (g.get("project_code_url") or "").strip()
        path = _project_path_on_hub(url)
        if not path:
            continue
        try:
            proj_html = hub.get_text(path)
            detail = parse_grant_project_detail(proj_html)
            for k, val in detail.items():
                if val:
                    g[k] = val
        except Exception as e:
            log.debug("Grant detail fetch failed for %s: %s", path, e)


def enrich_and_save(
    client_hub: HKUHubClient,
    sb,
    listing: dict,
    *,
    details: bool,
    grant_details_override: bool | None = None,
) -> None:
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
    _attach_publication_abstracts(client_hub, row["publications"])

    ext_html = client_hub.fetch_profile_tab(cris_id, "external")
    row["external_relations"] = parse_generic_sections(ext_html)

    ach_html = client_hub.fetch_profile_tab(cris_id, "achievements")
    row["university_responsibilities"] = parse_generic_sections(ach_html)

    grants_html = client_hub.fetch_grants_page(cris_id)
    row["grants"] = parse_grants(grants_html)
    fetch_grant_pages = FETCH_GRANT_DETAILS if grant_details_override is None else grant_details_override
    if fetch_grant_pages:
        _attach_grant_details(client_hub, row["grants"])

    upsert_professor(sb, row)


def run(
    *,
    list_only: bool = False,
    max_n: int | None = None,
    grant_details_override: bool | None = None,
) -> None:
    limit = max_n if max_n is not None else (MAX_PROFESSORS or None)
    sb = get_client()
    hub = HKUHubClient()
    processed = 0
    ok = 0
    failed: list[tuple[str, str]] = []
    try:
        for listing in hub.iter_all_staff_listings():
            cris_id = listing.get("cris_rp_id", "?")
            if limit is not None and processed >= limit:
                break
            processed += 1
            try:
                enrich_and_save(
                    hub,
                    sb,
                    listing,
                    details=not list_only,
                    grant_details_override=grant_details_override,
                )
                ok += 1
            except Exception as e:
                msg = f"{type(e).__name__}: {e}"
                failed.append((cris_id, msg))
                log.error("Failed to sync %s: %s", cris_id, e)
                if log.isEnabledFor(logging.DEBUG):
                    log.exception("Traceback for %s", cris_id)
            if processed % 25 == 0:
                log.info("Progress: %s processed (%s ok, %s failed)", processed, ok, len(failed))
        log.info(
            "Done. Processed=%s ok=%s failed=%s (list_only=%s)",
            processed,
            ok,
            len(failed),
            list_only,
        )
        if failed:
            log.warning("Failed CRIS IDs (%s):", len(failed))
            for cid, msg in failed[:50]:
                log.warning("  %s — %s", cid, msg)
            if len(failed) > 50:
                log.warning("  ... and %s more", len(failed) - 50)
    finally:
        hub.close()


def main() -> None:
    p = argparse.ArgumentParser(description="Sync HKU Scholars Hub staff into Supabase")
    p.add_argument(
        "--list-only",
        action="store_true",
        help="Only upsert listing fields (name, dept from search); skip profile tabs",
    )
    p.add_argument(
        "--max",
        type=int,
        default=None,
        help="Max staff rows to attempt from the hub (includes failures)",
    )
    p.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Log debug messages and tracebacks for each failed profile",
    )
    p.add_argument(
        "--no-grant-details",
        action="store_true",
        help="Skip fetching /cris/project/… for each grant (overrides FETCH_GRANT_DETAILS env)",
    )
    args = p.parse_args()
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
        log.setLevel(logging.DEBUG)
        logging.getLogger("app.hku_client").setLevel(logging.DEBUG)
    grant_override = False if args.no_grant_details else None
    run(
        list_only=args.list_only,
        max_n=args.max,
        grant_details_override=grant_override,
    )


if __name__ == "__main__":
    main()
