"""funding_service.py: the worked example of a SIGNATURE TRANSACTION.

"Fund an operation" takes money from an account and records who authorized
it, for which operation:

  1. take the money       UPDATE accounts SET balance = balance - amount ...
  2. record the funding   INSERT INTO funds ...
  3. COMMIT               (or ROLLBACK if any step fails)

Both writes happen, or neither does. Ways it can fail on purpose:
  - amount larger than the balance  -> CHECK (balance >= 0) rejects step 1
  - the same operation + account pair funded twice
                                    -> PRIMARY KEY on FUNDS rejects step 2,
                                       AFTER step 1 already ran; the rollback
                                       puts the balance back
  - two users at once               -> the UPDATE locks the account row until
                                       COMMIT, so a second user's UPDATE on the
                                       same account waits its turn

Your project needs its own signature transaction. Copy the SHAPE of this
function (write, write, commit or roll back), not its tables.
"""
import psycopg

import db


def fund(settings, person_id, operation_id, account_number, amount, pause_before_commit):
    """Runs the transaction. If pause_before_commit is True, it waits for Enter
    before committing, so you can start the same transaction in a second
    terminal and watch it wait."""
    print_balance(settings, account_number)
    with db.connect(settings) as conn:
        # psycopg starts a transaction automatically: nothing is permanent
        # until conn.commit().
        try:
            # Step 1: take the money. The CHECK (balance >= 0) is the real guard.
            cur = conn.execute(
                "UPDATE accounts SET balance = balance - %s WHERE account_number = %s",
                (amount, account_number),
            )
            if cur.rowcount == 0:
                conn.rollback()
                print(f"No account {account_number}. Nothing changed.")
                return
            print(f"  Step 1 done: balance reduced by {amount}")

            # Step 2: record the funding.
            conn.execute(
                "INSERT INTO funds (person_id, operation_id, account_number, amount, fund_date) "
                "VALUES (%s, %s, %s, %s, CURRENT_DATE)",
                (person_id, operation_id, account_number, amount),
            )
            print("  Step 2 done: funding recorded")

            if pause_before_commit:
                input("  Paused before COMMIT. Press Enter to commit... ")

            conn.commit()
            print("COMMITTED. Both writes are now permanent.")
        except psycopg.Error as e:
            conn.rollback()
            print("ROLLED BACK. " + db.explain_error(e))
            print("Nothing from this transaction was kept.")
    print_balance(settings, account_number)


def print_balance(settings, account_number):
    """Reads the balance in a fresh connection, to show what was (or wasn't) kept."""
    with db.connect(settings) as conn:
        row = conn.execute(
            "SELECT balance FROM accounts WHERE account_number = %s", (account_number,)
        ).fetchone()
    if row:
        print(f"  Account {account_number} balance: {row[0]}")
