# ActiveBrowser

**A macOS menu bar agent that opens every link in the browser you were just using.**

No rules to write. No picker to click. You set it as your default browser once, and from then on a link clicked anywhere — Slack, Mail, Notes, Terminal — opens in whichever browser you most recently had in front of you.

```
Reading docs in Arc  →  click a link in Slack  →  opens in Arc
Testing in Brave     →  click a link in Slack  →  opens in Brave
```

That's the whole idea. ActiveBrowser never becomes the thing that displays a page; it receives the URL, decides which real browser should get it, hands it over, and gets out of the way.

---

## Why this exists

macOS lets you pick exactly **one** default browser. If you use more than one — a work profile and a personal one, a dev browser and a daily driver — every link goes to the same place and you spend your day copy-pasting URLs between browsers.

The existing tools solve this, but all of them ask you to make a decision:

| Tool | How it decides | What it costs you |
|---|---|---|
| **Finicky** | Rules in a JavaScript config file — regex on the URL, matched to a browser | You write and maintain a config. Every new site or edge case is another rule. |
| **Velja** | Rules, plus per-link overrides | Same rule-writing, with a nicer UI |
| **Browserosaurus / Choosy / Bumpr** | Shows you a picker on every link | A click and a decision, every single time |

ActiveBrowser uses a different signal entirely: **your recent focus**. You already told the system which browser you're working in — by working in it. No config file, no rules, no prompt.

**When a rules-based tool is the better choice:** if your routing genuinely depends on the *URL* — "all `github.com` links must open in the work profile", "Zoom links bypass the browser" — that's a rule, and you want Finicky or Velja. ActiveBrowser has no idea what the URL says and deliberately doesn't look.

**When ActiveBrowser is the better choice:** if your routing depends on *what you're doing right now*, and the same link would reasonably go to different browsers depending on the hour. That's the case rules handle badly, because the rule would have to encode your context, and your context changes all day.

The two approaches aren't rivals so much as answers to different questions: *where does this URL belong?* versus *where am I working?*

---

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/tajpuriya27/active-browser/main/install.sh | sh
```

Then open the menu bar icon and choose **Set as Default Browser**, and accept the macOS confirmation dialog.

The script checks your macOS version and CPU architecture, verifies the download's SHA-256 checksum, and validates the app bundle *before* it replaces anything. Re-running it is the upgrade path — safe to run with the app open.

**Requirements:** macOS 13 (Ventura) or later, Apple silicon. Released builds are `arm64`; on an Intel Mac the installer refuses with a clear message rather than installing something that won't run.

**Why there's no Gatekeeper prompt:** the app is ad-hoc signed, not notarized. `curl` doesn't set the quarantine attribute, so a `curl`-installed copy opens without a warning. Downloading the zip through a browser *would* quarantine it, so use the one-liner.

<details>
<summary>Other ways to install</summary>

Build and install from source:

```sh
git clone https://github.com/tajpuriya27/active-browser.git
cd active-browser
make install
```

Install from a local zip (useful for testing a release before publishing it):

```sh
ACTIVEBROWSER_ZIP=/path/to/ActiveBrowser.app.zip sh install.sh
```

`install.sh` also accepts `ACTIVEBROWSER_SUMS` (checksum file) and `ACTIVEBROWSER_VERSION` (pin a tag).

</details>

### Uninstall

Order matters — removing the login item while the app is still installed lets the next launch re-create it.

```sh
pkill -x ActiveBrowser
rm -rf /Applications/ActiveBrowser.app
defaults delete com.local.activebrowser   # optional: drop saved settings
```

Then System Settings → General → **Login Items & Extensions** → select ActiveBrowser → **−**, and set your real default browser back in System Settings → Desktop & Dock.

---

## Using it

Click the globe icon in the menu bar:

```
Routing to: Arc                        ← where the next link goes, right now
Recent: Arc › Brave Browser › Safari   ← your focus order
──────────
Browsers            ▸   ☑ Arc  ☑ Brave  ☑ Safari    ← who participates
Fallback Browser    ▸   ● Arc  ○ Brave  ○ Safari    ← used when nothing is running
──────────
Set as Default Browser
☑ Launch at Login
──────────
Quit ActiveBrowser
```

**Browsers** — untick a browser and it stops participating entirely: focusing it won't affect routing, and links will never go there. Useful for a browser you keep open but don't want links in. The last remaining ticked browser can't be unticked — that would leave nowhere to send a link.

**Fallback Browser** — used when the routing chain has nothing better, most commonly right after login when you haven't focused a browser yet. Untick the browser currently set as fallback and it moves to the next one automatically.

Both settings persist across restarts. The menu re-scans for newly installed browsers each time you open it.

### How a URL is routed

1. The most recently focused **included** browser that is **currently running**
2. Otherwise the most recently focused included browser, even if it isn't running (it gets launched)
3. Otherwise your **Fallback Browser**
4. Otherwise the first browser it can find

A URL is never dropped. If no browser can be resolved at all, it's logged rather than silently discarded — and ActiveBrowser filters itself out of every step, so a link can't be routed back into it in a loop.

---

## Development

Zero third-party dependencies — Swift plus Apple frameworks (`AppKit`, `Foundation`, `ServiceManagement`) only.

```sh
make build     # swift build -c release
make bundle    # assemble + ad-hoc sign build/ActiveBrowser.app
make run       # bundle, then launch the build/ copy
make install   # build, install to /Applications, register, launch
make release   # build/ActiveBrowser.app.zip + SHA256SUMS
make clean     # unregister the build copy, remove .build/ and build/
```

**The app must run from the `.app` bundle.** A bare `swift build` binary has no `Info.plist`, so `LSUIElement` (no Dock icon), the `http`/`https` claim, and self-filtering are all inert — `Bundle.main.bundleIdentifier` is `nil` outside a bundle. Use `make run` or `make install`, not `.build/release/ActiveBrowser`.

**Careful with `make run` while a copy is installed.** It launches a second bundle from `build/` with the same bundle id, claiming the same URL schemes, so macOS registers both and you get two ActiveBrowser rows in the default-browser dropdown. `make clean` unregisters and removes the build copy. (`make install` and `make release` both delete `build/ActiveBrowser.app` themselves for exactly this reason.)

**Logging:** `NSLog` output from this process doesn't reach `log show`. To read it, run the binary directly and capture stderr:

```sh
pkill -x ActiveBrowser
/Applications/ActiveBrowser.app/Contents/MacOS/ActiveBrowser > /tmp/ab.log 2>&1 &
sleep 4; kill %1; cat /tmp/ab.log
open -a ActiveBrowser    # relaunch through Launch Services
```

### Architecture

```
Sources/ActiveBrowser/
├── App/
│   ├── AppDelegate.swift      # entry point, owns all state
│   └── FocusObserver.swift    # the one NSWorkspace focus subscription
├── Core/
│   ├── BrowserRegistry.swift  # installed https handlers, minus ourselves
│   ├── BrowserStack.swift     # LRU order + target resolution
│   ├── Settings.swift         # UserDefaults-backed preferences
│   └── URLDispatcher.swift    # the single place a URL is handed off
└── UI/
    └── MenuBarManager.swift   # status item and menu
```

Design constraints, all enforced in review:

- **No polling.** State changes only through `NSWorkspace` notifications and your menu actions.
- **Everything is `@MainActor`.** No GCD queues, no locks, no actors.
- **Background agent only** (`LSUIElement`) — no Dock icon, no windows. Idle footprint is ~12 MB.
- **Never routes to itself.** The app's own bundle id is filtered out of the registry and every dispatch candidate.

### Testing

Manual, on a real machine — there is no XCTest target. macOS integration (Launch Services registration, default-browser binding, focus notifications, login items) is most of what could break, and almost none of it is meaningfully unit-testable. `tasks/TEST-PLAN.md` holds the manual checklist.

### Releasing

Push a `v*` tag. A GitHub Actions workflow builds on `macos-latest`, verifies the artefacts, and publishes `ActiveBrowser.app.zip` and `SHA256SUMS` to the release.

```sh
git tag v0.1.0 && git push origin v0.1.0
```

Those two asset names are a published contract — `install.sh` builds its download URLs from them, so renaming either breaks the installer for everyone.

---

## Known limitations

- **Apple silicon only** in released builds. Building from source on Intel works; the published zip is `arm64`.
- **Ad-hoc signed, not notarized.** Fine for `curl`, but a browser download would be quarantined.
- **Routing ignores the URL.** By design — see [Why this exists](#why-this-exists). If you need per-site rules, use Finicky or Velja.
- **`http`/`https` only.** Other schemes are left to the system.
