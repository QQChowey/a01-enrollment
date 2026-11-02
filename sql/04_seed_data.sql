-- Name:		  02_sample_data
-- Project:		  A01-Enrollment for CS157A, Sec 07
-- Description:   Inserts sample data into all 12 tables. Run after 01_create_tables on an empty database.
-- Authors:       Quan Tang, Sebastian Lim, Kirsten Perez
-- Created:       November 1, 2026
-- Last edited:   November 1, 2026

-- Student: 5 students
INSERT INTO Student (student_id, first_name, last_name, address, phone_number, email) VALUES
(1001, 'Ava',   'Nguyen', '1 Washington Sq, San Jose, 95192',      '408-555-0101', 'ava.nguyen@sjsu.edu'),
(1002, 'Ben',   'Lopez',  '200 E Santa Clara St, San Jose, 95113', '408-555-0102', 'ben.lopez@sjsu.edu'),
(1003, 'Chloe', 'Park',   '75 S 4th St, San Jose, 95112',          '408-555-0103', 'chloe.park@sjsu.edu'),
(1004, 'Diego', 'Ramos',  '410 N 1st St, San Jose, 95112',         '408-555-0104', 'diego.ramos@sjsu.edu'),
(1005, 'Emma',  'Chen',   '88 E San Fernando St, San Jose, 95113', '408-555-0105', 'emma.chen@sjsu.edu');

-- Course: 5 courses
INSERT INTO Course (course_id, name, units, department) VALUES
('CS46A',  'Introduction to Programming',                 4, 'Computer Science'),
('CS46B',  'Introduction to Data Structures',             4, 'Computer Science'),
('CS146',  'Data Structures and Algorithms',              3, 'Computer Science'),
('CS157A', 'Introduction to Database Management Systems', 3, 'Computer Science'),
('MATH42', 'Discrete Mathematics',                        3, 'Mathematics');

-- Instructor: IDs are auto-filled as 1, 2, 3
INSERT INTO Instructor (first_name, last_name, email) VALUES
('Yuva',  'Athur', 'yuva.athur@sjsu.edu'),   -- instructor_id 1
('Maria', 'Gomez', 'maria.gomez@sjsu.edu'),  -- instructor_id 2
('James', 'Lee',   'james.lee@sjsu.edu');    -- instructor_id 3

-- Major: IDs are auto-filled as 1, 2, 3
INSERT INTO Major (name) VALUES
('Computer Science'),      -- major_id 1
('Software Engineering'),  -- major_id 2
('Mathematics');           -- major_id 3

-- Section: name is the term, days use M T W R F S (R = Thursday)
INSERT INTO Section (course_id, section_no, name, start_date, end_date, capacity, waitlist_capacity, days, start_time, end_time, location, instructor_id) VALUES
('CS157A', 7, 'Fall 2026', '2026-08-20', '2026-12-08',  2,  3, 'MW', '12:00', '13:15', 'MQH 225', 1),    -- capacity 2, used for the full-section demo
('CS157A', 1, 'Fall 2026', '2026-08-20', '2026-12-08', 40, 10, 'TR', '09:00', '10:15', 'DH 450',  1),
('CS146',  1, 'Fall 2026', '2026-08-20', '2026-12-08', 35,  5, 'MW', '10:30', '11:45', 'MH 222',  2),
('CS46B',  1, 'Fall 2026', '2026-08-20', '2026-12-08', 30,  5, 'TR', '13:30', '14:45', 'SCI 311', 3),
('MATH42', 2, 'Fall 2026', '2026-08-20', '2026-12-08', 30,  5, 'F',  '09:00', '11:45', 'MH 234',  NULL); -- instructor TBA

-- Enrollment: CS157A Sec 07 is full (2 of 2 seats taken)
INSERT INTO Enrollment (student_id, course_id, section_no, status, grade) VALUES
(1001, 'CS157A', 7, 'enrolled',  NULL),
(1002, 'CS157A', 7, 'enrolled',  NULL),
(1003, 'CS146',  1, 'enrolled',  NULL),
(1004, 'CS46B',  1, 'enrolled',  NULL),
(1001, 'MATH42', 2, 'completed', 'A-'),  -- only completed enrollments have a grade
(1005, 'CS46B',  1, 'dropped',   NULL);

-- Waitlist: 3 students waiting for CS157A Sec 07, in order
INSERT INTO Waitlist (student_id, course_id, section_no, position) VALUES
(1003, 'CS157A', 7, 1),  -- next to get a seat
(1004, 'CS157A', 7, 2),
(1005, 'CS157A', 7, 3);

-- Transfer_Course: classes taken at another school
INSERT INTO Transfer_Course (grade, student_id, course_id) VALUES
('A',  1002, 'CS46A'),
('B+', 1003, 'MATH42');

-- AP_Credit: AP exam scores that count for a course
INSERT INTO AP_Credit (score, student_id, course_id) VALUES
(5, 1004, 'CS46A'),
(4, 1005, 'MATH42');

-- Major_Course_Offering: which courses belong to which majors
INSERT INTO Major_Course_Offering (major_id, course_id) VALUES
(1, 'CS46A'), (1, 'CS46B'), (1, 'CS146'), (1, 'CS157A'), (1, 'MATH42'),  -- Computer Science
(2, 'CS46A'), (2, 'CS157A'),                                             -- Software Engineering
(3, 'MATH42');                                                           -- Mathematics

-- Student_Major: Emma (1005) is a double major
INSERT INTO Student_Major (student_id, major_id) VALUES
(1001, 1), (1002, 1), (1003, 2), (1004, 1), (1005, 3), (1005, 1);

-- Course_Prerequisite: CS46A -> CS46B -> CS146 -> CS157A, and MATH42 -> CS146
INSERT INTO Course_Prerequisite (course_id, prereq_course_id, min_grade, override) VALUES
('CS46B',  'CS46A',  'C-', FALSE),
('CS146',  'CS46B',  'C-', FALSE),
('CS146',  'MATH42', 'C-', FALSE),
('CS157A', 'CS146',  'C-', TRUE);   -- can be waived
