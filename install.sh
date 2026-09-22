#!/bin/bash
#
# ActiveBrowser installer.
#
# Downloads the latest ActiveBrowser release, verifies its SHA-256 checksum,
# replaces /Applications/ActiveBrowser.app, registers it with Launch Services
# and launches it. It touches nothing else: no user defaults, no login items,
# no default-browser binding, and no privilege escalation of any kind.
#
# Usage:
#
#   curl -fsSL https://raw.githubusercontent.com/tajpuriya27/active-browser/main/install.sh | sh
#
# That one-liner is the supported, user-facing way to run this script.
#
# Environment variables (all optional):
#
#   ACTIVEBROWSER_ZIP      Path to a local ActiveBrowser.app.zip. When set, the
#                          script makes NO network access at all.
#   ACTIVEBROWSER_SUMS     Path to the SHA256SUMS for that zip. Defaults to a
#                          file named SHA256SUMS in the same directory as the
#                          zip -- exactly what `make release` writes to build/.
#   ACTIVEBROWSER_VERSION  Pin a release tag (e.g. v0.1.0) instead of resolving
#                          the latest release.
#
# ACTIVEBROWSER_ZIP / ACTIVEBROWSER_SUMS exist so the install path can be
# exercised for testing and offline installs without a published release; the
# default and supported path remains the GitHub Release above.
#
# Signing: v1 bundles are ad-hoc signed. `curl` does not set the
# com.apple.quarantine attribute, which is why this path installs and launches
# without notarization. This script therefore only *reports* quarantine; it
# never strips it.

set -euo pipefail

APP_NAME="ActiveBrowser"
BUNDLE_ID="com.local.activebrowser"
DEST="/Applications/${APP_NAME}.app"
REPO="tajpuriya27/active-browser"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

warn() {
    printf 'warning: %s\n' "$*" >&2
}

say() {
    printf '==> %s\n' "$*"
}

TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

# ---------------------------------------------------------------------------
# Preflight. Everything here runs before anything is downloaded and long before
# anything is deleted, so a refusal always leaves an installed copy untouched.
# ---------------------------------------------------------------------------

kernel="$(uname -s)"
[ "$kernel" = "Darwin" ] || fail "ActiveBrowser is macOS-only (found: $kernel)"

macos_version="$(sw_vers -productVersion)"
macos_major="${macos_version%%.*}"
case "$macos_major" in
    ''|*[!0-9]*) fail "could not parse the macOS version (found: $macos_version)" ;;
esac
[ "$macos_major" -ge 13 ] || fail "ActiveBrowser requires macOS 13 or later (found: $macos_version)"

arch="$(uname -m)"
# A Terminal running under Rosetta reports x86_64 on an Apple-silicon Mac;
# sysctl.proc_translated = 1 is the correction, so an arm64 machine is not
# refused an artefact that would have worked.
if [ "$arch" = "x86_64" ] && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || true)" = "1" ]; then
    arch="arm64"
fi
case "$arch" in
    arm64|x86_64) ;;
    *) fail "unsupported architecture: $arch (ActiveBrowser supports arm64 and x86_64)" ;;
esac

[ -w /Applications ] || fail "/Applications is not writable by $(id -un); install as an admin user"

for tool in curl ditto shasum plutil lipo pkill open; do
    command -v "$tool" >/dev/null 2>&1 || fail "required tool not found on PATH: $tool"
done

# A missing lsregister is not worth failing an install over: `open` still makes
# the app usable and Launch Services indexes it lazily.
if [ ! -x "$LSREGISTER" ]; then
    warn "lsregister not found at $LSREGISTER; skipping explicit Launch Services registration"
    LSREGISTER=""
fi

# ---------------------------------------------------------------------------
# Acquisition. Both files are normalised into $TMPDIR_WORK under the exact names
# `make release` uses, because SHA256SUMS names the zip with a bare filename.
# ---------------------------------------------------------------------------

zip_override="${ACTIVEBROWSER_ZIP:-}"
sums_override="${ACTIVEBROWSER_SUMS:-}"
version_pin="${ACTIVEBROWSER_VERSION:-}"

work_zip="$TMPDIR_WORK/ActiveBrowser.app.zip"
work_sums="$TMPDIR_WORK/SHA256SUMS"
have_sums=0

if [ -n "$zip_override" ]; then
    [ -f "$zip_override" ] || fail "ACTIVEBROWSER_ZIP does not name an existing file: $zip_override"
    say "Using local archive $zip_override (no network access)"
    cp "$zip_override" "$work_zip"

    if [ -n "$sums_override" ]; then
        [ -f "$sums_override" ] || fail "ACTIVEBROWSER_SUMS does not name an existing file: $sums_override"
        cp "$sums_override" "$work_sums"
        have_sums=1
    else
        zip_dir="$(dirname "$zip_override")"
        if [ -f "$zip_dir/SHA256SUMS" ]; then
            cp "$zip_dir/SHA256SUMS" "$work_sums"
            have_sums=1
        fi
    fi
else
    tag="$version_pin"
    if [ -n "$tag" ]; then
        say "Using pinned release $tag"
    else
        say "Resolving the latest release of $REPO"
        # The API is unauthenticated (60 requests/hour per IP), so a failure here
        # is expected occasionally and falls back to the redirect URL below.
        api_json="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" || true)"
        tag="$(printf '%s' "$api_json" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 || true)"
        tag="$(printf '%s' "$tag" | sed 's/.*"\([^"]*\)"$/\1/' || true)"
    fi

    if [ -n "$tag" ]; then
        base_url="https://github.com/$REPO/releases/download/$tag"
        say "Downloading ActiveBrowser $tag"
    else
        say "Could not resolve a release tag from the GitHub API; falling back to the latest-release redirect"
        base_url="https://github.com/$REPO/releases/latest/download"
    fi

    curl -fsSL -o "$work_zip" "$base_url/ActiveBrowser.app.zip" \
        || fail "download failed: $base_url/ActiveBrowser.app.zip"
    # A release without its SHA256SUMS is a broken release.
    curl -fsSL -o "$work_sums" "$base_url/SHA256SUMS" \
        || fail "download failed: $base_url/SHA256SUMS (a release must publish its checksums)"
    have_sums=1
fi

# ---------------------------------------------------------------------------
# Verification. macOS ships Perl's shasum, which has no --ignore-missing, so the
# check runs from the directory holding a file of the exact name in SHA256SUMS.
# ---------------------------------------------------------------------------

if [ "$have_sums" -eq 1 ]; then
    say "Verifying the SHA-256 checksum"
    if ! ( cd "$TMPDIR_WORK" && shasum -a 256 -c SHA256SUMS ); then
        fail "checksum verification failed for ActiveBrowser.app.zip; refusing to install"
    fi
else
    warn "no SHA256SUMS next to $zip_override; skipping verification"
fi

# ---------------------------------------------------------------------------
# Stage and validate. Nothing under /Applications is touched until the staged
# bundle has passed every check, so a bad archive can never leave the user
# without an app that holds the http/https handler role.
# ---------------------------------------------------------------------------

say "Extracting the archive"
ditto -x -k "$work_zip" "$TMPDIR_WORK/stage" \
    || fail "could not extract ActiveBrowser.app.zip (the archive may be truncated)"

staged="$TMPDIR_WORK/stage/${APP_NAME}.app"
if [ ! -d "$staged" ]; then
    contents="$(ls -A "$TMPDIR_WORK/stage" 2>/dev/null | tr '\n' ' ' || true)"
    fail "the archive has no ${APP_NAME}.app at its top level (it contains: ${contents:-nothing})"
fi

# `plutil -extract` without `-o -` rewrites the plist in place and invalidates
# the code signature; every extract below therefore passes `-o -`.
staged_id="$(plutil -extract CFBundleIdentifier raw -o - "$staged/Contents/Info.plist" 2>/dev/null || true)"
[ -n "$staged_id" ] || fail "could not determine the CFBundleIdentifier of the staged bundle"
[ "$staged_id" = "$BUNDLE_ID" ] || fail "staged bundle declares $staged_id, expected $BUNDLE_ID; refusing to install"

staged_archs="$(lipo -archs "$staged/Contents/MacOS/$APP_NAME" 2>/dev/null || true)"
[ -n "$staged_archs" ] || fail "could not determine the architecture of the staged binary"
case " $staged_archs " in
    *" $arch "*) ;;
    *) fail "this release is built for $staged_archs, this Mac is $arch" ;;
esac

# Structural check only: an ad-hoc signature carries no identity, and the
# SHA-256 above is the authenticity gate. Never a hard failure.
if command -v codesign >/dev/null 2>&1; then
    if ! codesign --verify --strict "$staged" >/dev/null 2>&1; then
        warn "codesign --verify --strict failed on the staged bundle; continuing (the checksum already passed)"
    fi
fi

# curl does not quarantine; a browser download or a Cask does. Report it, never
# strip it -- com.apple.provenance is a different attribute and is expected.
if command -v xattr >/dev/null 2>&1; then
    quarantine="$(xattr -p com.apple.quarantine "$staged" 2>/dev/null || true)"
    if [ -n "$quarantine" ]; then
        warn "the zip was obtained through a quarantining path; macOS may prompt on first launch"
    fi
fi

staged_version="$(plutil -extract CFBundleShortVersionString raw -o - "$staged/Contents/Info.plist" 2>/dev/null || true)"
[ -n "$staged_version" ] || staged_version="unknown"

if [ -e "$DEST" ]; then
    existing_id="$(plutil -extract CFBundleIdentifier raw -o - "$DEST/Contents/Info.plist" 2>/dev/null || true)"
    [ "$existing_id" = "$BUNDLE_ID" ] \
        || fail "$DEST exists but declares ${existing_id:-no readable bundle id}, not $BUNDLE_ID; refusing to replace an unrelated app"
fi

# ---------------------------------------------------------------------------
# Replace, register, launch.
# ---------------------------------------------------------------------------

say "Installing ActiveBrowser $staged_version into /Applications"
# pkill first: never pull a bundle out from under a live process, and `open`
# would otherwise merely re-activate the dying instance. The sleep is bounded
# process teardown -- not the Launch Services scanner race that is banned in
# the Makefile, where no wait is long enough because the scan lands after the
# command has already returned.
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1
# Mandatory: ditto/cp onto an existing bundle merges trees, and a stale
# Contents/_CodeSignature then fails codesign --verify, which macOS treats as
# "refuse to launch".
rm -rf "$DEST"
# ditto, not mv: $TMPDIR may be on a different volume, and ditto preserves the
# signature and extended attributes.
ditto "$staged" "$DEST" || fail "could not install the app into /Applications"

if [ -n "$LSREGISTER" ]; then
    say "Registering the http/https URL schemes with Launch Services"
    "$LSREGISTER" -f "$DEST" || warn "lsregister -f failed; the schemes will be indexed lazily instead"
fi

say "Launching ActiveBrowser"
open "$DEST" || fail "could not launch $DEST"

say "ActiveBrowser $staged_version is installed at $DEST"
say "Next: open the ActiveBrowser item in the menu bar and choose \"Set as Default Browser\"."
