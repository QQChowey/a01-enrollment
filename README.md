# NoTown Org Console Scaffold (Python)

CS 157A, Fall 2026: Final Group Project starter

A small console application that connects to the **NoTown Org** PostgreSQL database and shows, working, every piece your project demo needs: registering a user, a database rule rejecting bad input, a search, its query plan, and a transaction that commits or rolls back as a whole, including when two users run it at once.

Java is the standard course language; this Python version is the optional alternative and does exactly the same things.

Use it in two stages:

1. **Get it running on NoTown Org.** This proves your tools work before your own schema exists. A screenshot of it running is part of the 10/25 check-in.
2. **Turn it into your project.** Replace the NoTown tables and queries with your own (see *Make it your project*).

The scaffold is provided by the course; you may build on it freely.

**Stuck on setup?** Email the instructor with a screenshot of the error. You will not lose points for a setup problem you report, and an extension is available. The error screenshot also counts for the 10/25 check-in.

---

## 1. What you need

| Tool | Notes |
| --- | --- |
| PostgreSQL 16 or newer, with pgAdmin | From the PostgreSQL install you did earlier this term. Note the password you set for the `postgres` user |
| Python 3.10 or newer | From python.org. On Windows, tick **Add python.exe to PATH** in the installer |
| VS Code | With the **Python** extension (by Microsoft) |
| psycopg 3 | The PostgreSQL driver for Python; installed in step 5 |

Check Python in a terminal (on macOS and Linux, use `python3`):

```
python --version
```

## 2. Create and load the database

**In pgAdmin:**

1. Right-click **Databases**, choose **Create → Database**, and name it `notown_org`.
2. Select `notown_org`, open **Tools → Query Tool**, open `sql/01_notown_org.sql`, and run it (F5).
3. Check: `SELECT COUNT(*) FROM person;` should return **50**.

**Or in a terminal:**

```
createdb -U postgres notown_org
psql -U postgres -d notown_org -f sql/01_notown_org.sql
```

Running `01_notown_org.sql` again at any time resets the data.

## 3. Set your connection

Copy `db.ini.example` to a new file named `db.ini` in the same folder, and replace `YOUR_PASSWORD_HERE` with your PostgreSQL password. If you installed PostgreSQL on a port other than 5432, change `port` too.

`db.ini` holds your password. Do not share or upload it.

## 4. Open the folder in VS Code

**File → Open Folder** and choose this scaffold folder itself (the one containing `app.py`), not a folder above it. Then open the Terminal panel (**View → Terminal**).

## 5. Create a virtual environment and install the driver

A virtual environment keeps this project's packages separate from the rest of your computer. In the VS Code terminal:

**Windows:**

```
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

**macOS / Linux:**

```
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Then tell VS Code to use it: Command Palette (**Ctrl+Shift+P**, or **Cmd+Shift+P** on a Mac), **Python: Select Interpreter**, and pick the one inside `.venv`.

## 6. Run in VS Code

Open `app.py` and click **Run Python File** (the triangle, top right), or open **Run and Debug** and start **Run NoTown App**. The app runs in the Terminal panel; type your answers there.

You should see:

```
Connected to notown_org on localhost:5432
Server: PostgreSQL 16...
=== NoTown Org ===
```

**That screen is your 10/25 check-in screenshot.**

## 7. Or run from a terminal

With the virtual environment active, from this folder: `python app.py` (or `python3 app.py`).

## 8. Try the demo steps

Each menu option is one part of the standard demo script. Keep `sql/02_demo_checks.sql` open beside the app to show the proof in the database.

| Demo step | Menu | Try this | What you should see |
| --- | --- | --- | --- |
| 1. Register | 1 | Your own name, email `you@notownhq.com`, age 25, organization 3, title Analyst | A new Person_ID (51 on fresh data) |
| 2. Validation | 1 | The same email again | Rejected by the UNIQUE rule; no new row |
| 2. Validation | 1 | Age 150, or organization 99 | Rejected by the CHECK rule, or by the foreign key |
| 3. Search | 2, then 4 | `Mo` | Two people named Moore, then the plan from EXPLAIN ANALYZE |
| 4. Transaction succeeds | 3 | Person 6, operation 4, account 7, amount 1000, no pause | COMMITTED; account 7's balance drops by 1000 |
| 5. Transaction fails | 3 | Person 6, operation 1, account 1, amount 500 | ROLLED BACK: that pair is already funded. Balance unchanged, even though step 2 had already run |
| 5. Transaction fails | 3 | Person 6, operation 4, account 3, amount 999999999 | ROLLED BACK: the balance cannot go below zero |

**Two users at once.** Start the app in two terminals (in VS Code, the **+** in the Terminal panel opens a second one; activate the virtual environment there too, then run `python app.py`).

1. In terminal A: menu 3, account 8, and answer **y** to pause before commit. A has updated account 8 but not committed, so it holds a lock on that row.
2. In terminal B: menu 3, also account 8, no pause. B stops and waits: its UPDATE cannot change the row A has locked.
3. Press Enter in A. A commits, B continues, and B's starting balance already includes A's change.

Nothing was lost or counted twice, because an UPDATE locks the row it changes until COMMIT, so the second user had to wait.

## 9. Run the tests

`test_scaffold.py` holds seven small tests, one per behavior you will demonstrate: connect, register, a rejected duplicate, search, a transaction that commits, a transaction that rolls back, and two users at once. Each test checks the result **in the database** and cleans up after itself. Python's built-in `unittest` runs them; nothing extra to install.

From a terminal in this folder (with your virtual environment active): `python -m unittest -v test_scaffold`

You should see seven lines ending in `ok`, then `Ran 7 tests` and `OK`.

**Test first.** For each feature you add to your project, write the test before the code: state the behavior in one sentence, write a test that checks the database, watch it **fail**, write the code, watch it **pass**. A failing test you wrote first is the proof that the test can catch a bug.

If tests fail on a fresh NoTown database, run `sql/01_notown_org.sql` again to reset it, then retest.

## 10. Code tour

| File | What it does |
| --- | --- |
| `app.py` | The menu loop and input. Start reading here |
| `db.py` | Reads `db.ini`, opens connections, turns database errors into readable messages |
| `person_service.py` | Register and search, with parameterized statements |
| `funding_service.py` | The signature transaction: write, write, commit or roll back |
| `explain_helper.py` | Runs EXPLAIN ANALYZE on the search query |
| `sql/01_notown_org.sql` | Creates and loads the NoTown Org database |
| `sql/02_demo_checks.sql` | The proof query for each demo step |
| `test_scaffold.py` | Seven indicative tests; copy the pattern for your own features |

## 11. Troubleshooting

| Message | Fix |
| --- | --- |
| `No module named 'psycopg'` | The virtual environment is not active or not selected. Activate it, run `pip install -r requirements.txt`, and select its interpreter in VS Code |
| Windows: running scripts is disabled (when activating) | Skip activation and use `.venv\Scripts\python -m pip install -r requirements.txt`, then `.venv\Scripts\python app.py` |
| `Could not read db.ini` | Create `db.ini` (step 3), and open this folder itself in VS Code so the app starts here |
| `password authentication failed` | Check `user` and `password` in `db.ini` |
| `Connection refused` | PostgreSQL is not running, or it uses another port. Check that pgAdmin can connect, and match `port` in `db.ini` |
| `database "notown_org" does not exist` | Create it (step 2), or fix `dbname` in `db.ini` |
| `python` is not recognized | Python is not on your PATH. Reinstall with **Add python.exe to PATH** ticked, or use `py` on Windows |

---

## Make it your project

The scaffold is plumbing: a connection, a menu, and one worked example of each thing your demo needs. Keep the shape, replace the tables.

1. **Write your schema as numbered SQL files** in `sql/`: `03_create_tables.sql`, `04_seed_data.sql`, and so on. Each file should run cleanly on an empty database, so any teammate can rebuild the whole database by running the files in order.
2. **Point the app at your database.** Create your project database in pgAdmin, run your SQL files, and change the database name in your connection settings.
3. **Rewrite one service at a time.** Registration and search first (demo steps 1 to 3), then your own signature transaction (steps 4 and 5). Copy the *shape* of the funding transaction (write, write, commit or roll back), not its tables.
4. **Rewrite `sql/02_demo_checks.sql`** so each demo step has its proof query.

**Sharing work with your team.** Git is optional. A shared folder (Google Drive, OneDrive) works, or a GitHub repository if your team already uses one. Either way, never share your connection settings file: it holds your password.

---

## Technical floor

Every project, whether one of the 20 ideas or your own, must meet every item. Tick them off as you build.

**Schema**

- [ ] At least 6 tables, including one many-to-many junction table with a composite key
- [ ] At least one of: a weak entity, an ISA hierarchy, or a recursive relationship
- [ ] Every foreign key has a deliberate ON DELETE policy (CASCADE, RESTRICT, or SET NULL), stated in the report
- [ ] At least 3 CHECK or UNIQUE constraints that encode real business rules
- [ ] At least one view and one trigger

**Data and performance**

- [ ] Your two main queries run with EXPLAIN ANALYZE, with a sentence on the plan PostgreSQL chose and why. On a small table a Seq Scan is expected, and explaining it earns full credit

**Optional stretch: indexes on larger data.** Not required and not graded. Seed 10,000 or more rows into one table, add an index, and show the plan before and after. Students who need help generating data can contact the instructor.

**Application**

- [ ] User registration with validation enforced by the database (for example, a duplicate email rejected by UNIQUE)
- [ ] A search screen backed by one of your two main queries
- [ ] One signature transaction: several writes that all commit or all roll back, with a rehearsed failure case: two users running it on the same row at the same moment
- [ ] Parameterized statements only, never SQL built from user input

**Process**

- [ ] Schema changes go through numbered SQL files that rebuild the database from scratch (version control such as Git is optional)
- [ ] A "Use of AI" statement with prompts listed, per the course policy

---

## Schema

*This section describes the NoTown Org example database. In your project, replace it with your own schema, written the same way.*

**Database:** `notown_org`, created by `sql/01_notown_org.sql`. The script drops and recreates every table, so running it again resets the data.

### Tables

| Table | What it holds | Primary key | Foreign keys (ON DELETE) | Other rules | Rows |
| --- | --- | --- | --- | --- | --- |
| ORGANIZATION | Units of the company | Org_ID | none | Org_Code UNIQUE (alternate key); Org_Type in Division, Department, Business Unit, Subsidiary | 10 |
| PERSON | Employees | Person_ID | Org_ID → ORGANIZATION (SET NULL); Supervisor_ID → PERSON (SET NULL) | Email UNIQUE (alternate key); Age between 18 and 100; Since may be set only if Org_ID is set | 50 |
| PERSON_PHONE | Phone numbers, several per person | (Person_ID, Phone_Number) | Person_ID → PERSON (CASCADE) | none | 64 |
| ACCOUNTS | Money accounts | Account_Number | none | Account_Code UNIQUE (alternate key); Balance ≥ 0; Account_Type in Operating, Capital, Reserve, Grant | 8 |
| OPERATION | Programs the company runs | Operation_ID | Lead_Person_ID → PERSON (SET NULL) | Status in Active, Inactive, Completed | 5 |
| FUNDS | Who authorized funding for which operation from which account | (Operation_ID, Account_Number) | Person_ID → PERSON, Operation_ID → OPERATION, Account_Number → ACCOUNTS (no policy stated, so the default NO ACTION blocks the delete) | Amount > 0 | 10 |
| OPERATION_LOG | Dated log entries for each operation | (Operation_ID, Log_Seq_No) | Operation_ID → OPERATION (CASCADE) | none | 13 |

### How the ER design became these tables

| ER element | Kind | Mapped to |
| --- | --- | --- |
| Assigned_To (Person to Organization) | Many-to-one, partial participation | PERSON.Org_ID, nullable: a person may be unassigned |
| Reports_To (Person to Person) | Recursive, partial on both sides | PERSON.Supervisor_ID, a foreign key to the same table |
| Leads (Person to Operation) | One person leads an operation | OPERATION.Lead_Person_ID, nullable |
| Funds (Person, Operation, Accounts) | Ternary relationship | Its own table, FUNDS. At most one person authorizes each (operation, account) pair, so the key is (Operation_ID, Account_Number) |
| Logged_In (Operation owns Log) | Weak entity with its identifying relationship | OPERATION_LOG, keyed by the owner's key plus Log_Seq_No; deleting an operation deletes its log |
| Phone | Multivalued attribute | Its own table, PERSON_PHONE |

### Design choices worth defending

These are the trade-offs an interviewer, or a classmate in Q&A, will ask about.

- **SET NULL versus CASCADE.** Deleting an organization leaves its people unassigned (SET NULL), because a person exists on their own. Deleting an operation deletes its log entries (CASCADE), because a log entry means nothing without its operation.
- **FUNDS has no stated delete policy.** The default (NO ACTION) means a person, operation, or account with funding history cannot be deleted. That may be the right rule for financial records, but in your project, choose and state each policy on purpose.
- **IDs are plain integers.** Nothing generates them, so the app computes the next Person_ID as the current maximum plus one. Two people registering at the same instant can collide, and the primary key rejects one. In your own tables, use `INTEGER GENERATED ALWAYS AS IDENTITY`.
- **Balance ≥ 0 is a database rule, not an app check.** The funding transaction relies on it: when a withdrawal would overdraw, the database refuses and the whole transaction rolls back.
- **Supervisor_ID is NULL for the CEO and for 34 staff with no tracked supervisor.** To find the CEO, filter on Title = 'CEO', not on a NULL supervisor.

### NoTown against the technical floor

NoTown is a working example, not a passing project. Checking it against the floor shows what your schema needs.

| Floor item | NoTown |
| --- | --- |
| At least 6 tables with a composite-key junction table | Yes: 7 tables; FUNDS has a composite key (a ternary relationship) |
| Weak entity, ISA, or recursive relationship | Yes: OPERATION_LOG is weak; Reports_To is recursive |
| A deliberate ON DELETE policy on every foreign key | No: FUNDS's three foreign keys use the default |
| At least 3 CHECK or UNIQUE rules | Yes: 10 of them |
| A view and a trigger | No |

---

## Project report sections

When this scaffold becomes your project, this README becomes your project's README and the outline of your written report. Fill in each section for your own application.

### Motivation and problem statement

*To be completed by your team.*

### Database design and schema

*Replace the NoTown Schema section above with your own.*

### ER diagram

*To be completed by your team.*

### Optimization strategies

*To be completed by your team.*

### User interactions

*To be completed by your team.*

### Lessons learnt and future scope

*To be completed by your team.*

### Use of AI

*To be completed by your team.*
