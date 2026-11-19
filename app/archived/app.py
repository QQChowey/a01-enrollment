"""app.py: the console menu. Start here.

Each menu option maps to one step of the standard demo script:
1 Register        -> demo steps 1 and 2 (new row; duplicate email rejected)
2 Search          -> demo step 3 (the query you profile with EXPLAIN)
3 Fund            -> demo steps 4 and 5 (signature transaction; two users at once)
4 Explain search  -> the EXPLAIN ANALYZE evidence for your report
"""
from decimal import Decimal, InvalidOperation
import psycopg
import db
import explain_helper
import view_schedule

def ask(prompt):
    try:
        return input(prompt + ": ").strip()
    except EOFError:
        return "0"


def ask_int(prompt):
    """Blank input means "no value" (SQL NULL)."""
    s = ask(prompt)
    return None if s == "" else int(s)

def main():
    try:
        settings = db.load_settings()
    except RuntimeError as e:
        print(e)
        return

        # Connection check: the first thing to get working (10/25 check-in screenshot).
        try:
            with db.connect(settings) as conn:
                version = conn.execute("SELECT version()").fetchone()[0]
                print(f"Connected to {settings['dbname']} on {settings['host']}:{settings['port']}")
                print("Server: " + version.split(",")[0])
        except psycopg.Error as e:
            print(db.explain_error(e))
            return

    while True:
        print()
        print("Enrollment:")
        print("1. Register a student")
        print("2. Show All Class Schedules")
        print("3. Register for class.")
        print("4. ")
        choice = ask("Choose")

        try:
            if choice == "1":
                pass
            elif choice == "2":
                view_schedule.view_schedule(settings)
            elif choice == "3":
                pass

                # while True:
                #     print()
                #     print("=== NoTown Org ===")
                #     print("1. Register a person")
                #     print("2. Search people by last name")
                #     print("3. Fund an operation (signature transaction)")
                #     print("4. Show the search query plan (EXPLAIN ANALYZE)")
                #     print("0. Exit")
                #     choice = ask("Choose")
                #
                #     try:
                #         if choice == "1":
                #             first = ask("First name")
                #             last = ask("Last name")
                #             email = ask("Email")
                #             age = ask_int("Age (blank to skip)")
                #             org_id = ask_int("Organization ID 1-10 (blank if unassigned)")
                #             title = ask("Title (e.g. Analyst)")
                #             new_id = person_service.register(settings, first, last, email, age, org_id, title)
                #             print(f"Registered. New Person_ID = {new_id}")
                #         elif choice == "2":
                #             found = person_service.search(settings, ask("Last name starts with"))
                #             print(f"{found} row(s).")
                #         elif choice == "3":
                #             person_id = int(ask("Person_ID authorizing (e.g. 6)"))
                #             operation_id = int(ask("Operation_ID (1-5)"))
                #             account = int(ask("Account_Number (1-8)"))
                #             amount = Decimal(ask("Amount"))
                #             pause = ask("Pause before commit, for a two-terminal test? (y/N)").lower() == "y"
                #             funding_service.fund(settings, person_id, operation_id, account, amount, pause)
                #         elif choice == "4":
                #             prefix = ask("Last name starts with (for the plan)")
                #             explain_helper.explain(settings, person_service.SEARCH_SQL, (prefix + "%",))
                #         elif choice == "0":
                #             print("Bye.")
                #             return
                #         else:
                #             print("Please choose 0-4.")
        except psycopg.Error as e:
            print(db.explain_error(e))
        except (ValueError, InvalidOperation):
            print("That was not a number. Nothing was changed.")


if __name__ == "__main__":
    main()
