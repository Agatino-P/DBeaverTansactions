# How to set up DBeaver for safe transaction handling

Distilled from the hands-on lab (2026-07-11/12), verified against DBeaver 26.1.2 + PostgreSQL 16.
Everything below was tested live, not copied from docs — deviations from the docs are flagged.

## Recommended configuration

### Daily driver: Auto-Commit + Smart commit mode

Toolbar → commit-mode dropdown (next to Commit/Rollback):

- tick **Auto-Commit**
- tick **Smart commit mode**

Result: SELECTs never leave a transaction open; the first INSERT/UPDATE/DELETE switches the
connection to manual, the green statement counter appears, and the write waits for your
explicit Commit (button or typed `commit;`). After commit/rollback the connection returns
to Auto by itself.

To make it survive reconnects, set the same in the connection defaults — the path is
non-obvious: **F4 on the connection → in the LEFT TREE, expand the collapsed
"Connection settings" node (click its `>` arrow) → Initialization**. The "Transactions"
section there has the *Auto-commit mode* dropdown and *Isolation level* (smart commit is
expected as a third dropdown value — unverified). A further "Transactions" sub-page sits
below Initialization in the tree. Note the dialog's own warning: **connection-type
settings (red/green/blue) override these initialization defaults** on connect.
Also here: "Close idle connection after 7200 s" — enabled by default, factory setting.

### Connection types (frame colors)

**F4 → General → Connection type** — the color marks Navigator entry, tabs, and editor frame:

| Type | Color | Behavior |
|------|-------|----------|
| Production | brick red | autocommit OFF, "Confirm SQL execution" before every write, 10-min idle-tx timeout |
| Test | olive green | autocommit on, confirms data changes |
| Development / custom (e.g. blue "Training") | your choice | autocommit on, no confirmations |

Global tweaks: **Window → Preferences → Connections → Connection types**.
The near-miss that motivates this: every editor tab carries its own connection binding, and
an `UPDATE` typed into the wrong tab executes against that tab's server. Colors are the
two-second defense. Identity check when in doubt:

```sql
SELECT current_database(), current_user, inet_server_addr(), inet_server_port(), version();
```

## The commit-mode dropdown, decoded

The menu looks like five options; it is actually **two radio groups and one checkbox**
(no visual separation — beware):

- **Auto-Commit / Manual Commit** — radio pair, the base mode, sticky.
- **Smart commit mode** — a CHECKBOX layered on top, not a third mode.
  - On: auto→manual on first write, and **back to Auto on every transaction end** —
    even if you had picked Manual by hand. Untick Smart if you want Manual to stick.
- **Read uncommitted … Serializable** — radio group, isolation level per connection.
  Display quirk: the tick can be missing until you set a level explicitly once.

## Mental model (Postgres specifics)

- Postgres runs *everything* in a transaction; the mode only decides **who closes it**.
  Autocommit: closes itself per statement. Manual: stays open (even after a SELECT) until
  you commit/rollback — this is the source of `idle in transaction` sessions.
- One DBeaver connection = several server sessions (Main, Metadata, one per SQL editor),
  each with independent transaction state. The Commit/Rollback buttons act on the **focused
  editor's** session only. Full reset: right-click connection → Invalidate/Reconnect.
- Typed SQL is honored everywhere: `BEGIN;` inside pure Auto-Commit works as a safety net,
  **but DBeaver's UI is blind to it** (no counter, greyed buttons) — you must remember the
  `ROLLBACK`/`COMMIT` yourself. Under Smart commit, `BEGIN` is detected (and redundant —
  expect a harmless "there is already a transaction in progress" warning).
- The **green counter** counts *statements* in the open transaction, not rows.
  **Click it** to open the Transaction Log — per-statement text, duration, and rows.
  Read it before committing anything you've lost track of.
- Isolation levels: Read Committed (default) = fresh snapshot per statement; Repeatable
  Read = snapshot frozen at first query, concurrent-write attempts fail with
  `could not serialize access` (optimistic-concurrency style — retry); Serializable adds
  write-skew detection via SIRead locks (witnesses, not barriers — SIRead locks never
  block, though writes still take ordinary row locks; losers abort at commit or as soon
  as the conflict is detected). "Read uncommitted" silently behaves as Read Committed —
  Postgres has no dirty reads, and doesn't need NOLOCK: DML readers and writers never
  block each other (DDL like `ALTER TABLE` still blocks everything).

## Server-side ground truth

Client UI can lie or lag; `pg_stat_activity` cannot. List all open transactions (any user):

```sql
SELECT pid, usename, application_name, state,
       now() - xact_start AS xact_age,
       left(query, 60) AS last_query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_start;
```

Worry about `state = 'idle in transaction'` with old `xact_age`. In this repo, `./observe.sh`
prints a per-session variant of this (db `lab` only, idle sessions included) plus blocking
pairs. Remedies: `pg_cancel_backend(pid)` interrupts an `active` query only — it does
nothing to an idle-in-transaction session, which has no query to cancel; for those you
need `pg_terminate_backend(pid)`, which kills the session (uncommitted work rolls back —
always fully, never partially). Seeing other users' query text requires `pg_read_all_stats`.
