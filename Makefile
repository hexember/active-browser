APP     = ActiveBrowser
BUILD   = .build/release/$(APP)
BUNDLE  = build/$(APP).app
LSREG   = /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# Mandatory: the `build` target and the `build/` output directory collide, so without
# .PHONY make would report "'build' is up to date" and silently skip the compile.
# Any target added later (install, release) must be listed here too.
.PHONY: build bundle run clean

build:
	swift build -c release

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	cp $(BUILD) $(BUNDLE)/Contents/MacOS/$(APP)
	cp Support/Info.plist $(BUNDLE)/Contents/Info.plist
	codesign --force --sign - $(BUNDLE)

# `open` on a bundle whose bundle id is already running activates the running
# instance instead of launching the new binary, so kill the old copy first.
run: bundle
	-pkill -x $(APP)
	open $(BUNDLE)

# Unregister before deleting: the build copy claims http/https under the same bundle
# id as the installed copy, so leaving it registered lets Launch Services bind the
# default-browser role to a deleted path. Unregistering after `rm` is a no-op.
clean:
	-$(LSREG) -u $(BUNDLE)
	rm -rf .build build
