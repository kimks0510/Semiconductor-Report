"""One-time migration: load the existing output/price-indicators.csv and
output/competitor-timeline.md (+ its state file) into SQLite, so the new
incremental Python pipeline starts from the real current state instead of
reprocessing everything from scratch. Safe to re-run (INSERT OR IGNORE).
"""
import csv
import json
import re
import sys

from db import PROJECT_ROOT, connect, mark_ingested

OUTPUT_DIR = PROJECT_ROOT / "output"
PRICE_CSV = OUTPUT_DIR / "price-indicators.csv"
TIMELINE_MD = OUTPUT_DIR / "competitor-timeline.md"
TIMELINE_STATE = OUTPUT_DIR / "competitor-timeline-state.json"

COMPANY_MAP = {
    "SK하이닉스": "SK hynix",
    "삼성전자": "Samsung Electronics",
    "Micron": "Micron",
}

ENTRY_HEADING_RE = re.compile(r"^### \[(.+?)\] \[(.+?)\] (.+)$")
DATE_HEADING_RE = re.compile(r"^## (\d{4}-\d{2}-\d{2})")


def migrate_price_indicators(conn) -> int:
    if not PRICE_CSV.exists():
        print("No existing price-indicators.csv; skipping.")
        return 0
    inserted = 0
    dates = set()
    with open(PRICE_CSV, encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            dates.add(row["report_date"])
            cur = conn.execute(
                "INSERT OR IGNORE INTO price_indicators "
                "(report_date, product, indicator, value, unit, trend, source_tier) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (row["report_date"], row["product"], row["indicator"], row["value"],
                 row["unit"], row["trend"], row["source_tier"]),
            )
            if cur.rowcount:
                inserted += 1
    conn.commit()
    mark_ingested(conn, "price_indicators", sorted(dates))
    print(f"price_indicators: inserted {inserted} row(s), marked {len(dates)} report date(s) ingested.")
    return inserted


def migrate_competitor_timeline(conn) -> int:
    if not TIMELINE_MD.exists():
        print("No existing competitor-timeline.md; skipping.")
        return 0

    lines = TIMELINE_MD.read_text(encoding="utf-8-sig").splitlines()
    inserted = 0
    current_date = None
    i = 0
    while i < len(lines):
        line = lines[i]
        date_m = DATE_HEADING_RE.match(line)
        if date_m:
            current_date = date_m.group(1)
            i += 1
            continue
        heading_m = ENTRY_HEADING_RE.match(line)
        if heading_m and current_date:
            company_raw, source_tier, headline = heading_m.groups()
            company = COMPANY_MAP.get(company_raw, company_raw)
            category, body, source_url, gsm_note = "", "", "", ""
            i += 1
            while i < len(lines) and not lines[i].startswith("## ") and not lines[i].startswith("### "):
                l = lines[i].strip()
                if l.startswith("- 구분:"):
                    category = l[len("- 구분:"):].strip()
                elif l.startswith("- 내용:"):
                    body = l[len("- 내용:"):].strip()
                elif l.startswith("- 출처:"):
                    source_url = l[len("- 출처:"):].strip()
                elif l.startswith("- GSM 경쟁 포지셔닝:"):
                    gsm_note = l[len("- GSM 경쟁 포지셔닝:"):].strip()
                i += 1
            cur = conn.execute(
                "INSERT OR IGNORE INTO competitor_events "
                "(event_date, company, source_tier, headline, category, body, gsm_note, source_url, source_report_date) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (current_date, company, source_tier, headline, category, body, gsm_note, source_url, current_date),
            )
            if cur.rowcount:
                inserted += 1
            continue
        i += 1
    conn.commit()
    print(f"competitor_events: inserted {inserted} entr(y/ies).")

    processed_dates = []
    if TIMELINE_STATE.exists():
        state = json.loads(TIMELINE_STATE.read_text(encoding="utf-8-sig"))
        processed_dates = state.get("processedReports", [])
    if processed_dates:
        mark_ingested(conn, "competitor_events", processed_dates)
        print(f"competitor_events: marked {len(processed_dates)} report date(s) ingested (from state file).")
    return inserted


def main() -> int:
    conn = connect()
    try:
        migrate_price_indicators(conn)
        migrate_competitor_timeline(conn)
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
