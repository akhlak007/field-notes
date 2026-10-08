#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RUN_DIR="$PROJECT_ROOT/.run"
PID_FILE="$RUN_DIR/backend.pid"

backend_identity_matches() {
  candidate_pid=$1
  case "$candidate_pid" in ''|*[!0-9]*) return 1 ;; esac
  [ "$candidate_pid" -gt 1 ] || return 1
  [ -f "$RUN_DIR/backend.started" ] && [ -f "$RUN_DIR/backend.jar" ] || return 1
  kill -0 "$candidate_pid" 2>/dev/null || return 1
  expected_start=$(cat "$RUN_DIR/backend.started")
  expected_jar=$(cat "$RUN_DIR/backend.jar")
  case "$expected_jar" in "$PROJECT_ROOT/backend/target/"*) ;; *) return 1 ;; esac
  actual_start=$(ps -p "$candidate_pid" -o lstart= 2>/dev/null | sed 's/^ *//;s/ *$//')
  actual_command=$(ps -p "$candidate_pid" -o command= 2>/dev/null || true)
  [ -n "$actual_start" ] && [ "$actual_start" = "$expected_start" ] || return 1
  printf '%s\n' "$actual_command" | grep -F -- "$expected_jar" >/dev/null 2>&1
}

if [ -f "$PID_FILE" ]; then
  BACKEND_PID=$(cat "$PID_FILE")
  if backend_identity_matches "$BACKEND_PID"; then
    echo "Stopping Field Notes backend (PID $BACKEND_PID)..."
    kill "$BACKEND_PID"
    attempt=0
    while kill -0 "$BACKEND_PID" 2>/dev/null && [ "$attempt" -lt 10 ]; do attempt=$((attempt + 1)); sleep 1; done
    if backend_identity_matches "$BACKEND_PID"; then kill -9 "$BACKEND_PID"; fi
  else
    echo "Warning: backend state is stale or invalid; no process was stopped." >&2
  fi
  rm -f "$RUN_DIR/backend.pid" "$RUN_DIR/backend.started" "$RUN_DIR/backend.jar" "$RUN_DIR/backend.port"
fi

if [ -f "$RUN_DIR/db-owned" ]; then
  RECORDED_DB_ID=$(cat "$RUN_DIR/db-owned")
  if ! CURRENT_DB_ID=$(docker compose -f "$PROJECT_ROOT/docker-compose.yml" ps -q db 2>/dev/null); then
    echo "Could not inspect PostgreSQL ownership because Docker Compose is unavailable. Ownership state was preserved; retry stop.sh when Docker is running." >&2
    exit 1
  fi
  case "$RECORDED_DB_ID" in ''|*[!a-f0-9]*) DB_ID_VALID=0 ;; *) DB_ID_VALID=1 ;; esac
  if [ "$DB_ID_VALID" -eq 1 ] && [ "$RECORDED_DB_ID" = "$CURRENT_DB_ID" ]; then
    echo "Stopping launcher-owned PostgreSQL container..."
    docker compose -f "$PROJECT_ROOT/docker-compose.yml" down
    echo "Stopped. The PostgreSQL volume and all database data were preserved."
  else
    echo "Warning: database ownership state does not match the running container; PostgreSQL was not stopped." >&2
  fi
  rm -f "$RUN_DIR/db-owned"
else
  echo "No launcher-owned PostgreSQL container to stop."
fi
