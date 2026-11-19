"""test_scaffold.py: indicative tests for the NoTown scaffold. No extra install needed.

Run from this folder:   python -m unittest -v test_scaffold

Each test states one behavior, runs it, and checks the result in the database
(not just in Python's return value). Each test also cleans up after itself, so
you can run this file as often as you like.

The pattern is always:
  1. note the starting state   2. do the action   3. check the database   4. clean up

Add one test of your own for every feature you build. Write the test FIRST,
watch it fail, then write the code that makes it pass.
"""
import contextlib
import io
import threading
import time
import unittest
from decimal import Decimal

import psycopg

import db
import funding_service
import person_service

SETTINGS = db.load_settings()


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


def balance(account):
    return scalar("SELECT balance FROM accounts WHERE account_number = %s", (account,))


def unique_email():
    return f"test.{time.time_ns()}@example.com"


def free_pairs(n, same_account=False):
    """Finds (operation, account) pairs not yet in FUNDS."""
    sql = ("SELECT o.operation_id, a.account_number FROM operation o CROSS JOIN accounts a "
           "WHERE a.balance > 1000 AND NOT EXISTS (SELECT 1 FROM funds f "
           "WHERE f.operation_id = o.operation_id AND f.account_number = a.account_number) "
           "ORDER BY a.account_number, o.operation_id")
    with db.connect(SETTINGS) as conn:
        rows = conn.execute(sql).fetchall()
    picked = []
    for op, acct in rows:
        if same_account and picked and picked[0][1] != acct:
            continue
        picked.append((op, acct))
        if len(picked) == n:
            return picked
    raise RuntimeError("Not enough unfunded pairs. Run sql/01_notown_org.sql to reset.")


def undo_fund(operation, account, amount):
    """Puts a test's funding back: delete the funds row (if any) and return the money."""
    with db.connect(SETTINGS) as conn:
        removed = conn.execute(
            "DELETE FROM funds WHERE operation_id = %s AND account_number = %s",
            (operation, account)).rowcount
        if removed:
            conn.execute("UPDATE accounts SET balance = balance + %s WHERE account_number = %s",
                         (amount, account))
        conn.commit()


class ScaffoldTests(unittest.TestCase):

    def test_1_connects(self):
        """Connects to the NoTown database"""
        self.assertEqual(scalar("SELECT 1"), 1)

    def test_2_register_stores_a_row(self):
        """Register stores a new row"""
        before = scalar("SELECT COUNT(*) FROM person")
        new_id = quiet(person_service.register, SETTINGS, "Test", "Student",
                       unique_email(), 25, 3, "Analyst")
        try:
            self.assertEqual(scalar("SELECT COUNT(*) FROM person"), before + 1)
            self.assertEqual(scalar("SELECT COUNT(*) FROM person WHERE person_id = %s", (new_id,)), 1)
        finally:
            run_sql("DELETE FROM person WHERE person_id = %s", (new_id,))

    def test_3_duplicate_email_is_rejected(self):
        """A duplicate email is rejected, and no row is added"""
        email = unique_email()
        first_id = quiet(person_service.register, SETTINGS, "Test", "One", email, 25, 3, "Analyst")
        try:
            before = scalar("SELECT COUNT(*) FROM person")
            with self.assertRaises(psycopg.errors.UniqueViolation):   # SQLSTATE 23505
                quiet(person_service.register, SETTINGS, "Test", "Two", email, 26, 3, "Analyst")
            self.assertEqual(scalar("SELECT COUNT(*) FROM person"), before)
        finally:
            run_sql("DELETE FROM person WHERE person_id = %s", (first_id,))

    def test_4_search_finds_by_prefix(self):
        """Search finds people by last-name prefix"""
        expected = scalar("SELECT COUNT(*) FROM person WHERE last_name LIKE 'Mo%'")
        found = quiet(person_service.search, SETTINGS, "Mo")
        self.assertEqual(found, expected)
        self.assertGreater(found, 0)

    def test_5_fund_commits_both_writes(self):
        """Fund commits BOTH writes"""
        op, acct = free_pairs(1)[0]
        amount = Decimal("100.00")
        before = balance(acct)
        quiet(funding_service.fund, SETTINGS, 6, op, acct, amount, False)
        try:
            self.assertEqual(balance(acct), before - amount)
            self.assertEqual(scalar("SELECT COUNT(*) FROM funds WHERE operation_id = %s "
                                    "AND account_number = %s", (op, acct)), 1)
        finally:
            undo_fund(op, acct, amount)

    def test_6_fund_rolls_back_both_writes(self):
        """Fund rolls back BOTH writes when step 2 fails"""
        # Fund the same (operation, account) pair twice. Step 1 (the UPDATE) succeeds the
        # second time, then step 2 (the INSERT) hits the primary key. The balance must come back.
        op, acct = free_pairs(1)[0]
        amount = Decimal("100.00")
        quiet(funding_service.fund, SETTINGS, 6, op, acct, amount, False)
        try:
            after_first = balance(acct)
            quiet(funding_service.fund, SETTINGS, 6, op, acct, amount, False)
            self.assertEqual(balance(acct), after_first, "second fund must roll back")
            self.assertEqual(scalar("SELECT COUNT(*) FROM funds WHERE operation_id = %s "
                                    "AND account_number = %s", (op, acct)), 1)
        finally:
            undo_fund(op, acct, amount)

    def test_7_two_users_at_once(self):
        """Two users fund the same account at once: no update is lost"""
        # Two different operations fund the SAME account at the same moment.
        # The UPDATE locks the account row, so one waits for the other. Neither update may be lost.
        (op1, acct), (op2, _) = free_pairs(2, same_account=True)
        a, b = Decimal("100.00"), Decimal("250.00")
        before = balance(acct)
        threads = [threading.Thread(target=funding_service.fund, args=(SETTINGS, 6, op1, acct, a, False)),
                   threading.Thread(target=funding_service.fund, args=(SETTINGS, 6, op2, acct, b, False))]
        with contextlib.redirect_stdout(io.StringIO()):
            for t in threads:
                t.start()
            for t in threads:
                t.join()
        try:
            self.assertEqual(balance(acct), before - a - b,
                             "a smaller drop than 350 means a lost update")
            self.assertEqual(scalar("SELECT COUNT(*) FROM funds WHERE account_number = %s "
                                    "AND operation_id IN (%s, %s)", (acct, op1, op2)), 2)
        finally:
            undo_fund(op1, acct, a)
            undo_fund(op2, acct, b)


if __name__ == "__main__":
    unittest.main(verbosity=2)
