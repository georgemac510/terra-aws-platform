"""web - the outer microservice. Talks to api, never to the database."""

import os

import requests
from flask import Flask, redirect, render_template_string, request

app = Flask(__name__)

# "api" resolves because both containers sit on the same user-defined Docker
# network, which Terraform creates. No IP addresses anywhere.
API_URL = os.environ.get("API_URL", "http://api:8000")

PAGE = """<!doctype html>
<title>{{ project }}</title>
<style>
  body { font: 15px/1.5 system-ui, sans-serif; max-width: 34rem; margin: 4rem auto; }
  li { margin: .2rem 0; }
  .down { color: #b00; }
</style>
<h1>{{ project }}</h1>
<p>api says: <strong class="{{ '' if healthy else 'down' }}">{{ status }}</strong></p>
<ul>{% for item in items %}<li>{{ item.id }} &mdash; {{ item.name }}</li>{% endfor %}</ul>
<form method="post" action="/add">
  <input name="name" placeholder="new item" autofocus>
  <button>add</button>
</form>
"""


@app.get("/")
def index():
    try:
        health = requests.get(f"{API_URL}/health", timeout=5).json()
        items = requests.get(f"{API_URL}/items", timeout=5).json()
        healthy = health.get("status") == "ok"
        status = f"{health.get('status')} (db {health.get('db')})"
    except requests.RequestException as exc:
        healthy, status, items = False, f"unreachable: {exc}", []

    return render_template_string(
        PAGE,
        project=os.environ.get("PROJECT_NAME", "platform"),
        status=status,
        healthy=healthy,
        items=items,
    )


@app.post("/add")
def add():
    name = request.form.get("name", "").strip()
    if name:
        requests.post(f"{API_URL}/items", json={"name": name}, timeout=5)
    return redirect("/")


@app.get("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
