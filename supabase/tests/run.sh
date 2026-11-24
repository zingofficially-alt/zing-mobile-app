#!/usr/bin/env bash
# Runs the SQL suites against a plain local Postgres (no Supabase needed).
#
#   PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres supabase/tests/run.sh
#
# Each suite gets a fresh database with supabase_stub.sql and every migration
# applied in order, then prints one "ok" / "FAIL" line per check. The script
# exits non-zero if any check fails.
set -uo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
failed=0

for suite in orders expiry privacy gaps; do
  db="zing_test_${suite}_$$"
  psql -X -q -d postgres -v ON_ERROR_STOP=1 -c "create database $db" || exit 2
  psql -X -q -d "$db" -v ON_ERROR_STOP=1 -f "$dir/supabase_stub.sql" >/dev/null 2>&1 || { echo "stub failed"; exit 2; }
  for migration in "$dir"/../migrations/*.sql; do
    psql -X -q -d "$db" -v ON_ERROR_STOP=1 -f "$migration" >/dev/null 2>&1 \
      || { echo "migration failed: $(basename "$migration")"; failed=1; }
  done
  out="$(psql -X -q -d "$db" -f "$dir/$suite.sql" 2>&1)"
  pass=$(printf '%s\n' "$out" | grep -c '^ok')
  bad=$(printf '%s\n' "$out" | grep -c -E 'FAIL|ERROR')
  echo "== $suite: $pass ok, $bad failed"
  [ "$bad" -gt 0 ] && { printf '%s\n' "$out" | grep -E 'FAIL|ERROR'; failed=1; }
  psql -X -q -d postgres -c "drop database $db" >/dev/null
done
exit $failed
