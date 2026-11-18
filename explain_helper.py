"""explain_helper.py: prints PostgreSQL's plan for a query, with real timings.

EXPLAIN ANALYZE actually RUNS the query, so only use it on SELECTs here.
Used on our 2 main queries: the class search and a student's schedule.
Course is tiny, so it gets a Seq Scan; Section and Enrollment are looked up
through their primary key and our partial index on enrolled rows.
"""
import db


def explain(settings, sql, params):
    with db.connect(settings) as conn:
        for (line,) in conn.execute("EXPLAIN ANALYZE " + sql, params):
            print("  " + line)
