# Security Policy

## Reporting a vulnerability

Please report security issues privately rather than in a public issue: use
[GitHub's private vulnerability reporting](https://github.com/hexember/active-browser/security/advisories/new)
for this repository.

Please include the macOS version, the chip (Apple silicon or Intel), how ActiveBrowser was
installed, and steps to reproduce. I'll acknowledge within a few days. This is a personal
project with no paid support, so please don't expect a same-day response.

## Supported versions

Only the latest release is supported. There are no backports.

## What you're trusting when you install this

**The app is ad-hoc signed, not notarized.** There is no Apple Developer ID behind it. The
`curl | sh` installer works without a Gatekeeper prompt because `curl` does not set the
`com.apple.quarantine` attribute — not because the bundle carries any trusted signature.
If that trade-off isn't acceptable to you, build from source instead; it takes one command.

**`install.sh` verifies a SHA-256 checksum** published alongside the release, and validates
the bundle identifier and architecture before replacing anything in `/Applications`. That
protects against a corrupted or truncated download. It does **not** protect against a
compromised GitHub account, since the checksum is published by the same workflow that
builds the artefact.

**The installer writes to `/Applications` and never uses `sudo`.** If `/Applications` is
not writable by your user, it refuses rather than escalating.

## What the app can see

ActiveBrowser receives every URL you open while it is your default browser, and it observes
which applications you focus. It does **not**:

- send anything over the network — the app makes no network requests of any kind;
- write URLs to disk or log them persistently;
- inspect or match on URL contents (routing is based purely on focus order).

Stored state is two `UserDefaults` keys — which browsers participate, and your fallback
browser — plus a launch-at-login opt-out flag. That's all, and it's local.
