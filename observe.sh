#!/usr/bin/env bash
set -euo pipefail

if command -v psql >/dev/null 2>&1; then
  run_psql() {
    PGPASSWORD=lab psql -h 127.0.0.1 -p 5432 -U lab -d lab -P pager=off -c "$1"
  }
else
  runtime=$(command -v podman || command -v docker) || {
    echo "need host psql (brew install libpq), podman, or docker" >&2
    exit 1
  }
  echo "psql not found on host, falling back to $runtime exec" >&2
  run_psql() {
    "$runtime" exec -i lab-postgres psql -U lab -d lab -P pager=off -c "$1"
  }
fi

echo "=== Sessions on db 'lab' (pg_stat_activity) ==="
run_psql "
SELECT pid,
       application_name,
       state,
       coalesce(wait_event_type || '/' || wait_event, '') AS wait,
       date_trunc('second', now() - xact_start)           AS xact_age,
       left(query, 60)                                    AS last_query
FROM pg_stat_activity
WHERE datname = 'lab' AND pid <> pg_backend_pid()
ORDER BY backend_start;
"

echo "=== Blocking pairs (who is stuck behind whom) ==="
run_psql "
SELECT blocked.pid                 AS blocked_pid,
       left(blocked.query, 45)     AS blocked_query,
       blocking.pid                AS blocking_pid,
       blocking.state              AS blocking_state,
       left(blocking.query, 45)    AS blocking_last_query
FROM pg_stat_activity blocked
JOIN LATERAL unnest(pg_blocking_pids(blocked.pid)) AS b(pid) ON true
JOIN pg_stat_activity blocking ON blocking.pid = b.pid;
"
