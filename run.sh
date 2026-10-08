#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RUN_DIR="$PROJECT_ROOT/.run"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
DEVICE=""
API_URL=""
NO_MOBILE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --device) DEVICE=${2:?"--device requires a Flutter device id"}; shift 2 ;;
    --api-base-url) API_URL=${2:?"--api-base-url requires a URL"}; shift 2 ;;
    --no-mobile) NO_MOBILE=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

load_dotenv() {
  [ -f "$1" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(printf '%s' "$line" | tr -d '\r')
    case "$line" in ''|'#'*) continue ;; esac
    case "$line" in *=*) key=${line%%=*}; value=${line#*=} ;; *) echo "Invalid .env line: $line" >&2; exit 1 ;; esac
    case "$key" in ''|[0-9]*|*[!A-Za-z0-9_]*) echo "Invalid .env key: $key" >&2; exit 1 ;; esac
    case "$value" in
      \"*\") value=${value#\"}; value=${value%\"} ;;
      \'*\') value=${value#\'}; value=${value%\'} ;;
    esac
    export "$key=$value"
  done <"$1"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required. $2" >&2
    exit 1
  fi
}

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

load_dotenv "$PROJECT_ROOT/.env"
require_command docker "Install Docker and start its engine."
require_command java "Install Java 17 or newer."
require_command curl "Install curl for API readiness checks."
if [ "$NO_MOBILE" -eq 0 ]; then require_command flutter "Install Flutter 3.27 or newer."; fi

JAVA_MAJOR=$(java -version 2>&1 | awk -F '"' '/version/ { split($2, parts, "."); print parts[1]; exit }')
if [ -z "$JAVA_MAJOR" ] || [ "$JAVA_MAJOR" -lt 17 ]; then echo "Java 17 or newer is required." >&2; exit 1; fi
if ! docker info >/dev/null 2>&1; then echo "Docker is installed but the Docker engine is not running." >&2; exit 1; fi

mkdir -p "$RUN_DIR"
if docker compose -f "$COMPOSE_FILE" ps --status running --services 2>/dev/null | grep -qx db; then
  DB_WAS_RUNNING=1
else
  DB_WAS_RUNNING=0
fi

echo "Starting PostgreSQL..."
docker compose -f "$COMPOSE_FILE" up -d db
DB_CONTAINER_ID=$(docker compose -f "$COMPOSE_FILE" ps -q db)
if [ -z "$DB_CONTAINER_ID" ]; then echo "Docker Compose started PostgreSQL but did not return its container ID." >&2; exit 1; fi
if [ "$DB_WAS_RUNNING" -eq 0 ]; then
  printf '%s\n' "$DB_CONTAINER_ID" >"$RUN_DIR/db-owned"
elif [ -f "$RUN_DIR/db-owned" ] && [ "$(cat "$RUN_DIR/db-owned")" != "$DB_CONTAINER_ID" ]; then
  rm -f "$RUN_DIR/db-owned"
  echo "Warning: removed stale database ownership state; the running database will not be stopped by stop.sh." >&2
fi

DB_USER_VALUE=${DB_USER:-fieldnotes}
DB_NAME_VALUE=${DB_NAME:-fieldnotes}
attempt=0
until docker compose -f "$COMPOSE_FILE" exec -T db pg_isready -U "$DB_USER_VALUE" -d "$DB_NAME_VALUE" >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ]; then
    docker compose -f "$COMPOSE_FILE" logs --tail 30 db >&2 || true
    echo "PostgreSQL did not become ready within 60 seconds." >&2
    exit 1
  fi
  sleep 1
done

BACKEND_PORT=${PORT:-8080}
BACKEND_PID=""
if [ -f "$RUN_DIR/backend.pid" ]; then BACKEND_PID=$(cat "$RUN_DIR/backend.pid"); fi

if [ -n "$BACKEND_PID" ] && backend_identity_matches "$BACKEND_PID"; then
  if [ ! -f "$RUN_DIR/backend.port" ] || [ "$(cat "$RUN_DIR/backend.port")" != "$BACKEND_PORT" ]; then
    echo "The owned backend uses a different port. Run ./stop.sh, then start again." >&2
    exit 1
  fi
  echo "Backend is already running (PID $BACKEND_PID)."
else
  rm -f "$RUN_DIR/backend.pid" "$RUN_DIR/backend.started" "$RUN_DIR/backend.jar" "$RUN_DIR/backend.port" \
    "$RUN_DIR/backend.log" "$RUN_DIR/backend-error.log"
  echo "Building Spring Boot API..."
  (cd "$PROJECT_ROOT/backend" && ./mvnw -q -DskipTests package)
  JAR_PATH=$(find "$PROJECT_ROOT/backend/target" -maxdepth 1 -type f -name '*.jar' ! -name '*.original' | head -n 1)
  if [ -z "$JAR_PATH" ]; then echo "The backend build completed but no executable JAR was found." >&2; exit 1; fi

  echo "Starting Spring Boot API..."
  (cd "$PROJECT_ROOT/backend" && exec java -jar "$JAR_PATH") >"$RUN_DIR/backend.log" 2>"$RUN_DIR/backend-error.log" &
  BACKEND_PID=$!
  printf '%s\n' "$BACKEND_PID" >"$RUN_DIR/backend.pid"
  ps -p "$BACKEND_PID" -o lstart= | sed 's/^ *//;s/ *$//' >"$RUN_DIR/backend.started"
  printf '%s\n' "$JAR_PATH" >"$RUN_DIR/backend.jar"
  printf '%s\n' "$BACKEND_PORT" >"$RUN_DIR/backend.port"
fi

attempt=0
until grep -q 'Started FieldNotesApplication' "$RUN_DIR/backend.log" 2>/dev/null && \
      curl -s -o /dev/null --connect-timeout 1 "http://localhost:$BACKEND_PORT/api/auth/login"; do
  if ! backend_identity_matches "$BACKEND_PID"; then
    echo "The backend stopped before it became ready:" >&2
    tail -n 30 "$RUN_DIR/backend.log" >&2 || true
    tail -n 30 "$RUN_DIR/backend-error.log" >&2 || true
    exit 1
  fi
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 90 ]; then
    tail -n 30 "$RUN_DIR/backend.log" >&2 || true
    tail -n 30 "$RUN_DIR/backend-error.log" >&2 || true
    echo "The backend did not become ready within 90 seconds." >&2
    exit 1
  fi
  sleep 1
done

echo "API ready at http://localhost:$BACKEND_PORT"
if [ "$NO_MOBILE" -eq 1 ]; then echo "Backend-only startup complete. Run ./stop.sh when finished."; exit 0; fi

if [ -z "$DEVICE" ]; then
  case "$(uname -s)" in Darwin) DEVICE=macos ;; *) DEVICE=linux ;; esac
fi

cd "$PROJECT_ROOT/mobile"
flutter pub get
if [ -z "$API_URL" ]; then API_URL=${API_BASE_URL:-}; fi
if [ -z "$API_URL" ]; then
  DEVICE_JSON=$(flutter devices --machine)
  if ! DEVICE_INFO=$(printf '%s\n' "$DEVICE_JSON" | dart run "$PROJECT_ROOT/scripts/flutter_device_info.dart" "$DEVICE"); then
    echo "Could not identify device '$DEVICE'. Pass --api-base-url explicitly or use an exact Flutter device id." >&2
    exit 1
  fi
  DEVICE_PLATFORM=$(printf '%s' "$DEVICE_INFO" | cut -f1)
  DEVICE_IS_EMULATOR=$(printf '%s' "$DEVICE_INFO" | cut -f2)
  case "$DEVICE_PLATFORM" in
    android*)
    if [ "$DEVICE_IS_EMULATOR" != "true" ]; then
      echo "A physical Android device needs a host-reachable URL. Re-run with --api-base-url http://<your-computer-ip>:$BACKEND_PORT." >&2
      exit 1
    fi
    API_URL="http://10.0.2.2:$BACKEND_PORT"
    ;;
    *) API_URL="http://localhost:$BACKEND_PORT" ;;
  esac
fi

echo "Launching Flutter on '$DEVICE' with API $API_URL..."
exec flutter run -d "$DEVICE" "--dart-define=API_BASE_URL=$API_URL"
