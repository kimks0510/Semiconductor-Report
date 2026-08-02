"""Incrementally extract competitor (Samsung/SK hynix/Micron) events from
new daily briefings into SQLite, then re-export output/competitor-timeline.md.

Dedup is rule-based: a UNIQUE(event_date, company, headline) constraint on
the table, enforced with INSERT OR IGNORE. Because each report is only ever
sent to Claude once (tracked via ingested_reports), true duplicate work is
avoided at the source; the UNIQUE constraint is a deterministic backstop,
not the primary mechanism.
"""
import re
import sys
from pathlib import Path

from db import PROJECT_ROOT, connect, already_ingested, mark_ingested
from claude_json import call_claude_for_json
from export import export_competitor_timeline

OUTPUT_DIR = PROJECT_ROOT / "output"
REPORT_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})-briefing$")

REQUIRED_KEYS = {"event_date", "company", "source_tier", "headline", "category", "body", "gsm_note", "source_url", "source_report_date"}
VALID_COMPANIES = {"Samsung Electronics", "SK hynix", "Micron"}


def find_all_reports() -> list[tuple[str, Path]]:
    reports = []
    for p in sorted(OUTPUT_DIR.glob("*-briefing.md")):
        m = REPORT_RE.match(p.stem)
        if m:
            reports.append((m.group(1), p))
    return reports


def build_prompt(new_reports: list[tuple[str, Path]]) -> str:
    file_list = ", ".join(f"output/{p.name}" for _, p in new_reports)
    return (
        f"Read only these report files: {file_list}. Do not read any other files. "
        "Extract facts about Samsung Electronics, SK hynix, or Micron: "
        "earnings/conference-call statements, contracts and LTAs, capacity or CapEx "
        "announcements, and product/roadmap claims (HBM, DRAM, NAND). "
        "Output ONLY a JSON array, no other text and no markdown code fences. "
        "Each object must have exactly these keys: event_date (the date of the "
        "announcement/event itself, which may differ from the report's own date), "
        "company (one of 'Samsung Electronics', 'SK hynix', 'Micron'), "
        "source_tier (one of '1차 원문', '산업 데이터', '주요 보도' -- this project's "
        "AGENTS.md source-tier labels), headline (a short Korean headline), "
        "category (a short Korean label such as '실적', '계약', 'CapEx', '제품/로드맵'), "
        "body (2-4 Korean sentences with the concrete facts, numbers, and dates), "
        "gsm_note (one Korean sentence on GSM (Global Sales & Marketing) competitive-"
        "positioning relevance), source_url (a URL if the report cites one, else an "
        "empty string), source_report_date (the yyyy-mm-dd date of whichever of the "
        "files listed above this specific fact was found in). Use an en dash, not a "
        "tilde, for numeric ranges. "
        "Do not invent facts not present in the source reports. "
        "If there is nothing new to extract, output an empty array []."
    )


def main() -> int:
    conn = connect()
    try:
        all_reports = find_all_reports()
        processed = already_ingested(conn, "competitor_events")
        new_reports = [(d, p) for d, p in all_reports if d not in processed]

        if not new_reports:
            print(f"No new reports since last extraction ({len(processed)} already processed); skipping Claude call entirely.")
            return 0

        prompt = build_prompt(new_reports)
        rows = call_claude_for_json(prompt)

        inserted = 0
        for row in rows:
            if not REQUIRED_KEYS.issubset(row.keys()):
                print(f"Skipping malformed row (missing keys): {row}", file=sys.stderr)
                continue
            if row["company"] not in VALID_COMPANIES:
                print(f"Skipping row with invalid company: {row}", file=sys.stderr)
                continue
            cur = conn.execute(
                "INSERT OR IGNORE INTO competitor_events "
                "(event_date, company, source_tier, headline, category, body, gsm_note, source_url, source_report_date) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (row["event_date"], row["company"], row["source_tier"], row["headline"],
                 row.get("category", ""), row.get("body", ""), row.get("gsm_note", ""),
                 row.get("source_url", ""), row["source_report_date"]),
            )
            if cur.rowcount:
                inserted += 1
        conn.commit()

        mark_ingested(conn, "competitor_events", [d for d, _ in new_reports])
        export_competitor_timeline(conn)
        print(f"Processed {len(new_reports)} new report(s), inserted {inserted} event(s).")
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
