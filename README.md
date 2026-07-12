# DBeaver Transactions Lab

A finished, hands-on lab on DBeaver's transaction handling (commit modes, smart commit,
isolation levels) against a local PostgreSQL 16, with every claim verified live.

- **[DBEAVER-SETUP.md](DBEAVER-SETUP.md)** — the take-home: how to configure DBeaver for
  safe transaction handling, and the server-side queries that outrank the UI.
- **[PLAN.md](PLAN.md)** — the lab record: method, per-module findings, and how to
  re-run the stack (works with Docker or Podman).

Quickstart: `podman compose up -d` (or `docker compose up -d`) → pgAdmin at
http://localhost:5050 (`admin@example.com` / `lab`), Postgres at `localhost:5432`
(`lab`/`lab`/`lab`), `./observe.sh` to watch sessions and locks.
