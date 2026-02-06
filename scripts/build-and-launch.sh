#!/usr/bin/env bash
#
# build-and-launch.sh — Build Dockhand, launch it, and optionally wait
# for the MCP server to become ready.
#
# Usage:
#   ./scripts/build-and-launch.sh [OPTIONS]
#
# Options:
#   --port PORT               MCP server port (default: 8766)
#   --wait-for-server         Poll until the MCP /rpc endpoint responds
#   --timeout SECS            Max seconds to wait for MCP (default: 30)
#   --skip-build              Launch an existing build without rebuilding
#   --configuration CONFIG    Xcode build configuration (default: Debug)
#   --help                    Show this help message
#
# Examples:
#   ./scripts/build-and-launch.sh --wait-for-server
#   ./scripts/build-and-launch.sh --port 9000 --wait-for-server --timeout 60
#   ./scripts/build-and-launch.sh --skip-build --wait-for-server
#

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"
BUNDLE_ID="crunchy-bananas.Dockhand"
SCHEME="Dockhand"
LOCK_FILE="$REPO_ROOT/tmp/.build-launch.lock"
LOCK_MAX_AGE=300 # seconds

# ─── Defaults ─────────────────────────────────────────────────────────

MCP_PORT=8766
WAIT_FOR_SERVER=false
TIMEOUT=30
SKIP_BUILD=false
CONFIGURATION="Debug"

# ─── Helpers ──────────────────────────────────────────────────────────

usage() {
  sed -n '3,/^$/s/^# \{0,1\}//p' "$0"
  exit 0
}

info()  { printf "\033[1;34m▸\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m⚠\033[0m %s\n" "$*" >&2; }
die()   { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; exit 1; }

# ─── Lock File ────────────────────────────────────────────────────────

acquire_lock() {
  mkdir -p "$(dirname "$LOCK_FILE")"

  if [[ -f "$LOCK_FILE" ]]; then
    local lock_age
    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE") ))
    if (( lock_age > LOCK_MAX_AGE )); then
      warn "Stale lock file (${lock_age}s old) — removing"
      rm -f "$LOCK_FILE"
    else
      die "Another build-and-launch is running (lock age: ${lock_age}s). Remove $LOCK_FILE to force."
    fi
  fi

  echo $$ > "$LOCK_FILE"
}

cleanup_lock() {
  rm -f "$LOCK_FILE"
}

trap cleanup_lock EXIT

# ─── MCP Health Check ────────────────────────────────────────────────

mcp_server_ready() {
  local port="${1:-$MCP_PORT}"
  local response
  response=$(curl -s --max-time 2 \
    -X POST "http://127.0.0.1:${port}/rpc" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' 2>/dev/null) || return 1
  echo "$response" | grep -q '"tools"'
}

# ─── Parse Args ───────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      MCP_PORT="$2"; shift 2 ;;
    --wait-for-server)
      WAIT_FOR_SERVER=true; shift ;;
    --timeout)
      TIMEOUT="$2"; shift 2 ;;
    --skip-build)
      SKIP_BUILD=true; shift ;;
    --configuration)
      CONFIGURATION="$2"; shift 2 ;;
    --help|-h)
      usage ;;
    *)
      die "Unknown option: $1 (use --help for usage)" ;;
  esac
done

# ─── Acquire Lock ─────────────────────────────────────────────────────

acquire_lock

# ─── Build ────────────────────────────────────────────────────────────

if [[ "$SKIP_BUILD" == "false" ]]; then
  info "Building $SCHEME ($CONFIGURATION)…"

  BUILD_LOG=$(mktemp /tmp/dockhand-build.XXXXXX.log)

  set +e
  xcodebuild \
    -project "$REPO_ROOT/Dockhand.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR" \
    -destination 'platform=macOS' \
    build > "$BUILD_LOG" 2>&1
  BUILD_EXIT=$?
  set -e

  if [[ $BUILD_EXIT -ne 0 ]]; then
    warn "Build failed — last 50 lines of log:"
    tail -50 "$BUILD_LOG"
    die "xcodebuild exited with code $BUILD_EXIT (full log: $BUILD_LOG)"
  fi

  rm -f "$BUILD_LOG"
  ok "Build succeeded"
else
  info "Skipping build (--skip-build)"
fi

# ─── Find .app ────────────────────────────────────────────────────────

APP_PATH=$(find "$BUILD_DIR" -name "Dockhand.app" -type d 2>/dev/null | head -1)

if [[ -z "$APP_PATH" ]]; then
  # Fall back to default DerivedData location
  APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Dockhand-*/Build/Products/Debug/Dockhand.app -maxdepth 0 -type d 2>/dev/null | head -1)
fi

[[ -n "$APP_PATH" ]] || die "Could not locate Dockhand.app — did the build succeed?"

info "Found app: $APP_PATH"

# ─── Kill Existing Instance ──────────────────────────────────────────

if pgrep -x Dockhand > /dev/null 2>&1; then
  warn "Dockhand is already running — terminating…"
  killall Dockhand 2>/dev/null || true
  sleep 1
  # Force-kill if it's still hanging around
  if pgrep -x Dockhand > /dev/null 2>&1; then
    killall -9 Dockhand 2>/dev/null || true
    sleep 1
  fi
fi

# ─── Configure Defaults ──────────────────────────────────────────────

info "Configuring MCP defaults (port=$MCP_PORT, enabled=true)…"
defaults write "$BUNDLE_ID" "mcp.server.enabled" -bool true
defaults write "$BUNDLE_ID" "mcp.server.port" -int "$MCP_PORT"

# ─── Launch ───────────────────────────────────────────────────────────

info "Launching Dockhand…"
open -a "$APP_PATH"
ok "Dockhand launched"

# ─── Wait for MCP Server ─────────────────────────────────────────────

if [[ "$WAIT_FOR_SERVER" == "true" ]]; then
  info "Waiting for MCP server on port $MCP_PORT (timeout: ${TIMEOUT}s)…"

  attempt=0
  while (( attempt < TIMEOUT )); do
    if mcp_server_ready "$MCP_PORT"; then
      ok "MCP server is ready on http://127.0.0.1:${MCP_PORT}/rpc"
      exit 0
    fi
    sleep 1
    (( attempt++ ))
  done

  die "MCP server did not respond within ${TIMEOUT}s"
fi

ok "Done"
