-- ============================================================
-- 03_demo_checks.sql: the "proof in the database" for each demo step
-- Project: A01-Enrollment for CS157A, Sec 07
-- Authors: Quan Tang, Sebastian Lim, Kirsten Perez
-- Created: November 15, 2026 | Last edited: November 17, 2026
--
-- Keep this file open beside the app terminal and run one statement
-- at a time (highlight it, then F5 in pgAdmin). Start from a fresh
-- load: 01_create_tables.sql, then 02_seed_data.sql.
--
-- Seed setup: CS157A Sec 07 (Fall 2026) is full, 2 of 2 seats
-- (Ava 1001, Ben 1002); Chloe 1003, Diego 1004, Emma 1005 wait in
-- positions 1, 2, 3.
-- ============================================================

-- Step 1 - Register: the newest students and their major
SELECT s.student_id, s.first_name, s.last_name, s.email, m.name AS major
FROM Student s
LEFT JOIN Student_Major sm ON sm.student_id = s.student_id
LEFT JOIN Major m ON m.major_id = sm.major_id
ORDER BY s.student_id DESC
LIMIT 3;

-- Step 2 - Validation: the duplicate email was not stored (expect 1)
SELECT COUNT(*) FROM Student WHERE email = 'frank.ito@sjsu.edu';

-- Step 3 - Search: the plan PostgreSQL chose for the app's search
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
GROUP BY s.course_id, s.term, s.section_no, c.name, s.days, s.start_time, s.capacity
ORDER BY s.course_id, s.section_no;

-- Steps 4 and 5 - Transaction: run BEFORE and AFTER, compare
-- Step 4 (Ava drops): Ava dropped, Chloe enrolled, Diego 1 and Emma 2
-- Step 5 (Ben and Chloe drop at once): Diego and Emma each enrolled
-- once, waitlist empty, never more than 2 enrolled
SELECT student_id, status, NULL AS position
FROM Enrollment
WHERE course_id = 'CS157A' AND term = 'Fall 2026' AND section_no = 7
UNION ALL
SELECT student_id, 'waitlist', position
FROM Waitlist
WHERE course_id = 'CS157A' AND term = 'Fall 2026' AND section_no = 7
UNION ALL
SELECT NULL, enrolled_count || ' of ' || capacity || ' seats taken', waitlist_count
FROM Section_Seat_Status
WHERE course_id = 'CS157A' AND term = 'Fall 2026' AND section_no = 7
ORDER BY 1 NULLS LAST;

-- Reset: run 01_create_tables.sql then 02_seed_data.sql again to start over.