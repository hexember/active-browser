## Summary

<!-- What changes, and why. -->

## How I verified it

<!--
Testing here is manual -- there is no XCTest target. Please say what you actually ran,
not what you expect to work. If it touches routing, `open -a ActiveBrowser https://example.com/test`
reaches the same entry point as a real link click.
-->

- [ ] `make install` and exercised the change by hand
- [ ] Menu bar icon still appears and its items respond
- [ ] Routing still lands in the expected browser

## Checklist

- [ ] Builds clean: `swift build` and `swift build -c release`, no warnings
- [ ] No third-party dependencies added
- [ ] `CHANGELOG.md` updated under `## [Unreleased]` if user-visible
