"""Pre-digest a week's worth of structured data (SQLite) into a compact
text block for the weekly-rollup prompt, so Claude doesn't have to reopen
raw daily briefings just to see this week's numbers. Pure local filtering,
no LLM involved.

Usage: python weekly_context.py 2026-07-20 2026-07-24
Prints the digest to stdout; empty output means no structured data yet
for that range (caller should fall back to raw reports or flag it sparse).
"""
import sys

from db import connect, PROJECT_ROOT

COMPANY_DISPLAY = {
    "SK hynix": "SK하이닉스",
    "Samsung Electronics": "삼성전자",
    "Micron": "Micron",
}


def build_context(monday: str, friday: str) -> str:
    conn = connect()
    try:
        price_rows = conn.execute(
            "SELECT report_date, product, indicator, value, unit, trend, source_tier "
            "FROM price_indicators WHERE report_date BETWEEN ? AND ? ORDER BY report_date",
            (monday, friday),
        ).fetchall()
        event_rows = conn.execute(
            "SELECT event_date, company, source_tier, headline, body, gsm_note "
            "FROM competitor_events WHERE event_date BETWEEN ? AND ? ORDER BY event_date",
            (monday, friday),
        ).fetchall()
    finally:
        conn.close()

    blocks = []
    if price_rows:
        lines = [
            f"- {d} [{product}] {indicator}: {value} {unit} ({trend}, {tier})"
            for d, product, indicator, value, unit, trend, tier in price_rows
        ]
        blocks.append("### Price/supply indicators for this week\n" + "\n".join(lines))
    if event_rows:
        lines = []
        for d, company, tier, headline, body, gsm_note in event_rows:
            display_company = COMPANY_DISPLAY.get(company, company)
            lines.append(f"- {d} [{display_company}] [{tier}] {headline}: {body} (GSM: {gsm_note})")
        blocks.append("### Competitor timeline entries for this week\n" + "\n".join(lines))
    return "\n\n".join(blocks)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python weekly_context.py <monday yyyy-mm-dd> <friday yyyy-mm-dd>", file=sys.stderr)
        sys.exit(1)
    print(build_context(sys.argv[1], sys.argv[2]))
