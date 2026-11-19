"""person_service.py: registration and search on the PERSON table.

Every statement uses %s placeholders with a separate tuple of values.
User input is never glued into the SQL text, which is what stops SQL
injection. (Never build SQL with f-strings or +.)
"""
from datetime import date

import db

# The search used by the menu AND by the EXPLAIN option.
SEARCH_SQL = (
    "SELECT person_id, first_name, last_name, email, title, org_id "
    "FROM person "
    "WHERE last_name LIKE %s "
    "ORDER BY last_name, first_name"
)


def register(settings, first, last, email, age, org_id, title):
    """Inserts a person and returns the new Person_ID. Validation is left to the database."""
    with db.connect(settings) as conn:
        # NoTown's Person_ID has no generator, so we take the largest id plus one.
        # If two people register at the same instant, both can get the same id and
        # the PRIMARY KEY rejects one of them. In your own tables, let the database
        # number the rows: id INTEGER GENERATED ALWAYS AS IDENTITY
        largest = conn.execute("SELECT MAX(person_id) FROM person").fetchone()[0]
        new_id = (largest or 0) + 1

        since = None if org_id is None else date.today()   # no organization, no start date
        conn.execute(
            "INSERT INTO person (person_id, first_name, last_name, email, age, org_id, since, title) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
            (new_id, first, last, email, age, org_id, since, title),
        )
        conn.commit()
        return new_id


def search(settings, last_name_prefix):
    """Prints people whose last name starts with the given text."""
    with db.connect(settings) as conn:
        rows = conn.execute(SEARCH_SQL, (last_name_prefix + "%",)).fetchall()
    print(f"{'ID':<4} {'First':<12} {'Last':<12} {'Email':<34} {'Title':<17} Org_ID")
    for person_id, first, last, email, title, org_id in rows:
        print(f"{person_id:<4} {first:<12} {last:<12} {email:<34} {title:<17} "
              f"{'(none)' if org_id is None else org_id}")
    return len(rows)
