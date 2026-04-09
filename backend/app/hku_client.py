from __future__ import annotations

import logging
import time
from typing import Iterator

import httpx

from app.config import HKU_HUB_BASE, HTTP_TIMEOUT, REQUEST_DELAY_SEC, RESULTS_PER_PAGE

log = logging.getLogger(__name__)
from app.parsers import parse_pagination_max_start, parse_search_result_rows


class HKUHubClient:
    def __init__(self) -> None:
        self._client = httpx.Client(
            base_url=HKU_HUB_BASE,
            timeout=HTTP_TIMEOUT,
            headers={
                "User-Agent": "HKUProfSummarySync/1.0 (research aggregation; contact: your-email)",
                "Accept": "text/html,application/xhtml+xml",
                "Accept-Language": "en-HK,en;q=0.9",
            },
            follow_redirects=True,
        )

    def close(self) -> None:
        self._client.close()

    def _sleep(self) -> None:
        if REQUEST_DELAY_SEC > 0:
            time.sleep(REQUEST_DELAY_SEC)

    def get_text(self, path: str, params: dict | None = None, *, retries: int = 3) -> str:
        last_exc: BaseException | None = None
        for attempt in range(retries):
            try:
                self._sleep()
                r = self._client.get(path, params=params)
                r.raise_for_status()
                return r.text
            except (httpx.HTTPError, httpx.TransportError) as e:
                last_exc = e
                log.warning(
                    "HTTP %s/%s failed for %s: %s",
                    attempt + 1,
                    retries,
                    path,
                    e,
                )
                if attempt < retries - 1:
                    time.sleep(min(8.0, 2.0**attempt))
        assert last_exc is not None
        raise last_exc

    def iter_all_staff_listings(self) -> Iterator[dict]:
        rpp = RESULTS_PER_PAGE
        start = 0
        max_start: int | None = None
        while True:
            params = {
                "query": "*",
                "location": "crisrp",
                "sort_by": "score",
                "order": "desc",
                "rpp": str(rpp),
                "etal": "0",
                "start": str(start),
            }
            html_text = self.get_text("/simple-search", params=params)
            if max_start is None:
                max_start = parse_pagination_max_start(html_text, rpp)
            rows = parse_search_result_rows(html_text)
            if not rows:
                break
            for row in rows:
                yield row
            if max_start is not None and start >= max_start:
                break
            start += rpp

    def fetch_profile_main(self, cris_rp_id: str) -> str:
        return self.get_text(f"/cris/rp/{cris_rp_id}")

    def fetch_profile_tab(self, cris_rp_id: str, tab: str) -> str:
        return self.get_text(f"/cris/rp/{cris_rp_id}/{tab}.html", params={"onlytab": "true"})
