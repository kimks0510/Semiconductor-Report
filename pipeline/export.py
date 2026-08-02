"""Materialize the SQLite tables back to the plain files the rest of the
pipeline (Build-MobileSite.ps1, Send-KakaoKnowledgeDigest.ps1) already
reads. SQLite is the source of truth; these files are generated views.
"""
import csv
import sqlite3
from pathlib import Path

from db import PROJECT_ROOT

PRICE_CSV = PROJECT_ROOT / "output" / "price-indicators.csv"
TIMELINE_MD = PROJECT_ROOT / "output" / "competitor-timeline.md"

# DB stores company names in English (stable join/query keys); the site and
# every other artifact are Korean-first, so map back to Korean for display.
COMPANY_DISPLAY = {
    "SK hynix": "SK하이닉스",
    "Samsung Electronics": "삼성전자",
    "Micron": "Micron",
}


def export_price_indicators(conn: sqlite3.Connection) -> None:
    rows = conn.execute(
        "SELECT report_date, product, indicator, value, unit, trend, source_tier "
        "FROM price_indicators ORDER BY report_date, id"
    ).fetchall()
    with open(PRICE_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["report_date", "product", "indicator", "value", "unit", "trend", "source_tier"])
        writer.writerows(rows)


def export_competitor_timeline(conn: sqlite3.Connection) -> None:
    rows = conn.execute(
        "SELECT event_date, company, source_tier, headline, category, body, gsm_note, source_url "
        "FROM competitor_events ORDER BY event_date, id"
    ).fetchall()
    lines = [
        "# 삼성전자·SK하이닉스·Micron 경쟁사 타임라인",
        "",
        "> SQLite 구조화 데이터에서 자동 생성됨. 신규 보고서가 들어올 때마다 증분 갱신됩니다.",
        "",
    ]
    current_date = None
    for event_date, company, source_tier, headline, category, body, gsm_note, source_url in rows:
        if event_date != current_date:
            lines.append(f"## {event_date}")
            lines.append("")
            current_date = event_date
        display_company = COMPANY_DISPLAY.get(company, company)
        lines.append(f"### [{display_company}] [{source_tier}] {headline}")
        lines.append("")
        if category:
            lines.append(f"- 구분: {category}")
        if body:
            lines.append(f"- 내용: {body}")
        if source_url:
            lines.append(f"- 출처: {source_url}")
        if gsm_note:
            lines.append(f"- GSM 경쟁 포지셔닝: {gsm_note}")
        lines.append("")
    TIMELINE_MD.write_text("\n".join(lines), encoding="utf-8")


def export_all() -> None:
    from db import connect
    conn = connect()
    try:
        export_price_indicators(conn)
        export_competitor_timeline(conn)
    finally:
        conn.close()


if __name__ == "__main__":
    export_all()
    print("Exported price-indicators.csv and competitor-timeline.md from SQLite.")
