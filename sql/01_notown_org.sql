-- ============================================================
-- Notown OrgChart Schema — CS 157A Practical Lab
-- PostgreSQL DDL + Sample Data
--
-- Entities  : ORGANIZATION, PERSON, OPERATION, ACCOUNTS
-- Multivalued: PERSON_PHONE  (Rule 2.2 — Person may have several phone numbers)
-- Relationships merged in (Rule 5.2, arrow-side receives the FK):
--     Person  -> Assigned_To -- Organization   :  PERSON.Org_ID      (nullable — partial)
--     Person  -- Reports_To  -> Person          :  PERSON.Supervisor_ID (self-FK, nullable)
--     Person  -- Leads       -> Operation        :  OPERATION.Lead_Person_ID (nullable)
-- Ternary relationship, own table (never merges — Structural Reason Axiom):
--     FUNDS(Person_ID, Operation_ID, Account_Number)  — Person side capped
--
-- Weak entity LOG intentionally omitted from this lab.
-- ============================================================
DROP TABLE IF EXISTS OPERATION_LOG CASCADE;
DROP TABLE IF EXISTS FUNDS CASCADE;
DROP TABLE IF EXISTS PERSON_PHONE CASCADE;
DROP TABLE IF EXISTS OPERATION CASCADE;
DROP TABLE IF EXISTS ACCOUNTS CASCADE;
DROP TABLE IF EXISTS PERSON CASCADE;
DROP TABLE IF EXISTS ORGANIZATION CASCADE;
-- ------------------------------------------------------------
-- ORGANIZATION
-- ------------------------------------------------------------
CREATE TABLE ORGANIZATION (
    Org_ID          INTEGER         PRIMARY KEY,
    Org_Name        VARCHAR(100)    NOT NULL,
    Org_Type        VARCHAR(30)     NOT NULL
                       CHECK (Org_Type IN ('Division','Department','Business Unit','Subsidiary')),
    Founded_Date    DATE,
    Org_Code        VARCHAR(15)     NOT NULL,
    CONSTRAINT AK_Organization_Code UNIQUE (Org_Code)     -- Alternate Key
);

-- ------------------------------------------------------------
-- PERSON
--   Org_ID          : Rule 5.2 merge of Assigned_To (Person -> Org). Nullable = partial
--                      participation — an unassigned person is legal.
--   Supervisor_ID    : Rule 5.2 merge of the unary Reports_To relationship. Self-FK.
--                      NULL means "no tracked supervisor" — true of the CEO AND of the
--                      34 unlinked staff (Reports_To has partial participation on both
--                      sides). Use Title = 'CEO' to identify the CEO specifically, not
--                      Supervisor_ID IS NULL alone.
-- ------------------------------------------------------------
CREATE TABLE PERSON (
    Person_ID       INTEGER         PRIMARY KEY,
    First_Name      VARCHAR(50)     NOT NULL,
    Last_Name       VARCHAR(50)     NOT NULL,
    Email           VARCHAR(100)    NOT NULL,
    Age             INTEGER         CHECK (Age BETWEEN 18 AND 100),
    Org_ID          INTEGER         NULL REFERENCES ORGANIZATION(Org_ID) ON DELETE SET NULL,
    Since           DATE            NULL,
    Supervisor_ID   INTEGER         NULL REFERENCES PERSON(Person_ID) ON DELETE SET NULL,
    Title           VARCHAR(30)     NOT NULL,
    CONSTRAINT AK_Person_Email UNIQUE (Email),             -- Alternate Key
    CONSTRAINT CK_Since_requires_Org
        CHECK (Org_ID IS NOT NULL OR Since IS NULL)         -- Since only meaningful if assigned
);

-- ------------------------------------------------------------
-- PERSON_PHONE  — multivalued attribute (Rule 2.2)
--   A person may have zero, one, or several phone numbers.
--   Composite PK: the same number is not stored twice for one person.
-- ------------------------------------------------------------
CREATE TABLE PERSON_PHONE (
    Person_ID       INTEGER         NOT NULL REFERENCES PERSON(Person_ID) ON DELETE CASCADE,
    Phone_Number    VARCHAR(20)     NOT NULL,
    PRIMARY KEY (Person_ID, Phone_Number)
);

-- ------------------------------------------------------------
-- ACCOUNTS
-- ------------------------------------------------------------
CREATE TABLE ACCOUNTS (
    Account_Number  INTEGER         PRIMARY KEY,
    Account_Code    VARCHAR(20)     NOT NULL,
    Balance         NUMERIC(12,2)   NOT NULL CHECK (Balance >= 0),
    Account_Type    VARCHAR(20)     NOT NULL
                       CHECK (Account_Type IN ('Operating','Capital','Reserve','Grant')),
    CONSTRAINT AK_Account_Code UNIQUE (Account_Code)        -- Alternate Key
);

-- ------------------------------------------------------------
-- OPERATION
--   Lead_Person_ID  : Rule 5.2 merge of Leads (Person -- Leads -> Operation).
--                      Nullable = an operation may (briefly) have no lead assigned.
-- ------------------------------------------------------------
CREATE TABLE OPERATION (
    Operation_ID    INTEGER         PRIMARY KEY,
    Operation_Name  VARCHAR(100)    NOT NULL,
    Status          VARCHAR(20)     NOT NULL
                       CHECK (Status IN ('Active','Inactive','Completed')),
    Lead_Person_ID  INTEGER         NULL REFERENCES PERSON(Person_ID) ON DELETE SET NULL,
    Start_Date      DATE            NOT NULL
);

-- ------------------------------------------------------------
-- FUNDS — ternary relationship (Person, Operation, Accounts).
--   Own table: a ternary relationship is never merged into a participant
--   (Structural Reason Axiom — no single participant's key determines the others).
--   Person side is capped: for a given (Operation, Account) pair, at most one
--   Person authorized it — hence Person_ID is functionally determined by the
--   other two and the natural PK is the full triple.
-- ------------------------------------------------------------
CREATE TABLE FUNDS (
    Person_ID       INTEGER         NOT NULL REFERENCES PERSON(Person_ID),
    Operation_ID    INTEGER         NOT NULL REFERENCES OPERATION(Operation_ID),
    Account_Number  INTEGER         NOT NULL REFERENCES ACCOUNTS(Account_Number),
    Amount          NUMERIC(12,2)   NOT NULL CHECK (Amount > 0),
    Fund_Date       DATE            NOT NULL,
    PRIMARY KEY (Operation_ID, Account_Number)     -- Person determined by (Operation,Account)
);

-- ============================================================
-- WEAK ENTITY: OPERATION_LOG (owned by OPERATION)
--   Identifying relationship: Logged_In (OPERATION =existe=> Logged_In <==thick+arrow== LOG)
--   LOG cannot be identified by its own attributes alone — Log_Seq_No only
--   distinguishes one log row from another WITHIN one operation; the full
--   identifier is (Operation_ID, Log_Seq_No) together (Rule 3, ER-to-RM
--   Cheat Sheet). The identifying relationship itself (Logged_In) is never
--   given its own table — it is already encoded as the Operation_ID FK here.
--   LOG has total participation in Logged_In: a log entry cannot exist
--   without the operation it logs, hence Operation_ID is NOT NULL and
--   ON DELETE CASCADE (deleting an operation deletes its log history with it
--   — the opposite policy from PERSON.Org_ID's ON DELETE SET NULL, because a
--   log entry has no independent existence the way a person does).
-- ============================================================

CREATE TABLE OPERATION_LOG (
    Operation_ID    INTEGER         NOT NULL REFERENCES OPERATION(Operation_ID) ON DELETE CASCADE,
    Log_Seq_No      INTEGER         NOT NULL,
    Log_Date        DATE            NOT NULL,
    Author          VARCHAR(100)    NOT NULL,
    Summary         VARCHAR(300)    NOT NULL,
    PRIMARY KEY (Operation_ID, Log_Seq_No)      -- owner's PK + partial key, together
);

-- ============================================================
-- SAMPLE DATA
-- ============================================================

-- ORGANIZATION (10 rows)
INSERT INTO ORGANIZATION (Org_ID, Org_Name, Org_Type, Founded_Date, Org_Code) VALUES
    (1, 'Rodriguez, Figueroa and Sanchez Group', 'Division', '2013-09-05', 'ORG-001'),
    (2, 'Rhodes PLC Unit', 'Department', '2012-12-10', 'ORG-002'),
    (3, 'Johnson-Davis Division', 'Department', '2014-12-25', 'ORG-003'),
    (4, 'Johnson, Gonzalez and Santos Group', 'Division', '2019-05-10', 'ORG-004'),
    (5, 'Cole LLC', 'Division', '2023-01-21', 'ORG-005'),
    (6, 'Blake and Sons Group', 'Division', '2021-07-01', 'ORG-006'),
    (7, 'Ramirez-Lewis Division', 'Department', '2022-05-31', 'ORG-007'),
    (8, 'Davis Inc Group', 'Department', '2016-10-01', 'ORG-008'),
    (9, 'Munoz-Roman', 'Department', '2021-12-10', 'ORG-009'),
    (10, 'Martinez, Nielsen and Miller', 'Business Unit', '2015-10-31', 'ORG-010');

-- PERSON (50 rows) — inserted WITHOUT Supervisor_ID first to avoid forward-reference issues,
-- then Supervisor_ID is set in a second pass (self-referencing FK).
INSERT INTO PERSON (Person_ID, First_Name, Last_Name, Email, Age, Org_ID, Since, Title) VALUES
    (1, 'Courtney', 'Mcclure', 'courtney.mcclure1@notownhq.com', 45, 1, '2018-09-06', 'CEO'),
    (2, 'Michael', 'Lee', 'michael.lee2@notownhq.com', 48, 3, '2021-05-22', 'Manager'),
    (3, 'Chad', 'Stanley', 'chad.stanley3@notownhq.com', 43, 6, '2019-05-10', 'Manager'),
    (4, 'Kendra', 'Galloway', 'kendra.galloway4@notownhq.com', 41, 3, '2022-01-09', 'Manager'),
    (5, 'Melissa', 'Delacruz', 'melissa.delacruz5@notownhq.com', 38, 6, '2023-06-17', 'Manager'),
    (6, 'Norman', 'Chavez', 'norman.chavez6@notownhq.com', 47, 2, '2019-07-21', 'Manager'),
    (7, 'Mary', 'Martin', 'mary.martin7@notownhq.com', 35, 2, '2023-11-01', 'Employee'),
    (8, 'Michael', 'Santiago', 'michael.santiago8@notownhq.com', 43, 6, '2024-02-25', 'Employee'),
    (9, 'Jacqueline', 'Sutton', 'jacqueline.sutton9@notownhq.com', 25, 5, '2025-07-31', 'Employee'),
    (10, 'Charles', 'Reid', 'charles.reid10@notownhq.com', 41, 8, '2025-06-10', 'Employee'),
    (11, 'Amanda', 'Sanchez', 'amanda.sanchez11@notownhq.com', 36, 2, '2024-09-29', 'Employee'),
    (12, 'Steven', 'Nelson', 'steven.nelson12@notownhq.com', 41, 2, '2024-06-25', 'Employee'),
    (13, 'Sara', 'Watts', 'sara.watts13@notownhq.com', 44, 5, '2024-07-29', 'Employee'),
    (14, 'Jeffrey', 'Nguyen', 'jeffrey.nguyen14@notownhq.com', 35, 10, '2023-04-27', 'Employee'),
    (15, 'Kayla', 'Brown', 'kayla.brown15@notownhq.com', 30, 10, '2024-05-30', 'Employee'),
    (16, 'Lydia', 'Trujillo', 'lydia.trujillo16@notownhq.com', 25, 2, '2023-03-21', 'Employee'),
    (17, 'Richard', 'Jones', 'richard.jones17@notownhq.com', 27, 5, '2023-05-27', 'Coordinator'),
    (18, 'Robin', 'Bradley', 'robin.bradley18@notownhq.com', 39, 7, '2021-01-27', 'Administrator'),
    (19, 'Jennifer', 'Lewis', 'jennifer.lewis19@notownhq.com', 32, 6, '2023-08-28', 'Senior Associate'),
    (20, 'Victor', 'Wilkerson', 'victor.wilkerson20@notownhq.com', 26, 5, '2020-10-06', 'Associate'),
    (21, 'Dawn', 'Thomas', 'dawn.thomas21@notownhq.com', 32, 4, '2021-01-24', 'Administrator'),
    (22, 'Donald', 'Mcgee', 'donald.mcgee22@notownhq.com', 36, 9, '2020-11-22', 'Senior Associate'),
    (23, 'Amber', 'Burgess', 'amber.burgess23@notownhq.com', 36, 1, '2023-07-24', 'Analyst'),
    (24, 'Ross', 'Silva', 'ross.silva24@notownhq.com', 39, 7, '2023-05-20', 'Senior Analyst'),
    (25, 'Michael', 'Osborn', 'michael.osborn25@notownhq.com', 42, 10, '2024-10-27', 'Coordinator'),
    (26, 'Devon', 'Snyder', 'devon.snyder26@notownhq.com', 51, 7, '2024-02-18', 'Associate'),
    (27, 'Katelyn', 'Callahan', 'katelyn.callahan27@notownhq.com', 57, 4, '2023-04-21', 'Specialist'),
    (28, 'Eric', 'Moore', 'eric.moore28@notownhq.com', 47, 7, '2021-04-01', 'Senior Associate'),
    (29, 'Erin', 'Carlson', 'erin.carlson29@notownhq.com', 54, 3, '2022-10-06', 'Administrator'),
    (30, 'Paul', 'Carlson', 'paul.carlson30@notownhq.com', 25, NULL, NULL, 'Senior Analyst'),
    (31, 'Taylor', 'King', 'taylor.king31@notownhq.com', 49, 3, '2025-07-15', 'Senior Analyst'),
    (32, 'Angela', 'Dunlap', 'angela.dunlap32@notownhq.com', 51, 10, '2024-03-13', 'Specialist'),
    (33, 'Erin', 'Wilson', 'erin.wilson33@notownhq.com', 29, 1, '2021-01-27', 'Specialist'),
    (34, 'Nicole', 'Potter', 'nicole.potter34@notownhq.com', 29, 6, '2025-05-15', 'Specialist'),
    (35, 'Kayla', 'Peterson', 'kayla.peterson35@notownhq.com', 22, 8, '2021-10-01', 'Specialist'),
    (36, 'Kelly', 'Moore', 'kelly.moore36@notownhq.com', 54, 3, '2021-07-09', 'Senior Analyst'),
    (37, 'Aaron', 'Bowen', 'aaron.bowen37@notownhq.com', 54, 5, '2023-03-24', 'Coordinator'),
    (38, 'Jennifer', 'Stanton', 'jennifer.stanton38@notownhq.com', 56, 3, '2021-03-03', 'Analyst'),
    (39, 'Kathleen', 'Romero', 'kathleen.romero39@notownhq.com', 23, 8, '2025-09-28', 'Senior Analyst'),
    (40, 'Daniel', 'Garrett', 'daniel.garrett40@notownhq.com', 37, 5, '2024-03-17', 'Analyst'),
    (41, 'Meagan', 'Romero', 'meagan.romero41@notownhq.com', 27, 10, '2020-10-22', 'Senior Analyst'),
    (42, 'James', 'Brooks', 'james.brooks42@notownhq.com', 56, 2, '2024-10-01', 'Associate'),
    (43, 'Evan', 'Ashley', 'evan.ashley43@notownhq.com', 57, 8, '2022-12-09', 'Associate'),
    (44, 'Sandra', 'Sellers', 'sandra.sellers44@notownhq.com', 49, 10, '2025-08-02', 'Coordinator'),
    (45, 'Carol', 'Burns', 'carol.burns45@notownhq.com', 41, 4, '2021-09-13', 'Consultant'),
    (46, 'Daniel', 'Cox', 'daniel.cox46@notownhq.com', 50, 6, '2022-10-14', 'Administrator'),
    (47, 'Tricia', 'Roman', 'tricia.roman47@notownhq.com', 26, 4, '2025-05-24', 'Senior Associate'),
    (48, 'John', 'Allen', 'john.allen48@notownhq.com', 57, NULL, NULL, 'Coordinator'),
    (49, 'Ashley', 'Miller', 'ashley.miller49@notownhq.com', 26, 1, '2024-07-17', 'Analyst'),
    (50, 'Jessica', 'Cabrera', 'jessica.cabrera50@notownhq.com', 43, 1, '2025-04-09', 'Senior Analyst');

-- Second pass: set Supervisor_ID now that all Person rows exist
UPDATE PERSON SET Supervisor_ID = 1 WHERE Person_ID = 2;
UPDATE PERSON SET Supervisor_ID = 1 WHERE Person_ID = 3;
UPDATE PERSON SET Supervisor_ID = 1 WHERE Person_ID = 4;
UPDATE PERSON SET Supervisor_ID = 1 WHERE Person_ID = 5;
UPDATE PERSON SET Supervisor_ID = 1 WHERE Person_ID = 6;
UPDATE PERSON SET Supervisor_ID = 2 WHERE Person_ID = 7;
UPDATE PERSON SET Supervisor_ID = 3 WHERE Person_ID = 8;
UPDATE PERSON SET Supervisor_ID = 4 WHERE Person_ID = 9;
UPDATE PERSON SET Supervisor_ID = 5 WHERE Person_ID = 10;
UPDATE PERSON SET Supervisor_ID = 6 WHERE Person_ID = 11;
UPDATE PERSON SET Supervisor_ID = 2 WHERE Person_ID = 12;
UPDATE PERSON SET Supervisor_ID = 3 WHERE Person_ID = 13;
UPDATE PERSON SET Supervisor_ID = 4 WHERE Person_ID = 14;
UPDATE PERSON SET Supervisor_ID = 5 WHERE Person_ID = 15;
UPDATE PERSON SET Supervisor_ID = 6 WHERE Person_ID = 16;

-- PERSON_PHONE — multivalued attribute (64 rows)
INSERT INTO PERSON_PHONE (Person_ID, Phone_Number) VALUES
    (1, '723-430-9805'),
    (2, '009-788-2081'),
    (3, '219-136-1939'),
    (4, '909-169-9854'),
    (5, '353-462-4751'),
    (5, '079-911-8384'),
    (6, '251-354-2784'),
    (6, '980-841-2411'),
    (7, '824-493-5348'),
    (7, '740-164-0052'),
    (8, '427-868-0112'),
    (9, '805-982-6204'),
    (10, '505-331-5869'),
    (12, '232-260-2563'),
    (12, '421-607-3375'),
    (13, '433-036-5414'),
    (14, '586-850-1429'),
    (15, '401-965-5698'),
    (15, '169-340-6088'),
    (17, '356-159-5148'),
    (17, '465-648-2366'),
    (18, '299-468-0443'),
    (18, '699-577-7387'),
    (20, '214-895-1343'),
    (20, '320-037-9176'),
    (21, '936-763-2016'),
    (21, '328-708-3172'),
    (22, '788-957-9868'),
    (23, '727-743-4873'),
    (24, '471-434-5581'),
    (25, '223-623-1665'),
    (26, '876-036-6909'),
    (27, '670-546-6889'),
    (28, '373-467-0656'),
    (28, '272-980-6990'),
    (30, '162-720-4653'),
    (30, '755-646-4170'),
    (31, '805-310-0330'),
    (31, '923-271-9374'),
    (33, '529-912-4190'),
    (33, '496-631-9314'),
    (34, '919-058-6518'),
    (37, '506-716-5726'),
    (37, '284-987-7694'),
    (38, '531-473-7996'),
    (39, '507-527-3545'),
    (40, '494-808-3136'),
    (41, '783-777-0143'),
    (41, '634-957-8856'),
    (42, '855-744-4313'),
    (42, '518-233-7498'),
    (42, '941-343-5240'),
    (43, '824-008-4271'),
    (45, '094-777-5204'),
    (46, '711-671-9022'),
    (46, '941-318-6999'),
    (46, '386-774-9649'),
    (47, '909-133-4123'),
    (47, '281-206-7974'),
    (48, '034-471-3493'),
    (49, '618-324-2102'),
    (49, '499-471-7464'),
    (50, '887-719-0659'),
    (50, '401-399-0490');

-- ACCOUNTS (8 rows)
INSERT INTO ACCOUNTS (Account_Number, Account_Code, Balance, Account_Type) VALUES
    (1, 'ACC-1001', 485919.21, 'Operating'),
    (2, 'ACC-1002', 386589.0, 'Operating'),
    (3, 'ACC-1003', 72564.05, 'Grant'),
    (4, 'ACC-1004', 276282.67, 'Capital'),
    (5, 'ACC-1005', 75595.81, 'Operating'),
    (6, 'ACC-1006', 433104.15, 'Operating'),
    (7, 'ACC-1007', 317765.8, 'Capital'),
    (8, 'ACC-1008', 231699.0, 'Capital');

-- OPERATION (5 rows) — Lead_Person_ID references PERSON, inserted after PERSON exists
INSERT INTO OPERATION (Operation_ID, Operation_Name, Status, Lead_Person_ID, Start_Date) VALUES
    (1, 'Market Expansion', 'Active', 16, '2026-01-05'),
    (2, 'Product Launch', 'Active', 3, '2024-04-01'),
    (3, 'Cost Optimization', 'Active', 4, '2025-04-13'),
    (4, 'Digital Transformation', 'Inactive', 5, '2025-01-19'),
    (5, 'Supply Chain Revamp', 'Completed', 14, '2024-07-23');

-- FUNDS — ternary relationship, 10 rows, distinct (Operation,Account) combinations
INSERT INTO FUNDS (Person_ID, Operation_ID, Account_Number, Amount, Fund_Date) VALUES
    (6, 1, 1, 91205.28, '2026-09-19'),
    (6, 2, 1, 16887.59, '2025-08-06'),
    (1, 3, 1, 89632.48, '2026-05-09'),
    (6, 1, 2, 50873.63, '2026-08-30'),
    (6, 2, 6, 39609.46, '2025-08-31'),
    (8, 2, 5, 71297.56, '2025-07-17'),
    (3, 1, 8, 95068.09, '2025-05-14'),
    (4, 3, 2, 132494.19, '2024-12-07'),
    (7, 3, 3, 68536.76, '2025-01-17'),
    (3, 5, 3, 44490.49, '2025-07-19');

-- Sample log entries — several per operation, demonstrating the weak
-- entity's whole point: Log_Seq_No (1, 2, 3, ...) only means something
-- relative to its owning Operation_ID; Log_Seq_No=1 recurs across every
-- operation without collision, because the real key is the pair.
INSERT INTO OPERATION_LOG (Operation_ID, Log_Seq_No, Log_Date, Author, Summary) VALUES
    (1, 1, '2024-02-03', 'Lydia Trujillo',  'Kicked off market analysis for target regions.'),
    (1, 2, '2024-03-18', 'Lydia Trujillo',  'Completed competitor pricing review.'),
    (1, 3, '2024-05-02', 'Courtney Mcclure','Exec review: approved expansion into APAC.'),
    (2, 1, '2024-01-10', 'Chad Stanley',    'Product spec finalized with engineering.'),
    (2, 2, '2024-02-14', 'Chad Stanley',    'Beta launched to internal test group.'),
    (3, 1, '2023-11-05', 'Kendra Galloway', 'Identified three vendor contracts for renegotiation.'),
    (3, 2, '2024-01-22', 'Kendra Galloway', 'Renegotiated contract with Vendor A, 12% savings.'),
    (3, 3, '2024-04-09', 'Mary Martin',     'Quarterly savings report submitted to finance.'),
    (4, 1, '2023-08-01', 'Melissa Delacruz','Project paused pending budget review.'),
    (5, 1, '2022-09-15', 'Jeffrey Nguyen',  'Supply chain audit kicked off.'),
    (5, 2, '2022-12-01', 'Jeffrey Nguyen',  'New logistics partner selected.'),
    (5, 3, '2023-03-20', 'Jeffrey Nguyen',  'Rollout completed across all warehouses.'),
    (5, 4, '2023-04-01', 'Courtney Mcclure','Operation formally closed out.');



-- ============================================================
-- EXAMPLE QUERIES — a few starting points
-- ============================================================

-- The org hierarchy: CEO, managers, and their reports
-- SELECT e.Person_ID, e.First_Name, e.Last_Name, e.Title,
--        s.First_Name || ' ' || s.Last_Name AS supervisor
-- FROM PERSON e LEFT JOIN PERSON s ON e.Supervisor_ID = s.Person_ID
-- ORDER BY s.Person_ID NULLS FIRST;

-- Each manager's report count
-- SELECT s.Person_ID, s.First_Name, s.Last_Name, COUNT(e.Person_ID) AS num_reports
-- FROM PERSON s JOIN PERSON e ON e.Supervisor_ID = s.Person_ID
-- GROUP BY s.Person_ID, s.First_Name, s.Last_Name;

-- People with more than one phone number (multivalued attribute)
-- SELECT p.Person_ID, p.First_Name, p.Last_Name, COUNT(*) AS num_phones
-- FROM PERSON p JOIN PERSON_PHONE pp ON pp.Person_ID = p.Person_ID
-- GROUP BY p.Person_ID, p.First_Name, p.Last_Name
-- HAVING COUNT(*) > 1;

-- DIVISION: accounts that funded EVERY currently active operation
-- (the Intro SQL lecture's own worked example, against this data)
-- SELECT Account_Number FROM (
--     SELECT DISTINCT Account_Number, Operation_ID FROM FUNDS
-- ) AS AF
-- WHERE NOT EXISTS (
--     SELECT Operation_ID FROM OPERATION WHERE Status = 'Active'
--     EXCEPT
--     SELECT Operation_ID FROM FUNDS f2 WHERE f2.Account_Number = AF.Account_Number
-- )
-- GROUP BY Account_Number;

-- Who leads each operation, and its funding accounts
-- SELECT o.Operation_Name, o.Status, p.First_Name || ' ' || p.Last_Name AS lead,
--        a.Account_Code, f.Amount
-- FROM OPERATION o
--   LEFT JOIN PERSON p ON o.Lead_Person_ID = p.Person_ID
--   JOIN FUNDS f ON f.Operation_ID = o.Operation_ID
--   JOIN ACCOUNTS a ON a.Account_Number = f.Account_Number
-- ORDER BY o.Operation_ID;

