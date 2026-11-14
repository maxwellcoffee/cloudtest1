#!/usr/bin/env bash
# Earshot bootstrap: checks Xcode, installs XcodeGen (Homebrew) if missing,
# optionally writes Config/Local.xcconfig with your signing team, generates
# Earshot.xcodeproj from project.yml and opens it.
#
# Usage:
#   scripts/bootstrap.sh [TEAM_ID] [BUNDLE_ID_PREFIX] [--no-open]
#
#   TEAM_ID           10-character Apple Developer team ID (Xcode > Settings >
#                     Accounts, or developer.apple.com/account). Written to
#                     Config/Local.xcconfig as DEVELOPMENT_TEAM.
#   BUNDLE_ID_PREFIX  Optional, e.g. com.yourname.earshot. Use it when the
#                     default com.example.earshot.* identifiers cannot be
#                     registered for your team.
#   --no-open         Generate the project but do not open Xcode.
#
# Without TEAM_ID an existing Config/Local.xcconfig is left untouched.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_XCCONFIG="$ROOT/Config/Local.xcconfig"
MIN_XCODE_MAJOR=26

TEAM_ID=""
BUNDLE_PREFIX=""
OPEN_PROJECT=1

info()  { printf '==> %s\n' "$*"; }
warn()  { printf 'warning: %s\n' "$*" >&2; }
fail()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            usage
            exit 0
            ;;
        --no-open)
            OPEN_PROJECT=0
            ;;
        -*)
            fail "unknown option: $arg (see --help)"
            ;;
        *)
            if [[ -z "$TEAM_ID" ]]; then
                TEAM_ID="$arg"
            elif [[ -z "$BUNDLE_PREFIX" ]]; then
                BUNDLE_PREFIX="$arg"
            else
                fail "unexpected argument: $arg (see --help)"
            fi
            ;;
    esac
done

# --- 1. Platform and Xcode -----------------------------------------------------

[[ "$(uname -s)" == "Darwin" ]] || fail "Earshot builds on macOS with Xcode; this machine is $(uname -s)."

if ! command -v xcodebuild >/dev/null 2>&1; then
    fail "xcodebuild not found. Install Xcode ${MIN_XCODE_MAJOR}+ from the App Store or developer.apple.com/xcode."
fi

if ! XCODE_VERSION_OUTPUT="$(xcodebuild -version 2>&1)"; then
    printf '%s\n' "$XCODE_VERSION_OUTPUT" >&2
    fail "xcodebuild is not usable. If only the Command Line Tools are selected, run:
    sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
fi

XCODE_VERSION="$(printf '%s\n' "$XCODE_VERSION_OUTPUT" | awk '/^Xcode /{print $2; exit}')"
XCODE_MAJOR="${XCODE_VERSION%%.*}"
if [[ "$XCODE_MAJOR" =~ ^[0-9]+$ ]]; then
    if (( XCODE_MAJOR < MIN_XCODE_MAJOR )); then
        warn "Xcode $XCODE_VERSION found; Earshot needs Xcode ${MIN_XCODE_MAJOR}+ (macOS 26 / watchOS 26 SDKs). The build will likely fail."
    else
        info "Xcode $XCODE_VERSION"
    fi
else
    warn "could not determine the Xcode version from: $XCODE_VERSION_OUTPUT"
fi

# --- 2. XcodeGen ------------------------------------------------------------------

find_brew() {
    if command -v brew >/dev/null 2>&1; then
        command -v brew
    elif [[ -x /opt/homebrew/bin/brew ]]; then
        echo /opt/homebrew/bin/brew
    elif [[ -x /usr/local/bin/brew ]]; then
        echo /usr/local/bin/brew
    fi
}

if ! command -v xcodegen >/dev/null 2>&1; then
    BREW="$(find_brew)"
    if [[ -z "$BREW" ]]; then
        fail "XcodeGen is not installed and Homebrew was not found.
Install Homebrew from https://brew.sh and re-run this script, or install XcodeGen
another way (e.g. 'mint install yonaskolb/XcodeGen') and make sure 'xcodegen' is on PATH."
    fi
    info "Installing XcodeGen with Homebrew"
    "$BREW" install xcodegen
    BREW_PREFIX="$("$BREW" --prefix)"
    export PATH="$BREW_PREFIX/bin:$PATH"
    command -v xcodegen >/dev/null 2>&1 || fail "xcodegen is still not on PATH after installing it."
fi
info "XcodeGen $(xcodegen --version 2>/dev/null | awk '{print $NF}')"

# --- 3. Local signing settings -------------------------------------------------------

if [[ -n "$TEAM_ID" ]]; then
    [[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "'$TEAM_ID' does not look like a team ID (10 upper-case letters/digits)."
    if [[ -n "$BUNDLE_PREFIX" ]]; then
        [[ "$BUNDLE_PREFIX" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] \
            || fail "'$BUNDLE_PREFIX' is not a valid reverse-DNS bundle identifier prefix."
    fi
    mkdir -p "$(dirname "$LOCAL_XCCONFIG")"
    if [[ -f "$LOCAL_XCCONFIG" ]]; then
        cp "$LOCAL_XCCONFIG" "$LOCAL_XCCONFIG.bak"
        info "Backed up the previous Local.xcconfig to Config/Local.xcconfig.bak"
    fi
    {
        echo "// Local.xcconfig: machine-specific signing settings written by scripts/bootstrap.sh."
        echo "// Included by Config/Signing.xcconfig. Do not commit this file."
        echo "DEVELOPMENT_TEAM = $TEAM_ID"
        if [[ -n "$BUNDLE_PREFIX" ]]; then
            echo "EARSHOT_BUNDLE_ID_PREFIX = $BUNDLE_PREFIX"
        fi
    } > "$LOCAL_XCCONFIG"
    info "Wrote Config/Local.xcconfig (DEVELOPMENT_TEAM = $TEAM_ID${BUNDLE_PREFIX:+, EARSHOT_BUNDLE_ID_PREFIX = $BUNDLE_PREFIX})"
elif [[ -f "$LOCAL_XCCONFIG" ]]; then
    info "Using existing Config/Local.xcconfig"
else
    warn "no signing team configured. The Mac app can still build and run locally, but installing on your
         Apple Watch needs a team: re-run 'scripts/bootstrap.sh YOURTEAMID' or pick a team in Xcode's
         Signing & Capabilities tab (that choice is lost the next time the project is generated)."
fi

# --- 4. Generate and open ------------------------------------------------------------

cd "$ROOT"
info "Generating Earshot.xcodeproj"
xcodegen generate --spec "$ROOT/project.yml"

if (( OPEN_PROJECT )); then
    info "Opening Earshot.xcodeproj"
    open "$ROOT/Earshot.xcodeproj"
fi

cat <<'NEXT'

Next steps:
  1. Run the "Earshot" scheme (My Mac). Add your Anthropic API key in Settings > AI
     and grant the permissions it asks for.
  2. Select the "EarshotWatch" scheme and your Apple Watch as the destination, then Run.
  3. On the watch, enter the address and pairing code shown in the Mac app's Devices section.
  Without a watch: scripts/smoke-test-server.sh <pairing-code> <audio.m4a>
NEXT
