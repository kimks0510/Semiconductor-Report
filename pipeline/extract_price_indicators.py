"""Incrementally extract price/supply indicators from new daily briefings
into SQLite, then re-export output/price-indicators.csv.

Only reports not already in ingested_reports(artifact='price_indicators')
are sent to Claude; if there are none, this exits without calling Claude
at all.
"""
import re
import sys
from pathlib import Path

from db import PROJECT_ROOT, connect, already_ingested, mark_ingested
from claude_json import call_claude_for_json
from export import export_price_indicators

OUTPUT_DIR = PROJECT_ROOT / "output"
REPORT_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})-briefing$")

REQUIRED_KEYS = {"report_date", "product", "indicator", "value", "unit", "trend", "source_tier"}
VALID_PRODUCTS = {"DRAM", "NAND", "HBM", "GPU", "CapEx", "Foundry", "Other"}
VALID_TRENDS = {"up", "down", "flat", "unclear"}


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
        "Extract every explicit price, supply, capacity, or demand data point mentioned "
        "(spot price, contract price, LTA terms, capacity expansion, shortage/oversupply "
        "commentary, CapEx figures tied to a specific company). "
        "Output ONLY a JSON array, no other text and no markdown code fences. "
        "Each object must have exactly these keys: report_date, product, indicator, value, "
        "unit, trend, source_tier. "
        "product is one of DRAM, NAND, HBM, GPU, CapEx, Foundry, Other. "
        "trend is one of up, down, flat, unclear. "
        "source_tier is one of '1차 원문', '산업 데이터', '주요 보도' "
        "(this project's AGENTS.md source-tier labels). "
        "Only include entries backed by an actual number or an explicit qualitative "
        "statement in the source report; never invent a value. "
        "Use an en dash, not a tilde, for ranges. "
        "If there is nothing to extract, output an empty array []."
    )


def main() -> int:
    conn = connect()
    try:
        all_reports = find_all_reports()
        processed = already_ingested(conn, "price_indicators")
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
            if row["product"] not in VALID_PRODUCTS or row["trend"] not in VALID_TRENDS:
                print(f"Skipping row with invalid product/trend: {row}", file=sys.stderr)
                continue
            cur = conn.execute(
                "INSERT OR IGNORE INTO price_indicators "
                "(report_date, product, indicator, value, unit, trend, source_tier) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (row["report_date"], row["product"], row["indicator"], row["value"],
                 row.get("unit", ""), row["trend"], row["source_tier"]),
            )
            if cur.rowcount:
                inserted += 1
        conn.commit()

        mark_ingested(conn, "price_indicators", [d for d, _ in new_reports])
        export_price_indicators(conn)
        print(f"Processed {len(new_reports)} new report(s), inserted {inserted} row(s).")
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
