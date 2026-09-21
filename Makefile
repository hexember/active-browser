# This file is only used in build-time only; never ships

APP     = ActiveBrowser
BUILD   = .build/release/$(APP)
BUNDLE  = build/$(APP).app
LSREG   = /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# Mandatory: the `build` target and the `build/` output directory collide, so without
# .PHONY make would report "'build' is up to date" and silently skip the compile.
# Any target added later (install, release) must be listed here too.
.PHONY: build bundle install run clean

# `make build` - swift build -c release → binary at .build/release/ActiveBrowser
build:
	swift build -c release

# `make bundle` - build, then assemble + ad-hoc sign build/ActiveBrowser.app
bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	cp $(BUILD) $(BUNDLE)/Contents/MacOS/$(APP)
	cp Support/Info.plist $(BUNDLE)/Contents/Info.plist
	codesign --force --sign - $(BUNDLE)

# `make install` 
install: bundle
	-pkill -x $(APP)
	rm -rf /Applications/$(APP).app
	cp -R $(BUNDLE) /Applications/
	rm -rf $(BUNDLE)
	-$(LSREG) -u $(BUNDLE)
	$(LSREG) -f /Applications/$(APP).app
	open /Applications/$(APP).app

# `make run` - bundle, kill any running copy, launch the build/ copy
run: bundle
	-pkill -x $(APP)
	open $(BUNDLE)

# `make clean` - unregister the build copy, delete .build/ and build/
clean:
	-$(LSREG) -u $(BUNDLE)
	rm -rf .build build
