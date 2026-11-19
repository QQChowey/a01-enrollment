"""app.py: the console menu. Start here.

You use the app as a student: register as a new student or log in with
your student ID, then use the student menu. Each option maps to one step
of the standard demo script:
  Register             -> demo steps 1 and 2 (new row; duplicate email rejected)
  1 Search classes     -> demo step 3 (the query you profile with EXPLAIN)
  2 Enroll             -> prerequisites, schedule, units, then seats; full -> waitlist
  3 Drop               -> demo steps 4 and 5 (signature transaction; two users at once)
  5 Query plans        -> the EXPLAIN ANALYZE evidence for your report
"""
import psycopg

import db
import enrollment_service
import explain_helper
import student_service

TERM = "Fall 2026"   # the current term used by every menu option


def ask(prompt):
    try:
        return input(prompt + ": ").strip()
    except EOFError:
        return "0"


def ask_int(prompt):
    """Blank input means "no value" (SQL NULL)."""
    s = ask(prompt)
    return None if s == "" else int(s)


def ask_default(prompt, default):
    """Blank input means "use the default"."""
    s = ask(f"{prompt} [Default: {default}]")
    return default if s == "" else s


def ask_section():
    course_id = ask("Course ID (e.g. CS157A)").upper()
    section_no = int(ask("Section number (e.g. 7)"))
    return course_id, section_no


def register(settings):
    """Returns the new student_id, or None if the database rejected it."""
    first = ask("First name")
    last = ask("Last name")
    email = ask("Email")
    phone = ask("Phone (blank to skip)") or None
    address = ask("Address (blank to skip)") or None
    majors = student_service.list_majors(settings)
    print("Majors: " + ", ".join(f"{major_id} {name}" for major_id, name in majors))
    major_id = ask_int("Major ID (blank if undeclared)")
    new_id = student_service.register(settings, first, last, email, phone, address, major_id)
    print(f"Registered. Your student ID is {new_id}. You are now logged in.")
    return new_id


def student_menu(settings, student_id, name):
    """The menu after logging in. Returns False to exit the app, True to log out."""
    while True:
        print()
        print(f"=== Logged in: {name} ({student_id}) | {TERM} ===")
        print("1. Search classes")
        print("2. Enroll in a section")
        print("3. Drop a section (signature transaction)")
        print("4. My schedule and waitlists")
        print("5. Show the query plans (EXPLAIN ANALYZE)")
        print("6. Log out")
        print("0. Exit")
        choice = ask("Choose")

        try:
            if choice == "1":
                department = ask_default("Department", "Computer Science")
                keyword = ask("Course name contains (blank for all)")
                found = student_service.search(settings, department, keyword, TERM)
                print(f"{found} section(s).")
            elif choice == "2":
                course_id, section_no = ask_section()
                result = enrollment_service.enroll(settings, student_id, course_id, TERM, section_no)
                if result == "full":
                    if ask("Join the waitlist? (y/N)").lower() == "y":
                        enrollment_service.join_waitlist(settings, student_id, course_id, TERM, section_no)
                    else:
                        print("Not added to the waitlist. Nothing changed.")
            elif choice == "3":
                course_id, section_no = ask_section()
                pause = ask("Pause before commit, for a two-terminal test? (y/N)").lower() == "y"
                enrollment_service.drop(settings, student_id, course_id, TERM, section_no, pause)
            elif choice == "4":
                student_service.schedule(settings, student_id, TERM)
            elif choice == "5":
                department = ask_default("Department", "Computer Science")
                keyword = ask_default("Course name contains", "data")
                print("Search:")
                explain_helper.explain(settings, student_service.SEARCH_SQL,
                                       (department, "%" + keyword + "%", TERM))
                print("My schedule:")
                explain_helper.explain(settings, student_service.SCHEDULE_SQL, (student_id, TERM))
            elif choice == "6":
                print("Logged out.")
                return True
            elif choice == "0":
                return False
            else:
                print("Please choose 0-6.")
        except psycopg.Error as e:
            print(db.explain_error(e))
        except ValueError:
            print("That was not a number. Nothing was changed.")


def main():
    try:
        settings = db.load_settings()
    except RuntimeError as e:
        print(e)
        return

    # Connection check: the first thing to get working.
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
        print("=== SJSU Enrollment ===")
        print("1. Register as a new student")
        print("2. Log in with your student ID")
        print("0. Exit")
        choice = ask("Choose")

        try:
            student_id = None
            if choice == "1":
                student_id = register(settings)
            elif choice == "2":
                student_id = int(ask("Student ID (e.g. 1001)"))
                if student_service.find_student(settings, student_id) is None:
                    print(f"No student with ID {student_id}.")
                    student_id = None
            elif choice == "0":
                print("Bye.")
                return
            else:
                print("Please choose 0-2.")

            if student_id is not None:
                first, last = student_service.find_student(settings, student_id)
                if not student_menu(settings, student_id, f"{first} {last}"):
                    print("Bye.")
                    return
        except psycopg.Error as e:
            print(db.explain_error(e))
        except ValueError:
            print("That was not a number. Nothing was changed.")


if __name__ == "__main__":
    main()
