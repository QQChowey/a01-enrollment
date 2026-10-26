-- ============================================================
-- 02_demo_checks.sql: the "proof in the database" for each demo step.
-- Keep this file open beside the app terminal in VS Code and run one
-- statement at a time (SQLTools, pgAdmin Query Tool, or psql).
-- Written for NoTown Org; rewrite each check for your own tables.
-- ============================================================

-- Step 1 - Register: the newest people, including the one just added
SELECT person_id, first_name, last_name, email, org_id, since, title
FROM person
ORDER BY person_id DESC
LIMIT 3;

-- Step 2 - Validation: the duplicate was not stored (expect 1)
SELECT COUNT(*) FROM person WHERE email = 'you@notownhq.com';

-- Step 3 - Search: the plan PostgreSQL chose for the app's search
EXPLAIN ANALYZE
SELECT person_id, first_name, last_name, email, title, org_id
FROM person
WHERE last_name LIKE 'Mo%'
ORDER BY last_name, first_name;

-- Steps 4 and 5 - Transaction: run BEFORE and AFTER, compare
SELECT account_number, balance FROM accounts ORDER BY account_number;

SELECT person_id, operation_id, account_number, amount, fund_date
FROM funds
ORDER BY operation_id, account_number;

-- Reset: run sql/01_notown_org.sql again to start over with the original data.
