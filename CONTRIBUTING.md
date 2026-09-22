# Contributing

Thanks for taking a look. This is a small, deliberately dependency-free macOS utility —
contributions are welcome, and the project is easy to build.

## Build and run

```sh
git clone https://github.com/tajpuriya27/active-browser.git
cd active-browser
make install     # builds, installs to /Applications, registers, launches
```

Requirements: **macOS 13+** and a **Swift 6** toolchain (`swift --version`). Install the
Xcode Command Line Tools with `xcode-select --install` if you don't have them.

| Command | What it does |
|---|---|
| `make build` | `swift build -c release` |
| `make bundle` | assemble and ad-hoc sign `build/ActiveBrowser.app` |
| `make run` | bundle, then launch the `build/` copy |
| `make install` | build, install to `/Applications`, register, launch |
| `make release` | produce `ActiveBrowser.app.zip` + `SHA256SUMS` |
| `make clean` | unregister the build copy, remove `.build/` and `build/` |

## Three things that will cost you an hour if nobody tells you

**1. The app must run from the `.app` bundle.** A bare `swift build` binary has no
`Info.plist`, so `LSUIElement` (no Dock icon), the `http`/`https` claim, and the
self-filter are all inert — `Bundle.main.bundleIdentifier` is `nil` outside a bundle. Use
`make run` or `make install`, never `.build/release/ActiveBrowser` directly.

**2. `NSLog` output does not reach Console.app or `log show`.** To read the app's own
logging you have to run the binary directly and capture stderr:

```sh
pkill -x ActiveBrowser
/Applications/ActiveBrowser.app/Contents/MacOS/ActiveBrowser > /tmp/ab.log 2>&1 &
sleep 4; kill %1; cat /tmp/ab.log
open -a ActiveBrowser          # relaunch through Launch Services
```

**3. Don't run `make run` while a copy is installed.** It launches a second bundle with
the same bundle id claiming the same URL schemes, so macOS registers both and you get two
ActiveBrowser rows in the default-browser dropdown. `make clean` removes the build copy.

## Testing

Testing is **manual** — there is no XCTest target, and please don't add one as part of an
unrelated change. Almost everything that can break here is macOS integration: Launch
Services registration, the default-browser binding, focus notifications, login items. None
of that is meaningfully unit-testable, and a test suite that mocked it would only assert
that the mocks agree with each other.

What CI does check on every push and pull request:

- both build configurations, with **zero** errors and zero warnings;
- the bundle assembles, signs, and carries the right `Info.plist` keys;
- `make release` produces artefacts whose checksum verifies;
- regression guards for two bugs that reached `main` past a green build (see
  `.github/workflows/ci.yml` for why they exist).

Before opening a PR, please also check by hand whatever your change touches. If it affects
routing, verify with `open -a ActiveBrowser https://example.com/test` — that reaches the
same entry point as a real link click, so you don't have to make ActiveBrowser your
default browser to test it.

Two gotchas when testing routing manually:

- Wait **~6 seconds** after launching the agent before focusing a browser. Its focus
  observer isn't registered immediately, and a missed focus event leaves the stack empty —
  the link then goes to your fallback browser and looks like a routing bug.
- **Assert which app is frontmost** (`lsappinfo front`) before dispatching. Browsers
  restore sessions and steal focus, which silently invalidates the test.

## Design constraints

These are enforced in review; a PR that breaks one will be asked to change:

- **No third-party dependencies.** Swift plus Apple frameworks only.
- **No polling.** State changes through `NSWorkspace` notifications and menu actions only.
- **Everything is `@MainActor`.** No GCD queues, no locks, no actors.
- **Background agent only** (`LSUIElement`) — no Dock icon, no windows.
- **Never drop a URL.** Every dispatch resolves to some browser, or logs why it couldn't.
- **Never route to ourselves.** The app's own bundle id is filtered out of the registry
  and every dispatch candidate — otherwise a link loops back into the process forever.

## Pull requests

- One logical change per PR; describe what you verified by hand.
- Conventional commit subjects (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`).
- Update `CHANGELOG.md` under `## [Unreleased]` for anything user-visible.

## Releasing (maintainers)

Push a `v*` tag from `main`; the workflow builds and publishes the assets.

```sh
git tag v0.1.1 && git push origin v0.1.1
```

The published asset names `ActiveBrowser.app.zip` and `SHA256SUMS` are a contract that
`install.sh` depends on — renaming either breaks the installer for every user. CI guards
this.
