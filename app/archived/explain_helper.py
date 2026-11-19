"""explain_helper.py: prints PostgreSQL's plan for a query, with real timings.

EXPLAIN ANALYZE actually RUNS the query, so only use it on SELECTs here.
On NoTown's 50 people you will see a Seq Scan: on a table that small,
reading every row is cheapest. Seed 10,000+ rows in your own project
before you expect an index to show up.
"""
import db


def explain(settings, sql, params):
    with db.connect(settings) as conn:
        for (line,) in conn.execute("EXPLAIN ANALYZE " + sql, params):
            print("  " + line)
