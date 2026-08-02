"""Minimal self-check for the SQLite layer: schema creation, ingestion
tracking, and the UNIQUE-constraint dedup backstop. No network, no Claude.
Run manually: python pipeline/test_db.py
"""
import sqlite3

from db import SCHEMA, already_ingested, mark_ingested


def make_conn():
    conn = sqlite3.connect(":memory:")
    conn.executescript(SCHEMA)
    return conn


def test_ingested_tracking():
    conn = make_conn()
    assert already_ingested(conn, "price_indicators") == set()
    mark_ingested(conn, "price_indicators", ["2026-07-19", "2026-07-20"])
    assert already_ingested(conn, "price_indicators") == {"2026-07-19", "2026-07-20"}
    # Different artifact is independently tracked.
    assert already_ingested(conn, "competitor_events") == set()
    # Re-marking the same dates is idempotent (INSERT OR IGNORE on PK).
    mark_ingested(conn, "price_indicators", ["2026-07-19"])
    assert already_ingested(conn, "price_indicators") == {"2026-07-19", "2026-07-20"}


def test_price_indicator_dedup():
    conn = make_conn()
    row = ("2026-07-19", "DRAM", "spot price", "50.0", "USD", "up", "산업 데이터")
    conn.execute(
        "INSERT OR IGNORE INTO price_indicators "
        "(report_date, product, indicator, value, unit, trend, source_tier) VALUES (?,?,?,?,?,?,?)",
        row,
    )
    cur = conn.execute(
        "INSERT OR IGNORE INTO price_indicators "
        "(report_date, product, indicator, value, unit, trend, source_tier) VALUES (?,?,?,?,?,?,?)",
        row,
    )
    assert cur.rowcount == 0, "exact-duplicate row should have been ignored"
    count = conn.execute("SELECT COUNT(*) FROM price_indicators").fetchone()[0]
    assert count == 1, f"expected 1 row after duplicate insert, got {count}"


def test_competitor_event_dedup_by_date_company_headline():
    conn = make_conn()
    base = ("2026-07-02", "SK hynix", "1차 원문", "청주 NAND 투자", "CapEx", "body", "note", "", "2026-07-19")
    conn.execute(
        "INSERT OR IGNORE INTO competitor_events "
        "(event_date, company, source_tier, headline, category, body, gsm_note, source_url, source_report_date) "
        "VALUES (?,?,?,?,?,?,?,?,?)", base,
    )
    # Same event_date+company+headline but different body -> still treated as duplicate (rule-based, not semantic).
    dup = ("2026-07-02", "SK hynix", "주요 보도", "청주 NAND 투자", "CapEx", "different body", "note2", "", "2026-07-20")
    cur = conn.execute(
        "INSERT OR IGNORE INTO competitor_events "
        "(event_date, company, source_tier, headline, category, body, gsm_note, source_url, source_report_date) "
        "VALUES (?,?,?,?,?,?,?,?,?)", dup,
    )
    assert cur.rowcount == 0, "same (event_date, company, headline) should be ignored even if body text differs"
    count = conn.execute("SELECT COUNT(*) FROM competitor_events").fetchone()[0]
    assert count == 1


if __name__ == "__main__":
    test_ingested_tracking()
    test_price_indicator_dedup()
    test_competitor_event_dedup_by_date_company_headline()
    print("ALL PASS")
