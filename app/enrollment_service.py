"""enrollment_service.py: enroll, join a waitlist, and drop.

DROP is the SIGNATURE TRANSACTION. One UPDATE from the app sets off
several writes inside the database, and all of them commit or none do:

  1. the student's row          UPDATE Enrollment SET status = 'dropped'
  2. the next waitlisted student INSERT INTO Enrollment   (trigger trg_waitlist_promote)
  3. their waitlist row         DELETE FROM Waitlist      (trigger trg_enrollment_leave_waitlist)
  4. everyone behind them       UPDATE Waitlist SET position = position - 1
  5. COMMIT                     (or ROLLBACK: then the drop AND the promotion are undone)

Two students dropping the same section at once: the promotion locks the
Section row (SELECT ... FOR UPDATE in the capacity trigger), so the second
drop waits for the first to COMMIT, then promotes the NEXT student on the
updated waitlist. Nobody is promoted twice and the section never goes over
capacity.

Enrolling is checked by the database in this order (trigger names are
numbered so they run in order): prerequisites, schedule conflict, unit
limit, then seats. So a "section is full" error means the student passed
everything else and can be offered the waitlist.
"""
import psycopg
from psycopg import errors

import db


def enroll(settings, student_id, course_id, term, section_no, pause_before_commit=False):
    """Tries to enroll. Returns "enrolled", "full", or "rejected"."""
    print_section(settings, course_id, term, section_no)
    with db.connect(settings) as conn:
        # Show the triggers' RAISE NOTICE messages
        conn.add_notice_handler(lambda diag: print("  Database: " + diag.message_primary))
        try:
            conn.execute(
                "INSERT INTO Enrollment (student_id, course_id, term, section_no) "
                "VALUES (%s, %s, %s, %s)",
                (student_id, course_id, term, section_no),
            )
            if pause_before_commit:
                answer = input("PAUSED before COMMIT. Press [Enter] to continue to commit, or type r to roll back.")
                if answer.strip().lower() == "r":
                    conn.rollback()
                    print("ROLLED BACK. Enrollment is cancelled.")
                    print_section(settings, course_id, term, section_no)
                    return

            conn.commit()
            print(f"Enrolled in {course_id} Sec {section_no}.")
            return "enrolled"
        except psycopg.Error as e:
            conn.rollback()
            # The seat check runs LAST, so "is full" means every other rule passed
            if isinstance(e, errors.CheckViolation) and "is full" in str(e):
                print(f"{course_id} Sec {section_no} is full.")
                return "full"
            print(db.explain_error(e))
            return "rejected"


def join_waitlist(settings, student_id, course_id, term, section_no):
    """Adds the student to the end of the waitlist. Returns their position, or None."""
    with db.connect(settings) as conn:
        try:
            # Lock the section row so two students joining at the same moment
            # don't both get the same position
            conn.execute(
                "SELECT 1 FROM Section WHERE course_id = %s AND term = %s AND section_no = %s "
                "FOR UPDATE",
                (course_id, term, section_no),
            )
            position = conn.execute(
                "SELECT COALESCE(MAX(position), 0) + 1 FROM Waitlist "
                "WHERE course_id = %s AND term = %s AND section_no = %s",
                (course_id, term, section_no),
            ).fetchone()[0]
            # The waitlist triggers check prerequisites, schedule, units,
            # that the section is full, and that the waitlist has room
            conn.execute(
                "INSERT INTO Waitlist (student_id, course_id, term, section_no, position) "
                "VALUES (%s, %s, %s, %s, %s)",
                (student_id, course_id, term, section_no, position),
            )
            conn.commit()
            print(f"Joined the waitlist for {course_id} Sec {section_no} at position {position}.")
            return position
        except psycopg.Error as e:
            conn.rollback()
            print(db.explain_error(e))
            return None


def drop(settings, student_id, course_id, term, section_no, pause_before_commit):
    """Runs the signature transaction. If pause_before_commit is True, it waits
    for Enter before committing, so you can drop from a second terminal and
    watch it wait."""
    print_section(settings, course_id, term, section_no)
    with db.connect(settings) as conn:
        # Show the triggers' RAISE NOTICE messages (who got promoted)
        conn.add_notice_handler(lambda diag: print("  Database: " + diag.message_primary))
        # psycopg starts a transaction automatically: nothing is permanent
        # until conn.commit().
        try:
            cur = conn.execute(
                "UPDATE Enrollment SET status = 'dropped' "
                "WHERE student_id = %s AND course_id = %s AND term = %s "
                "  AND section_no = %s AND status = 'enrolled'",
                (student_id, course_id, term, section_no),
            )
            if cur.rowcount == 0:
                conn.rollback()
                print(f"You are not enrolled in {course_id} Sec {section_no}. Nothing changed.")
                return
            print("  Step 1 done: your enrollment is marked dropped")
            print("  Step 2 done: the waitlist was checked for the next student (see above)")

            if pause_before_commit:
                answer = input("  Paused before COMMIT. Press Enter to commit, or type r to roll back... ")
                if answer.strip().lower() == "r":
                    conn.rollback()
                    print("ROLLED BACK. You are still enrolled and the waitlist is unchanged.")
                    print_section(settings, course_id, term, section_no)
                    return

            conn.commit()
            print("COMMITTED. The drop and any promotion are now permanent.")
        except psycopg.Error as e:
            conn.rollback()
            print("ROLLED BACK. " + db.explain_error(e))
            print("Nothing from this transaction was kept.")
    print_section(settings, course_id, term, section_no)


def print_section(settings, course_id, term, section_no):
    """Reads the seat counts from the view in a fresh connection, to show what was kept."""
    with db.connect(settings) as conn:
        row = conn.execute(
            "SELECT enrolled_count, capacity, waitlist_count, waitlist_capacity "
            "FROM Section_Seat_Status WHERE course_id = %s AND term = %s AND section_no = %s",
            (course_id, term, section_no),
        ).fetchone()
    if row:
        enrolled, capacity, waiting, wl_capacity = row
        print(f"  {course_id} Sec {section_no}: {enrolled} of {capacity} seats taken, "
              f"{waiting} of {wl_capacity} on the waitlist")
    else:
        print(f"  No section {course_id} Sec {section_no} in {term}.")
