from __future__ import annotations

import html
import re
from typing import Any

from bs4 import BeautifulSoup

from app.config import HKU_HUB_BASE


def _abs_url(href: str) -> str:
    if href.startswith("http"):
        return href
    return f"{HKU_HUB_BASE}{href}" if href.startswith("/") else f"{HKU_HUB_BASE}/{href}"


def parse_namecard(soup: BeautifulSoup) -> dict[str, Any]:
    card = soup.select_one("#content-hkuprofile-namecard") or soup
    h3 = card.select_one("h3.text-red")
    heading = html.unescape(h3.get_text(" ", strip=True)) if h3 else ""

    titles: list[str] = []
    dept = ""
    faculty = ""

    for row in card.select("div.row"):
        cols = row.select("div.col-xs-4, div.col-xs-8")
        if len(cols) < 2:
            continue
        label = cols[0].get_text(strip=True).rstrip(":")
        value_divs = cols[1].select("div")
        texts = [html.unescape(d.get_text(" ", strip=True)) for d in value_divs if d.get_text(strip=True)]
        blob = " | ".join(texts) if texts else html.unescape(cols[1].get_text(" ", strip=True))
        if label == "Title":
            titles = [t for t in texts if t] or ([blob] if blob else [])
        elif label == "Department":
            links = cols[1].select("a")
            dept = html.unescape(links[0].get_text(strip=True)) if links else blob
        elif label == "Faculty":
            links = cols[1].select("a")
            faculty = html.unescape(links[0].get_text(strip=True)) if links else blob

    return {
        "display_heading": heading,
        "titles": titles,
        "department": dept,
        "faculty": faculty,
    }


def parse_publications(html_text: str) -> list[dict[str, str]]:
    soup = BeautifulSoup(html_text, "html.parser")
    out: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for a in soup.select(".dctitle a[href^='/handle/']"):
        title = html.unescape(a.get_text(" ", strip=True))
        href = _abs_url(a.get("href", ""))
        key = (href, title)
        if key in seen:
            continue
        seen.add(key)
        journal_em = a.find_parent("div", class_="dctitle")
        journal = ""
        if journal_em:
            j = journal_em.select_one(".dctitle_group em")
            if j:
                journal = html.unescape(j.get_text(" ", strip=True))
        row = a.find_parent("tr")
        issue_date = ""
        if row:
            tds = row.find_all("td")
            if tds:
                issue_date = html.unescape(tds[-1].get_text(" ", strip=True))
        out.append({"title": title, "url": href, "journal": journal, "issue_date": issue_date})
    return out


def parse_item_abstract(html_text: str) -> str:
    """DSpace item page (/handle/...): abstract in metadata table rows."""
    soup = BeautifulSoup(html_text, "html.parser")
    dc_description_abstract = ""
    for tr in soup.select("tr"):
        cells = tr.find_all(["th", "td"])
        if len(cells) < 2:
            continue
        label = html.unescape(cells[0].get_text(strip=True))
        val = html.unescape(cells[1].get_text(" ", strip=True))
        if not val or val.strip() == "-":
            continue
        ll = label.lower()
        if ll == "abstract":
            return val
        if ll == "dc.description.abstract":
            dc_description_abstract = val
    return dc_description_abstract


def _parse_grant_table_rows(
    soup: BeautifulSoup,
    table_selector: str,
    grant_role: str,
    seen: set[str],
) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for tr in soup.select(f"{table_selector} tbody tr"):
        tds = tr.find_all("td")
        if len(tds) < 5:
            continue
        status_div = tds[0].select_one(".dctype")
        status = status_div.get("title", "") if status_div else ""
        code_a = tds[1].select_one("a")
        title_a = tds[2].select_one("a")
        if not title_a:
            continue
        url = _abs_url(title_a["href"]) if title_a.get("href") else ""
        key = f"{grant_role}|{url}" if url else f"{grant_role}|{title_a.get_text(' ', strip=True)}"
        if key in seen:
            continue
        seen.add(key)
        out.append(
            {
                "grant_role": grant_role,
                "status": status,
                "project_code": html.unescape(code_a.get_text(strip=True)) if code_a else "",
                "project_code_url": _abs_url(code_a["href"]) if code_a and code_a.get("href") else "",
                "title": html.unescape(title_a.get_text(" ", strip=True)),
                "url": url,
                "amount": html.unescape(tds[3].get_text(" ", strip=True)),
                "funding_year": html.unescape(tds[4].get_text(" ", strip=True)),
            }
        )
    return out


def parse_grants(html_text: str) -> list[dict[str, str]]:
    """
    HKU grants tab: two sub-sections — Principal Investigator and Co-Investigator — each with its own table
    (classes ncrisprojectprincipalinvestigator / ncrisprojectcoinvestigator). Also accept legacy table.table markup.
    """
    soup = BeautifulSoup(html_text, "html.parser")
    seen: set[str] = set()

    out: list[dict[str, str]] = []
    out.extend(
        _parse_grant_table_rows(
            soup,
            "table.ncrisprojectprincipalinvestigator",
            "principal_investigator",
            seen,
        )
    )
    out.extend(
        _parse_grant_table_rows(
            soup,
            "table.ncrisprojectcoinvestigator",
            "co_investigator",
            seen,
        )
    )

    # Legacy / fallback: bootstrap .table rows not matched above (same 5-column layout)
    for tr in soup.select("table.table tbody tr"):
        tbl = tr.find_parent("table")
        if tbl and tbl.get("class"):
            cl = " ".join(tbl["class"]) if isinstance(tbl["class"], list) else str(tbl["class"])
            if "ncrisproject" in cl:
                continue
        tds = tr.find_all("td")
        if len(tds) < 5:
            continue
        status_div = tds[0].select_one(".dctype")
        status = status_div.get("title", "") if status_div else ""
        code_a = tds[1].select_one("a")
        title_a = tds[2].select_one("a")
        if not title_a:
            continue
        url = _abs_url(title_a["href"]) if title_a.get("href") else ""
        key = f"unknown|{url}" if url else f"unknown|{title_a.get_text(' ', strip=True)}"
        if key in seen:
            continue
        seen.add(key)
        out.append(
            {
                "grant_role": "unknown",
                "status": status,
                "project_code": html.unescape(code_a.get_text(strip=True)) if code_a else "",
                "project_code_url": _abs_url(code_a["href"]) if code_a and code_a.get("href") else "",
                "title": html.unescape(title_a.get_text(" ", strip=True)),
                "url": url,
                "amount": html.unescape(tds[3].get_text(" ", strip=True)),
                "funding_year": html.unescape(tds[4].get_text(" ", strip=True)),
            }
        )
    return out


def parse_grant_project_detail(html_text: str) -> dict[str, str]:
    """
    Fields from /cris/project/{id} → Grant Data panel (HKU Scholars Hub).
    """
    soup = BeautifulSoup(html_text, "html.parser")
    panel = soup.select_one("#content-grantdata-grantdata .panel-body")
    if not panel:
        return {}

    label_keys = {
        "Project Title": "project_title",
        "Principal Investigator": "principal_investigator",
        "Duration": "duration",
        "Start Date": "start_date",
        "Completion Date": "completion_date",
        "Amount": "amount",
        "Conference Title": "conference_title",
        "Keywords": "keywords",
        "Discipline": "discipline",
        "Panel": "panel",
        "HKU Project Code": "hku_project_code",
        "Grant Type": "grant_type",
        "Funding Year": "funding_year",
        "Status": "status",
        "Objectives": "objectives",
    }

    out: dict[str, str] = {}
    for row in panel.select("div.row"):
        label_el = row.select_one(".col-xs-3 strong, .col-sm-3 strong, .col-md-3 strong")
        val_col = row.select_one(".col-xs-9, .col-sm-9, .col-md-9")
        if not label_el or not val_col:
            continue
        label = html.unescape(label_el.get_text(strip=True))
        key = label_keys.get(label)
        if not key:
            continue
        text = html.unescape(re.sub(r"\s+", " ", val_col.get_text(" ", strip=True)))
        if text and text != "-":
            out[key] = text
    return out


def parse_generic_sections(html_text: str) -> list[dict[str, Any]]:
    """
    External relations and university responsibilities: capture panel headings
    and condensed row text from tables / list groups.
    """
    soup = BeautifulSoup(html_text, "html.parser")
    sections: list[dict[str, Any]] = []
    for panel in soup.select("div.panel.panel-default"):
        heading_el = panel.select_one(".panel-heading")
        if not heading_el:
            continue
        title = html.unescape(heading_el.get_text(" ", strip=True))
        if not title or title.lower() == "name card":
            continue
        rows: list[str] = []
        for tr in panel.select("table.table tbody tr"):
            text = html.unescape(tr.get_text(" ", strip=True))
            if len(text) > 3:
                rows.append(text)
        if not rows:
            for li in panel.select("ul.list-group li"):
                text = html.unescape(li.get_text(" ", strip=True))
                if len(text) > 3:
                    rows.append(text)
        if rows:
            sections.append({"section": title, "entries": rows[:200]})
    return sections


def parse_search_result_rows(html_text: str) -> list[dict[str, str]]:
    soup = BeautifulSoup(html_text, "html.parser")
    results: list[dict[str, str]] = []
    for tr in soup.select("table.table tbody tr"):
        tds = tr.find_all("td")
        if len(tds) < 3:
            continue
        a = tds[0].select_one('a[href^="/cris/rp/rp"]')
        if not a:
            continue
        href = a.get("href", "")
        m = re.search(r"/cris/rp/(rp\d+)", href)
        if not m:
            continue
        cris_id = m.group(1)
        name_en = html.unescape(a.get_text(" ", strip=True))
        name_en = re.sub(r"\s+", " ", name_en).strip()
        zh_a = tds[1].select_one("a.authority")
        zh_text = html.unescape(tds[1].get_text(" ", strip=True))
        if zh_a:
            name_zh = html.unescape(zh_a.get_text(" ", strip=True))
        else:
            name_zh = "" if zh_text == "-" else zh_text
        dept_em = tds[2].select_one("em")
        department = html.unescape(dept_em.get_text(" ", strip=True)) if dept_em else ""
        interests_em = tds[3].select_one("em") if len(tds) > 3 else None
        interests = html.unescape(interests_em.get_text(" ", strip=True)) if interests_em else ""
        results.append(
            {
                "cris_rp_id": cris_id,
                "name_en": name_en,
                "name_zh": name_zh,
                "department": department,
                "research_interests": interests,
                "profile_path": href.split("?")[0],
            }
        )
    return results


def parse_pagination_max_start(html_text: str, rpp: int) -> int | None:
    soup = BeautifulSoup(html_text, "html.parser")
    starts = [0]
    for a in soup.select('a[href*="start="]'):
        href = a.get("href", "")
        m = re.search(r"start=(\d+)", href)
        if m:
            starts.append(int(m.group(1)))
    if not starts:
        return None
    return max(starts)
