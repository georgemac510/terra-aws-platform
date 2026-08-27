"""api - the inner microservice. Owns the database."""

import os
import time

import psycopg2
from flask import Flask, jsonify, request

app = Flask(__name__)

DSN = (
    f"host={os.environ['DB_HOST']} "
    f"port={os.environ.get('DB_PORT', '5432')} "
    f"dbname={os.environ['DB_NAME']} "
    f"user={os.environ['DB_USER']} "
    f"password={os.environ['DB_PASSWORD']}"
)


def connect(retries=30, delay=2):
    """Postgres accepts connections seconds after the container starts.

    Terraform's depends_on guarantees creation ORDER, not readiness, so the
    application has to tolerate the gap itself. This retry loop is that.
    """
    last_error = None
    for _ in range(retries):
        try:
            return psycopg2.connect(DSN)
        except psycopg2.OperationalError as exc:
            last_error = exc
            time.sleep(delay)
    raise last_error


def run(sql, params=None, fetch=None):
    conn = connect()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            result = cur.fetchall() if fetch == "all" else (
                cur.fetchone() if fetch == "one" else None
            )
        conn.commit()
        return result
    finally:
        conn.close()


@app.get("/health")
def health():
    try:
        run("SELECT 1")
    except Exception as exc:
        return jsonify(status="degraded", db="down", detail=str(exc)), 503
    return jsonify(status="ok", db="up")


@app.get("/items")
def list_items():
    rows = run("SELECT id, name FROM items ORDER BY id", fetch="all")
    return jsonify([{"id": r[0], "name": r[1]} for r in rows])


@app.post("/items")
def add_item():
    name = (request.get_json(silent=True) or {}).get("name")
    if not name:
        return jsonify(error="name is required"), 400
    row = run(
        "INSERT INTO items (name) VALUES (%s) RETURNING id", (name,), fetch="one"
    )
    return jsonify(id=row[0], name=name), 201


run("CREATE TABLE IF NOT EXISTS items (id SERIAL PRIMARY KEY, name TEXT NOT NULL)")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
