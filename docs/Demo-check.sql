-- ============================================================
-- 05_demo_checks.sql: the "proof in the database" for each demo step
-- Project: A01-Enrollment for CS157A, Sec 07
-- Authors: Quan Tang, Sebastian Lim, Kirsten Perez
-- Created: November 15, 2026
--
-- Keep this file open beside the app and run one statement at a time
-- (pgAdmin Query Tool or psql). Start from a fresh load:
-- 03_create_tables.sql, then 04_seed_data.sql.
--
-- Demo setup from the seed data: CS157A Sec 07 (Fall 2026) is full,
-- 2 of 2 seats (Ava 1001, Ben 1002), with Chloe 1003, Diego 1004 and
-- Emma 1005 on its waitlist in positions 1, 2, 3.
-- ============================================================

-- ============================================================
-- STEP AT RISK: 2. Validation
--
-- What should happen:
--   We try a duplicate enrollment and expect it to be rejected by
--   UNIQUE (student_id, course_id, term, section_no).
--
-- What happens instead:
--   It is rejected, but by a BEFORE INSERT trigger, not the UNIQUE
--   constraint. PostgreSQL runs BEFORE triggers before it checks UNIQUE,
--   so whichever trigger fails first wins.
--
--   Ava enrolling again in CS157A-07 (a full section):
--     ERROR: Section CS157A-7 (Fall 2026) is full (2 of 2 seats taken);
--            join the waitlist instead
--     CONTEXT: PL/pgSQL function check_section_capacity() line 29 at RAISE
--
--   Chloe enrolling again in CS146-1 (a section with open seats):
--     ERROR: Schedule conflict: CS146-1 overlaps with CS146-1 that student
--            1003 is already in
--     CONTEXT: PL/pgSQL function check_student_schedule() line 31 at RAISE
--
--   The data stays correct, but the demo shows the wrong rule, and
--   "schedule conflict" is a misleading message for a duplicate.
--
-- What we have already tried:
--   - Ran the duplicate against a full and a non-full section; a trigger
--     fires first both times.
--   - Confirmed the UNIQUE constraint exists (catalog check 4a, row 15).
--   - The other two bad inserts (capacity = -5, a course as its own
--     prerequisite) are rejected by their CHECK constraints as expected.
--
-- Question for Clinic 2:
--   Should check_student_schedule() skip the student's own section so the
--   UNIQUE constraint catches duplicates, or is it fine to show the trigger
--   rejecting it and explain that BEFORE triggers run before UNIQUE?
-- ============================================================


-- Step 1 - Register: the newest students, including the one just added
SELECT student_id, first_name, last_name, email
FROM Student
ORDER BY student_id DESC
LIMIT 3;

-- Step 1 - Register: their major was saved too
SELECT sm.student_id, m.name AS major
FROM Student_Major sm
JOIN Major m ON m.major_id = sm.major_id
ORDER BY sm.student_id DESC
LIMIT 3;


-- Step 2 - Validation: the duplicate email was not stored
-- (replace with the email you tried twice; expect 1)
SELECT COUNT(*) FROM Student WHERE email = 'frank.ito@sjsu.edu';

-- Step 2 - Validation: the bad inserts tried in psql, one at a time.
-- Each should fail; the comment says which rule should stop it.
-- capacity = -5 -> CHECK section_capacity_check
UPDATE Section SET capacity = -5 WHERE course_id = 'CS146' AND term = 'Fall 2026' AND section_no = 1;
-- duplicate enrollment -> meant for UNIQUE, but a trigger catches it first (see above)
INSERT INTO Enrollment (student_id, course_id, term, section_no) VALUES (1003, 'CS146', 'Fall 2026', 1);
-- course as its own prerequisite -> CHECK course_prerequisite_check
INSERT INTO Course_Prerequisite (course_id, prereq_course_id, min_grade, override) VALUES ('CS146', 'CS146', 'C', FALSE);

-- Step 2 - Validation: nothing changed (expect capacity 35, Chloe once, no CS146->CS146 row)
SELECT capacity FROM Section WHERE course_id = 'CS146' AND term = 'Fall 2026' AND section_no = 1;
SELECT COUNT(*) FROM Enrollment WHERE student_id = 1003 AND course_id = 'CS146' AND term = 'Fall 2026';
SELECT COUNT(*) FROM Course_Prerequisite WHERE course_id = 'CS146' AND prereq_course_id = 'CS146';


-- Step 3 - Search: the plan PostgreSQL chose for the app's search
-- (department CS, keyword "data", current term, seats left)
EXPLAIN ANALYZE
SELECT s.course_id, s.section_no, c.name, s.days, s.start_time,
       s.capacity - COUNT(e.enrollment_id) AS seats_left
FROM Section s
JOIN Course c ON c.course_id = s.course_id
LEFT JOIN Enrollment e ON e.course_id = s.course_id AND e.term = s.term
     AND e.section_no = s.section_no AND e.status = 'enrolled'
WHERE c.department = 'Computer Science'
  AND c.name ILIKE '%data%'
  AND s.term = 'Fall 2026'
GROUP BY s.course_id, s.term, s.section_no, c.name, s.days, s.start_time, s.capacity;


-- Step 4 - Transaction succeeds: run BEFORE and AFTER Ava drops
-- CS157A-07 in the app, and compare.
-- Expect AFTER: Ava 'dropped', Chloe 'enrolled', Diego and Emma at
-- waitlist positions 1 and 2, seats_open still 0.
SELECT student_id, status
FROM Enrollment
WHERE course_id = 'CS157A' AND term = 'Fall 2026' AND section_no = 7
ORDER BY student_id;

SELECT student_id, position
FROM Waitlist
WHERE course_id = 'CS157A' AND term = 'Fall 2026' AND section_no = 7
ORDER BY position;

SELECT course_id, section_no, capacity, enrolled_count, seats_open, waitlist_count
FROM Section_Seat_Status
WHERE course_id = 'CS157A' AND term = 'Fall 2026' AND section_no = 7;


-- Step 5 - Two users at once: after both app sessions try to take the
-- last seat, the section is never over capacity (expect enrolled_count
-- <= capacity) and only one of the two students got the seat.
SELECT course_id, section_no, capacity, enrolled_count, seats_open, waitlist_count
FROM Section_Seat_Status
WHERE course_id = 'CS157A' AND term = 'Fall 2026' AND section_no = 7;

SELECT student_id, status, time_enrolled
FROM Enrollment
WHERE course_id = 'CS157A' AND term = 'Fall 2026' AND section_no = 7
ORDER BY time_enrolled DESC;


-- Reset: run 03_create_tables.sql then 04_seed_data.sql again to start
-- over with the original data.