"""test_scaffold.py: tests for the Enrollment app. No extra install needed.

Run from this folder:   python -m unittest -v test_scaffold

Each test states one behavior, runs it, and checks the result in the database
(not just in Python's return value). Each test also cleans up after itself, so
you can run this file as often as you like and your demo data stays the same.

The tests don't touch the seed data: each one builds its own course TEST1
(one section on Saturdays, 1 unit, so no schedule or unit problems) and its
own students (IDs 9001 and up). tearDown deletes the course, which also
deletes its section, enrollments and waitlist (ON DELETE CASCADE), and then
the test students.

The pattern is always:
  1. set up the starting state   2. do the action   3. check the database   4. clean up
"""
import contextlib
import io
import threading
import time
import unittest
from unittest import mock

import psycopg

import db
import enrollment_service
import student_service

SETTINGS = db.load_settings()
TERM = "Fall 2026"
COURSE = "TEST1"


def quiet(func, *args):
    """Runs func with the services' own printing switched off, so test output stays readable."""
    with contextlib.redirect_stdout(io.StringIO()):
        return func(*args)


def scalar(sql, params=None):
    with db.connect(SETTINGS) as conn:
        return conn.execute(sql, params).fetchone()[0]


def run_sql(sql, params=None):
    with db.connect(SETTINGS) as conn:
        conn.execute(sql, params)
        conn.commit()


def unique_email():
    return f"test.{time.time_ns()}@example.com"


def make_section(capacity, waitlist_capacity):
    """Creates course TEST1 with one section (Saturday 08:00-09:00, 1 unit)."""
    run_sql("INSERT INTO Course (course_id, name, units, department) "
            "VALUES (%s, 'Test Course', 1, 'Test Dept')", (COURSE,))
    run_sql("INSERT INTO Section (course_id, term, section_no, start_date, end_date, capacity, "
            "waitlist_capacity, days, start_time, end_time, location, instructor_id) "
            "VALUES (%s, %s, 1, '2026-08-20', '2026-12-08', %s, %s, 'S', '08:00', '09:00', 'TEST', NULL)",
            (COURSE, TERM, capacity, waitlist_capacity))


def make_student(student_id):
    run_sql("INSERT INTO Student (student_id, first_name, last_name, email) "
            "VALUES (%s, 'Test', 'Student', %s)", (student_id, unique_email()))
    return student_id


def enroll_directly(student_id):
    run_sql("INSERT INTO Enrollment (student_id, course_id, term, section_no) "
            "VALUES (%s, %s, %s, 1)", (student_id, COURSE, TERM))


def wait_directly(student_id, position):
    run_sql("INSERT INTO Waitlist (student_id, course_id, term, section_no, position) "
            "VALUES (%s, %s, %s, 1, %s)", (student_id, COURSE, TERM, position))


def status_of(student_id):
    """'enrolled', 'dropped', 'waitlist N', or None."""
    with db.connect(SETTINGS) as conn:
        row = conn.execute("SELECT status FROM Enrollment WHERE student_id = %s AND course_id = %s",
                           (student_id, COURSE)).fetchone()
        if row:
            return row[0]
        row = conn.execute("SELECT position FROM Waitlist WHERE student_id = %s AND course_id = %s",
                           (student_id, COURSE)).fetchone()
        return None if row is None else f"waitlist {row[0]}"


def enrolled_count():
    return scalar("SELECT COUNT(*) FROM Enrollment WHERE course_id = %s AND status = 'enrolled'",
                  (COURSE,))


class EnrollmentTests(unittest.TestCase):

    def setUp(self):
        self.registered = []   # student IDs made by register(), deleted in tearDown

    def tearDown(self):
        run_sql("DELETE FROM Course WHERE course_id = %s", (COURSE,))   # cascades to section rows
        run_sql("DELETE FROM Student WHERE student_id >= 9000")
        for student_id in self.registered:
            run_sql("DELETE FROM Student WHERE student_id = %s", (student_id,))

    def test_1_connects(self):
        """Connects to the Enrollment database"""
        self.assertEqual(scalar("SELECT COUNT(*) FROM Major"), 3)

    def test_2_register_stores_student_and_major(self):
        """Register stores the student AND their major"""
        before = scalar("SELECT COUNT(*) FROM Student")
        new_id = quiet(student_service.register, SETTINGS, "Test", "Student",
                       unique_email(), None, None, 1)
        self.registered.append(new_id)
        self.assertEqual(scalar("SELECT COUNT(*) FROM Student"), before + 1)
        self.assertEqual(scalar("SELECT COUNT(*) FROM Student_Major WHERE student_id = %s "
                                "AND major_id = 1", (new_id,)), 1)

    def test_3_duplicate_email_is_rejected(self):
        """A duplicate email is rejected, and no row is added"""
        email = unique_email()
        first_id = quiet(student_service.register, SETTINGS, "Test", "One", email, None, None, 1)
        self.registered.append(first_id)
        before = scalar("SELECT COUNT(*) FROM Student")
        with self.assertRaises(psycopg.errors.UniqueViolation):   # SQLSTATE 23505
            quiet(student_service.register, SETTINGS, "Test", "Two", email, None, None, 1)
        self.assertEqual(scalar("SELECT COUNT(*) FROM Student"), before)

    def test_4_search_shows_seats_left(self):
        """Search finds the section and counts the seats left"""
        make_section(capacity=3, waitlist_capacity=0)
        enroll_directly(make_student(9001))
        with db.connect(SETTINGS) as conn:
            rows = conn.execute(student_service.SEARCH_SQL, ("Test Dept", "%test%", TERM)).fetchall()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0][5], 2)   # seats_left = 3 - 1
        self.assertEqual(quiet(student_service.search, SETTINGS, "Test Dept", "test", TERM), 1)

    def test_5_rules_are_checked_before_seats(self):
        """Missing prerequisite is reported before 'full'; an eligible student gets 'full'"""
        make_section(capacity=1, waitlist_capacity=1)
        enroll_directly(make_student(9001))   # the only seat is now taken
        run_sql("INSERT INTO Course_Prerequisite (course_id, prereq_course_id) VALUES (%s, 'CS46A')",
                (COURSE,))
        make_student(9002)                    # no CS46A
        make_student(9003)
        run_sql("INSERT INTO AP_Credit (score, student_id, course_id) VALUES (4, 9003, 'CS46A')")

        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            result = enrollment_service.enroll(SETTINGS, 9002, COURSE, TERM, 1)
        self.assertEqual(result, "rejected")
        self.assertIn("Prerequisite not met", out.getvalue())

        result = quiet(enrollment_service.enroll, SETTINGS, 9003, COURSE, TERM, 1)
        self.assertEqual(result, "full")
        self.assertIsNone(status_of(9002))
        self.assertIsNone(status_of(9003))
        self.assertEqual(enrolled_count(), 1)

    def test_6_drop_promotes_next_student(self):
        """Drop commits: the student is dropped and the next on the waitlist is enrolled"""
        make_section(capacity=1, waitlist_capacity=2)
        enroll_directly(make_student(9001))
        wait_directly(make_student(9002), 1)
        wait_directly(make_student(9003), 2)
        quiet(enrollment_service.drop, SETTINGS, 9001, COURSE, TERM, 1, False)
        self.assertEqual(status_of(9001), "dropped")
        self.assertEqual(status_of(9002), "enrolled")
        self.assertEqual(status_of(9003), "waitlist 1")   # moved up
        self.assertEqual(enrolled_count(), 1)

    def test_7_drop_rolls_back_everything(self):
        """Drop rolled back: the drop AND the promotion are both undone"""
        make_section(capacity=1, waitlist_capacity=1)
        enroll_directly(make_student(9001))
        wait_directly(make_student(9002), 1)
        with mock.patch("builtins.input", return_value="r"):   # type r at the pause
            quiet(enrollment_service.drop, SETTINGS, 9001, COURSE, TERM, 1, True)
        self.assertEqual(status_of(9001), "enrolled")
        self.assertEqual(status_of(9002), "waitlist 1")
        self.assertEqual(enrolled_count(), 1)

    def test_8_two_users_drop_at_once(self):
        """Two students drop at once: each waitlisted student is promoted once, never over capacity"""
        make_section(capacity=2, waitlist_capacity=2)
        enroll_directly(make_student(9001))
        enroll_directly(make_student(9002))
        wait_directly(make_student(9003), 1)
        wait_directly(make_student(9004), 2)
        threads = [threading.Thread(target=enrollment_service.drop,
                                    args=(SETTINGS, s, COURSE, TERM, 1, False)) for s in (9001, 9002)]
        with contextlib.redirect_stdout(io.StringIO()):
            for t in threads:
                t.start()
            for t in threads:
                t.join()
        self.assertEqual(status_of(9003), "enrolled")
        self.assertEqual(status_of(9004), "enrolled")
        self.assertEqual(enrolled_count(), 2, "more than 2 means a student was counted twice")
        self.assertEqual(scalar("SELECT COUNT(*) FROM Waitlist WHERE course_id = %s", (COURSE,)), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
