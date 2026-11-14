#!/usr/bin/env bash
# Exercises a running Earshot Mac server the way the watch does, so you can
# test the Mac app without an Apple Watch:
#   1. GET  /api/v1/hello      server info (no auth)
#   2. POST /api/v1/pair       pair with the 6-digit code shown in Devices
#   3. POST /api/v1/segments   upload an audio file with SegmentMeta headers
#   4. POST /api/v1/sync       report status, receive prompts + today snapshot
#   5. POST /api/v1/bookmarks  drop a "remember this moment" bookmark
#
# Usage:
#   scripts/smoke-test-server.sh <pairing-code> <audio.m4a> [base-url]
#
#   pairing-code  the code shown in the Mac app (Devices). Pass "-" to reuse a
#                 token from a previous run via EARSHOT_TOKEN=<token>.
#   audio.m4a     AAC .m4a (any length; a 10-60 s clip of speech works well).
#                 Record one with QuickTime Player or Voice Memos.
#   base-url      default http://127.0.0.1:8737 (or $EARSHOT_URL)
#
# The upload is transcribed like a watch segment and appears in Today.

set -euo pipefail

usage() {
    sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi
if (( $# < 2 )); then
    usage >&2
    exit 64
fi

CODE="$1"
AUDIO="$2"
BASE="${3:-${EARSHOT_URL:-http://127.0.0.1:8737}}"
BASE="${BASE%/}"
DEVICE_NAME="${EARSHOT_DEVICE_NAME:-Smoke Test}"

[[ -f "$AUDIO" ]] || { echo "error: audio file not found: $AUDIO" >&2; exit 66; }
command -v curl >/dev/null 2>&1 || { echo "error: curl is required" >&2; exit 69; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/earshot-smoke.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

step() { printf '\n==> %s\n' "$*"; }

# request METHOD PATH [curl args...]: prints the body on stdout; on HTTP >= 400
# prints the body (the server's explanation) on stderr and exits, so the reason
# is visible even when the caller redirects stdout to a file.
request() {
    local method="$1" path="$2"
    shift 2
    local out="$WORK/body" status
    status="$(curl -sS -o "$out" -w '%{http_code}' -X "$method" "$@" "$BASE$path")" || {
        echo "error: could not reach $BASE$path (is the Earshot Mac app running?)" >&2
        exit 1
    }
    if (( status >= 400 )); then
        { cat "$out"; echo; } >&2
        echo "error: HTTP $status from $method $path" >&2
        exit 1
    fi
    cat "$out"
    echo
}

# json_string KEY FILE: prints a top-level string value from a JSON file.
json_string() {
    local key="$1" file="$2"
    if command -v plutil >/dev/null 2>&1; then
        plutil -extract "$key" raw -o - "$file" 2>/dev/null && return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$file" "$key" 2>/dev/null && return 0
    fi
    sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" | sed 's#\\/#/#g'
}

new_id() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        printf 'smoke-%s-%s' "$(date +%s)" "$RANDOM"
    fi
}

# Duration in seconds (afinfo ships with macOS); falls back to 60.
DURATION="60"
if command -v afinfo >/dev/null 2>&1; then
    parsed="$(afinfo "$AUDIO" 2>/dev/null | awk '/estimated duration/ {print $3; exit}')"
    if [[ "$parsed" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        DURATION="$parsed"
    fi
fi
NOW="$(date +%s)"
STARTED_AT="$(awk -v now="$NOW" -v d="$DURATION" 'BEGIN { printf "%.3f", now - d }')"

# 1. hello ------------------------------------------------------------------------
step "GET /api/v1/hello"
request GET /api/v1/hello

# 2. pair -------------------------------------------------------------------------
if [[ "$CODE" == "-" ]]; then
    TOKEN="${EARSHOT_TOKEN:-}"
    [[ -n "$TOKEN" ]] || { echo "error: pairing code '-' needs EARSHOT_TOKEN=<token>" >&2; exit 64; }
    step "Reusing EARSHOT_TOKEN (skipping pairing)"
else
    step "POST /api/v1/pair"
    request POST /api/v1/pair \
        -H "Content-Type: application/json" \
        --data "{\"code\":\"$CODE\",\"deviceName\":\"$DEVICE_NAME\",\"deviceKind\":\"import\"}" \
        > "$WORK/pair.json"
    cat "$WORK/pair.json"
    TOKEN="$(json_string token "$WORK/pair.json")"
    [[ -n "$TOKEN" ]] || { echo "error: no token in the pairing response" >&2; exit 1; }
    echo "token: $TOKEN"
    echo "(reuse it with: EARSHOT_TOKEN=$TOKEN $0 - <audio.m4a> $BASE)"
fi
AUTH="Authorization: Bearer $TOKEN"

# 3. upload a segment ---------------------------------------------------------------
SEGMENT_ID="$(new_id)"
step "POST /api/v1/segments  (id $SEGMENT_ID, ${DURATION}s)"
# "Expect:" stops curl from waiting for a 100-continue on large bodies.
request POST /api/v1/segments \
    -H "$AUTH" \
    -H "Expect:" \
    -H "Content-Type: audio/mp4" \
    -H "X-Earshot-Segment-Id: $SEGMENT_ID" \
    -H "X-Earshot-Device: $DEVICE_NAME" \
    -H "X-Earshot-Started-At: $STARTED_AT" \
    -H "X-Earshot-Duration: $DURATION" \
    -H "X-Earshot-Avg-Power: -30" \
    -H "X-Earshot-Peak-Power: -6" \
    -H "X-Earshot-Speech-Ratio: 1" \
    -H "X-Earshot-Reason: rotation" \
    --data-binary "@$AUDIO"

# 4. sync -----------------------------------------------------------------------------
step "POST /api/v1/sync"
request POST /api/v1/sync \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    --data "{\"deviceName\":\"$DEVICE_NAME\",\"isRecording\":false,\"batteryLevel\":-1,\"queuedSegments\":0,\"queuedBytes\":0,\"lastSegmentAt\":$NOW,\"recordedSecondsToday\":$DURATION,\"appVersion\":\"smoke-test\",\"deliveredPromptIDs\":[]}"

# 5. bookmark -------------------------------------------------------------------------
step "POST /api/v1/bookmarks"
request POST /api/v1/bookmarks \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    --data "{\"id\":\"$(new_id)\",\"kind\":\"bookmark\",\"at\":$NOW,\"note\":\"smoke test\"}"

step "Done. Watch the Mac app: the segment is queued for transcription and shows up in Today."
