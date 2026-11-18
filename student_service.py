"""student_service.py: registration, log in, class search and schedule.

Every statement uses %s placeholders with a separate tuple of values.
User input is never glued into the SQL text, which is what stops SQL
injection. (Never build SQL with f-strings or +.)
"""
import db

# Main query 1: the class search. Used by the menu AND by the EXPLAIN option.
# Same query as Step 3 in sql/03_demo_checks.sql.
SEARCH_SQL = (
    "SELECT s.course_id, s.section_no, c.name, s.days, s.start_time, "
    "       s.capacity - COUNT(e.enrollment_id) AS seats_left "
    "FROM Section s "
    "JOIN Course c ON c.course_id = s.course_id "
    "LEFT JOIN Enrollment e ON e.course_id = s.course_id AND e.term = s.term "
    "     AND e.section_no = s.section_no AND e.status = 'enrolled' "
    "WHERE c.department = %s "
    "  AND c.name ILIKE %s "
    "  AND s.term = %s "
    "GROUP BY s.course_id, s.term, s.section_no, c.name, s.days, s.start_time, s.capacity "
    "ORDER BY s.course_id, s.section_no"
)

# Main query 2: one student's schedule for a term.
SCHEDULE_SQL = (
    "SELECT e.course_id, e.section_no, c.name, c.units, s.days, "
    "       s.start_time, s.end_time, s.location "
    "FROM Enrollment e "
    "JOIN Section s ON s.course_id = e.course_id AND s.term = e.term "
    "     AND s.section_no = e.section_no "
    "JOIN Course c ON c.course_id = e.course_id "
    "WHERE e.student_id = %s AND e.term = %s AND e.status = 'enrolled' "
    "ORDER BY s.start_time"
)


def list_majors(settings):
    """Returns [(major_id, name), ...] so the menu can show the choices."""
    with db.connect(settings) as conn:
        return conn.execute("SELECT major_id, name FROM Major ORDER BY major_id").fetchall()


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


def find_student(settings, student_id):
    """Log in: returns (first_name, last_name), or None if there's no such student."""
    with db.connect(settings) as conn:
        return conn.execute(
            "SELECT first_name, last_name FROM Student WHERE student_id = %s", (student_id,)
        ).fetchone()


def search(settings, department, keyword, term):
    """Prints sections in a department whose course name contains the keyword."""
    with db.connect(settings) as conn:
        rows = conn.execute(SEARCH_SQL, (department, "%" + keyword + "%", term)).fetchall()
    print(f"{'Course':<8} {'Sec':<4} {'Name':<45} {'Days':<5} {'Start':<6} Seats left")
    for course_id, section_no, name, days, start, seats_left in rows:
        print(f"{course_id:<8} {section_no:<4} {name:<45} {days:<5} "
              f"{start.strftime('%H:%M'):<6} {seats_left}")
    return len(rows)


def schedule(settings, student_id, term):
    """Prints the student's enrolled classes, total units, and waitlists."""
    with db.connect(settings) as conn:
        rows = conn.execute(SCHEDULE_SQL, (student_id, term)).fetchall()
        waits = conn.execute(
            "SELECT course_id, section_no, position FROM Waitlist "
            "WHERE student_id = %s AND term = %s ORDER BY course_id",
            (student_id, term),
        ).fetchall()

    print(f"Enrolled in {term}:")
    total = 0
    for course_id, section_no, name, units, days, start, end, location in rows:
        total += units
        print(f"  {course_id:<7} Sec {section_no:<3} {name:<45} {units}u  "
              f"{days:<4} {start.strftime('%H:%M')}-{end.strftime('%H:%M')}  {location or ''}")
    if not rows:
        print("  (none)")
    print(f"  Total units: {total}")

    print("Waitlists:")
    for course_id, section_no, position in waits:
        print(f"  {course_id} Sec {section_no}: position {position}")
    if not waits:
        print("  (none)")