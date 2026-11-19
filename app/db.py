"""db.py: reads the connection settings, opens connections, explains errors.

Settings come from db.ini in the project folder (copy db.ini.example to
start). Keep db.ini out of anything you share: it holds your password.
"""
import configparser
import os

import psycopg
from psycopg import errors

CONFIG_FILE = "db.ini"


def load_settings():
    """Returns the [postgres] section of db.ini as a dict."""
    if not os.path.exists(CONFIG_FILE):
        raise RuntimeError(
            f"Could not read {CONFIG_FILE}. Copy db.ini.example to {CONFIG_FILE} "
            "and fill in your password."
        )
    parser = configparser.ConfigParser()
    parser.read(CONFIG_FILE)
    s = parser["postgres"]
    return {
        "host": s.get("host", "localhost"),
        "port": s.getint("port", 5432),
        "dbname": s.get("dbname", "notown_org"),
        "user": s.get("user", "postgres"),
        "password": s.get("password", ""),
    }


def connect(settings):
    """Opens a new connection. Use it in a `with` block so it always closes."""
    return psycopg.connect(**settings)


def explain_error(e):
    """Turns a database error into a message a user can understand.

    The rule is enforced by the DATABASE (UNIQUE, CHECK, FOREIGN KEY).
    The application's only job is to explain the rejection clearly.
    """
    detail = str(e).splitlines()[0] if str(e) else ""
    if isinstance(e, errors.UniqueViolation):
        return f"Rejected: that value must be unique and already exists. ({detail})"
    if isinstance(e, errors.CheckViolation):
        return f"Rejected: a CHECK rule was broken. ({detail})"
    if isinstance(e, errors.ForeignKeyViolation):
        return f"Rejected: it refers to a row that does not exist (foreign key). ({detail})"
    if isinstance(e, errors.NotNullViolation):
        return f"Rejected: a required value is missing (NOT NULL). ({detail})"
    if isinstance(e, errors.SerializationFailure):
        return "Rejected: another user changed the same data at the same time. Try again."
    if isinstance(e, errors.DeadlockDetected):
        return "Rejected: deadlock with another user. Try again."
    if isinstance(e, psycopg.OperationalError):
        return f"Cannot connect: is PostgreSQL running, and are db.ini's settings right? ({detail})"
    return f"Database error: {detail}"
