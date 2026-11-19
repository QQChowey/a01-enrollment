import db
from tabulate import tabulate

def fetch_viewschedule(settings):
    with db.connect(settings) as conn:
        results = conn.execute("SELECT * FROM Section_Seat_Status").fetchall()
    return results

def view_schedule(settings):
    results = fetch_viewschedule(settings)
    headers = ["Course", "Semester", "Section", "Title",
        "Instructor", "Days", "Start", "End", "Capacity",
        "Enrolled", "Available", "Waitlist Capacity", "Waitlisted"
        ]
    print(tabulate(
        results,
        headers=headers,
        tablefmt="simple",
        maxcolwidths=[8, 10, 5, 20, 15, 5, 8, 8, 6, 8, 6, 8, 6]
    ))

def register(settings, first, last, email, phone, address, major_id):
    """Inserts a student and their major in ONE transaction, returns the new student_id.

    If either insert fails (duplicate email, a major that doesn't exist),
    neither row is kept. Validation is left to the database.
    """
    with db.connect(settings) as conn:
        # Student IDs have no generator (the school assigns them), so we take
        # the largest id plus one. If two students register at the same
        # instant, the PRIMARY KEY rejects one of them.
        largest = conn.execute("SELECT MAX(student_id) FROM Student").fetchone()[0]
        new_id = (largest or 1000) + 1

        conn.execute(
            "INSERT INTO Student (student_id, first_name, last_name, address, phone_number, email) "
            "VALUES (%s, %s, %s, %s, %s, %s)",
            (new_id, first, last, address, phone, email),
        )
        if major_id is not None:
            conn.execute(
                "INSERT INTO Student_Major (student_id, major_id) VALUES (%s, %s)",
                (new_id, major_id),
            )
        conn.commit()
        return new_id
