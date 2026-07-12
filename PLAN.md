# DBeaver Transaction Lab — record

A hands-on lab (July 2026) on DBeaver's transaction/auto-commit settings, run against a
local Postgres 16 with every claim verified live against the server. **The lab is complete.**
The distilled, reusable outcome is [DBEAVER-SETUP.md](DBEAVER-SETUP.md) — read that first;
this file records how the lab worked and what each module established.

## Re-running the lab: environment memo

The stack is generic — before bringing it up on any machine, check:

- **Container runtime**: Docker or Podman, either works. Verify compose is available
  (`docker compose version` / `podman compose version`) and use the matching command
  (`podman compose up -d` vs `docker compose up -d`). On a fresh macOS Podman install,
  run `podman machine init && podman machine start` first.
- **Schema seeding**: `init/01-schema.sql` runs only on the *first* bring-up (the `pgdata`
  volume persists). To re-seed from scratch: `podman compose down -v` then up again.
- **DBeaver version**: the lab was verified against DBeaver 26.1.2. UI paths (toolbar
  commit-mode dropdown, F4 dialog layout) drift between versions — re-verify against a
  fresh screenshot before trusting any click-path in these notes.
- **Ports**: 5432 (Postgres) and 5050 (pgAdmin) must be free; both are bound to
  127.0.0.1 only.
- **Host psql** (optional): `observe.sh` uses it if present (`brew install libpq` on
  macOS); without it, run the same queries via
  `podman exec -it lab-postgres psql -U lab -d lab`.

Bring-up: `podman compose up -d` → pgAdmin at http://localhost:5050
(login `admin@example.com` / `lab`, lab server pre-registered, DB password `lab`).
DBeaver connection: `localhost:5432`, db/user/password `lab`/`lab`/`lab`.

## Method

Three observation channels made the client's behavior falsifiable:

1. **Server-side ground truth** — `pg_stat_activity` / `pg_locks` (wrapped in `./observe.sh`)
   show what each connection actually did, regardless of what the UI claims.
2. **Screenshots** of the real DBeaver UI for every click-path (rule: no UI instruction
   that wasn't verified against docs or a fresh screenshot — the docs were wrong or
   incomplete more than once).
3. **A second concurrent session** (psql) to play the colleague: observing uncommitted
   changes' invisibility, non-blocking writes, and isolation anomalies live.

## Curriculum & findings

1. **Setup & observation channels** — one DBeaver connection = several server sessions
   (Main, Metadata, one per SQL editor), each with independent transaction state.
2. **Transactions & DBeaver's model** — Postgres runs everything in a transaction; the
   commit mode only decides who closes it. Manual mode opens a transaction on *any*
   statement (even SELECT → `idle in transaction`). Commit/Rollback buttons act on the
   focused editor's session only; Invalidate/Reconnect resets all of a connection's
   sessions. Connection types (colored frames/tabs) are the guard rail against running
   SQL against the wrong server — every editor tab carries its own connection binding.
3. **Autocommit + manual BEGIN** — autocommit = instant, permanent, no undo. A hand-typed
   `BEGIN;` inside autocommit works as a safety net (server honors it) **but DBeaver's UI
   is blind to it**: no counter, greyed buttons, an invisible open transaction. Rollback
   safety net verified.
4. **Locking** — (skipped as a module; known territory) core evidence still captured:
   `idle in transaction` sessions hold row locks on the tuples they've written (blocking
   writers to those rows), and their open snapshot holds back the xmin horizon so vacuum
   can't reclaim dead tuples until they close.
5. **Smart commit** — reads leave no transaction; the first write auto-switches to manual
   (counter + lit buttons), typed `commit`/`rollback` is tracked, then the mode returns to
   Auto. UI trap: in the toolbar dropdown, "Smart commit mode" is a **checkbox modifier**
   on the Auto/Manual radio pair, not a third mode — and while it's on, every transaction
   end snaps the mode back to Auto (a hand-picked Manual survives only if Smart is off).
   The green toolbar counter counts **statements**, not rows; clicking it opens the
   Transaction Log (per-statement rows/duration — read it before committing anything
   you've lost track of).
6. **Isolation levels** — non-repeatable read demonstrated under Read Committed (same
   SELECT, two answers in one transaction); Repeatable Read freezes the snapshot at the
   first query and rejects writes to concurrently-modified rows
   (`could not serialize access` — optimistic-concurrency style, retry). Serializable
   adds write-skew detection via SIRead locks (witnesses, not barriers). "Read
   uncommitted" silently behaves as Read Committed — Postgres has no dirty reads and
   needs no NOLOCK: DML readers and writers never block each other. Menu quirk: the
   isolation tick display is unreliable until a level is set explicitly once.
7. **Wrap-up** — recommended settings and the stuck-transaction first-aid kit, both
   distilled into DBEAVER-SETUP.md.

## Repo contents

- `docker-compose.yml` — Postgres 16 + pgAdmin (pinned), localhost-only ports, healthcheck
- `init/01-schema.sql` — `bank` schema: `accounts` (its per-row CHECK pointedly *cannot*
  enforce the cross-row invariant used in the write-skew demo — that gap is the lesson),
  `transfers` (unused by the modules; kept as future material)
- `servers.json` — pgAdmin pre-registration of the lab server
- `observe.sh` — the observation deck: all sessions on db `lab` + blocking pairs
- `DBEAVER-SETUP.md` — **the take-home artifact**
