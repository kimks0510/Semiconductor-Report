"""SQLite connection and schema for the structured GSM data layer.

Design: Claude only ever emits JSON text (via Read-only headless calls);
this module is the sole writer of the database. That split keeps the LLM
out of the business of directly editing a binary file, and keeps all
dedup/consistency rules in deterministic code.
"""
import sys
import sqlite3
from pathlib import Path

# The Windows console's active codepage (often cp949, not UTF-8) is what
# Python's stdout/stderr default to; Korean text and en dashes then raise
# UnicodeEncodeError on print(). Every pipeline script imports this module,
# so fix it once here rather than repeating it in each entry point.
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DB_PATH = PROJECT_ROOT / "output" / "gsm_data.db"

SCHEMA = """
CREATE TABLE IF NOT EXISTS price_indicators (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_date TEXT NOT NULL,
    product TEXT NOT NULL,
    indicator TEXT NOT NULL,
    value TEXT NOT NULL,
    unit TEXT,
    trend TEXT,
    source_tier TEXT,
    UNIQUE(report_date, product, indicator, value)
);

CREATE TABLE IF NOT EXISTS competitor_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_date TEXT NOT NULL,
    company TEXT NOT NULL,
    source_tier TEXT,
    headline TEXT NOT NULL,
    category TEXT,
    body TEXT,
    gsm_note TEXT,
    source_url TEXT,
    source_report_date TEXT NOT NULL,
    UNIQUE(event_date, company, headline)
);

CREATE TABLE IF NOT EXISTS ingested_reports (
    report_date TEXT NOT NULL,
    artifact TEXT NOT NULL,
    ingested_at TEXT NOT NULL,
    PRIMARY KEY (report_date, artifact)
);
"""


def connect() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.executescript(SCHEMA)
    return conn


def already_ingested(conn: sqlite3.Connection, artifact: str) -> set[str]:
    rows = conn.execute(
        "SELECT report_date FROM ingested_reports WHERE artifact = ?", (artifact,)
    ).fetchall()
    return {r[0] for r in rows}


def mark_ingested(conn: sqlite3.Connection, artifact: str, report_dates: list[str]) -> None:
    import datetime
    now = datetime.datetime.utcnow().isoformat()
    conn.executemany(
        "INSERT OR IGNORE INTO ingested_reports (report_date, artifact, ingested_at) VALUES (?, ?, ?)",
        [(d, artifact, now) for d in report_dates],
    )
    conn.commit()
