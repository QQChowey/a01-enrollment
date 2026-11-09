-- ============================================================
-- 04_seed_data.sql: Sample Data for the Enrollment Database
-- Authors: Quan Tang, Sebastian Lim, Kirsten Perez
-- Created: November 1, 2026 | Last edited: November 8, 2026
--
-- Fills all 13 tables with sample data
-- Run this right after 03_create_tables.sql on an empty database
--
-- Demo setup: CS157A Sec 07 has only 2 seats; both are taken and
-- 3 students are on its waitlist so we can show what happens when
-- a section is full
-- ============================================================

-- ------------------------------------------------------------
-- STUDENT (5 rows)
-- ------------------------------------------------------------
INSERT INTO Student (student_id, first_name, last_name, address, phone_number, email) VALUES
(1001, 'Ava',   'Nguyen', '1 Washington Sq, San Jose, 95192',      '408-555-0101', 'ava.nguyen@sjsu.edu'),
(1002, 'Ben',   'Lopez',  '200 E Santa Clara St, San Jose, 95113', '408-555-0102', 'ben.lopez@sjsu.edu'),
(1003, 'Chloe', 'Park',   '75 S 4th St, San Jose, 95112',          '408-555-0103', 'chloe.park@sjsu.edu'),
(1004, 'Diego', 'Ramos',  '410 N 1st St, San Jose, 95112',         '408-555-0104', 'diego.ramos@sjsu.edu'),
(1005, 'Emma',  'Chen',   '88 E San Fernando St, San Jose, 95113', '408-555-0105', 'emma.chen@sjsu.edu');

-- ------------------------------------------------------------
-- COURSE (5 rows)
-- ------------------------------------------------------------
INSERT INTO Course (course_id, name, units, department) VALUES
('CS46A',  'Introduction to Programming',                 4, 'Computer Science'),
('CS46B',  'Introduction to Data Structures',             4, 'Computer Science'),
('CS146',  'Data Structures and Algorithms',              3, 'Computer Science'),
('CS157A', 'Introduction to Database Management Systems', 3, 'Computer Science'),
('MATH42', 'Discrete Mathematics',                        3, 'Mathematics');

-- ------------------------------------------------------------
-- INSTRUCTOR (3 rows)
--   instructor_id is filled in automatically: 1, 2, 3
-- ------------------------------------------------------------
INSERT INTO Instructor (first_name, last_name, email) VALUES
('Yuva',  'Athur', 'yuva.athur@sjsu.edu'),      -- instructor_id 1
('Maria', 'Gomez', 'maria.gomez@sjsu.edu'),     -- instructor_id 2
('James', 'Lee',   'james.lee@sjsu.edu');       -- instructor_id 3

-- ------------------------------------------------------------
-- MAJOR (3 rows)
--   major_id is filled in automatically: 1, 2, 3
-- ------------------------------------------------------------
INSERT INTO Major (name) VALUES
('Computer Science'),       -- major_id 1
('Software Engineering'),   -- major_id 2
('Mathematics');            -- major_id 3

-- ------------------------------------------------------------
-- SECTION (6 rows)
--   days use M T W R F S (R = Thursday)
--   CS157A Sec 07 has capacity 2 for the full-section demo
--   MATH42 Sec 2 has no instructor yet (NULL = TBA)
--   CS46B Sec 1 runs in both Spring 2026 and Fall 2026: the same section
--   number in two terms (allowed because the key includes term)
--   Yuva Athur teaches two sections at different times (MW and TR)
-- ------------------------------------------------------------
INSERT INTO Section (course_id, section_no, term, start_date, end_date, capacity, waitlist_capacity, days, start_time, end_time, location, instructor_id) VALUES
('CS157A', 7, 'Fall 2026',   '2026-08-20', '2026-12-08',  2,  3, 'MW', '12:00', '13:15', 'MQH 225', 1),
('CS157A', 1, 'Fall 2026',   '2026-08-20', '2026-12-08', 40, 10, 'TR', '09:00', '10:15', 'DH 450',  1),
('CS146',  1, 'Fall 2026',   '2026-08-20', '2026-12-08', 35,  5, 'MW', '10:30', '11:45', 'MH 222',  2),
('CS46B',  1, 'Fall 2026',   '2026-08-20', '2026-12-08', 30,  5, 'TR', '13:30', '14:45', 'SCI 311', 3),
('MATH42', 2, 'Fall 2026',   '2026-08-20', '2026-12-08', 30,  5, 'F',  '09:00', '11:45', 'MH 234',  NULL),
('CS46B',  1, 'Spring 2026', '2026-01-22', '2026-05-12', 30,  5, 'TR', '13:30', '14:45', 'SCI 311', 3);

-- ------------------------------------------------------------
-- UNIT_OVERRIDE (1 row)
--   Emma (1005) is approved by the Dean to take up to 21 units in
--   Fall 2026; everyone else has the normal 18-unit limit
-- ------------------------------------------------------------
INSERT INTO Unit_Override (student_id, term, max_units, approver_name, approver_role, approved_date) VALUES
(1005, 'Fall 2026', 21, 'Dr. Laura Kim', 'Dean', '2026-08-01');

-- ------------------------------------------------------------
-- ENROLLMENT (7 rows)
--   Ava and Ben fill both seats in CS157A Sec 07 (2 of 2)
--   Only completed enrollments have a grade
--   Chloe completed CS46B in Spring 2026 so she meets the CS46B
--   prerequisite for CS146 (her MATH42 prerequisite comes from a transfer course)
--   Emma's row shows a dropped class
--   The prerequisite trigger checks rows in order so Chloe's completed
--   CS46B row comes before her CS146 row
-- ------------------------------------------------------------
INSERT INTO Enrollment (student_id, course_id, term, section_no, status, grade) VALUES
(1003, 'CS46B', 'Spring 2026', 1, 'completed', 'B'),
(1001, 'CS157A', 'Fall 2026', 7, 'enrolled',  NULL),
(1002, 'CS157A', 'Fall 2026', 7, 'enrolled',  NULL),
(1003, 'CS146', 'Fall 2026',  1, 'enrolled',  NULL),
(1004, 'CS46B', 'Fall 2026',  1, 'enrolled',  NULL),
(1001, 'MATH42', 'Fall 2026', 2, 'completed', 'A-'),
(1005, 'CS46B', 'Fall 2026',  1, 'dropped',   NULL);

-- ------------------------------------------------------------
-- WAITLIST (3 rows)
--   3 students waiting for CS157A Sec 07 in order (the waitlist is full: 3 of 3)
--   Chloe is position 1 so she gets the next open seat
-- ------------------------------------------------------------
INSERT INTO Waitlist (student_id, course_id, term, section_no, position) VALUES
(1003, 'CS157A', 'Fall 2026', 7, 1),
(1004, 'CS157A', 'Fall 2026', 7, 2),
(1005, 'CS157A', 'Fall 2026', 7, 3);

-- ------------------------------------------------------------
-- TRANSFER_COURSE (2 rows)
--   Classes taken at another school that count for a course here
-- ------------------------------------------------------------
INSERT INTO Transfer_Course (grade, student_id, course_id) VALUES
('A',  1002, 'CS46A'),
('B+', 1003, 'MATH42');

-- ------------------------------------------------------------
-- AP_CREDIT (2 rows)
--   AP exam scores that count for a course here
-- ------------------------------------------------------------
INSERT INTO AP_Credit (score, student_id, course_id) VALUES
(5, 1004, 'CS46A'),
(4, 1005, 'MATH42');

-- ------------------------------------------------------------
-- MAJOR_COURSE_OFFERING (8 rows)
--   Which courses belong to which majors
-- ------------------------------------------------------------
INSERT INTO Major_Course_Offering (major_id, course_id) VALUES
(1, 'CS46A'), (1, 'CS46B'), (1, 'CS146'), (1, 'CS157A'), (1, 'MATH42'),  -- Computer Science
(2, 'CS46A'), (2, 'CS157A'),                                             -- Software Engineering
(3, 'MATH42');                                                           -- Mathematics

-- ------------------------------------------------------------
-- STUDENT_MAJOR (6 rows)
--   Emma (1005) is a double major: Mathematics and Computer Science
-- ------------------------------------------------------------
INSERT INTO Student_Major (student_id, major_id) VALUES
(1001, 1), (1002, 1), (1003, 2), (1004, 1), (1005, 3), (1005, 1);

-- ------------------------------------------------------------
-- COURSE_PREREQUISITE (4 rows)
--   Chain: CS46A -> CS46B -> CS146 -> CS157A and MATH42 -> CS146
--   The CS157A requirement can be waived (override = TRUE)
-- ------------------------------------------------------------
INSERT INTO Course_Prerequisite (course_id, prereq_course_id, min_grade, override) VALUES
('CS46B',  'CS46A',  'C-', FALSE),
('CS146',  'CS46B',  'C-', FALSE),
('CS146',  'MATH42', 'C-', FALSE),
('CS157A', 'CS146',  'C-', TRUE);