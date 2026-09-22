# This file is only used in build-time only; never ships

APP     = ActiveBrowser
BUILD   = .build/release/$(APP)
BUNDLE  = build/$(APP).app
LSREG   = /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# Mandatory: the `build` target and the `build/` output directory collide, so without
# .PHONY make would report "'build' is up to date" and silently skip the compile.
# Any target added later (install, release) must be listed here too.
.PHONY: build bundle install run release clean

# `make build` - swift build -c release → binary at .build/release/ActiveBrowser
build:
	swift build -c release

# `make bundle` - build, then assemble + ad-hoc sign build/ActiveBrowser.app
#
# Every payload file must be in place BEFORE `codesign`: the ad-hoc signature seals
# Contents/Resources into _CodeSignature/CodeResources, so a resource copied in after
# signing makes `codesign --verify --strict` fail and macOS refuse to launch the bundle.
# Keep the codesign line last.
bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD) $(BUNDLE)/Contents/MacOS/$(APP)
	cp Support/Info.plist $(BUNDLE)/Contents/Info.plist
	cp assets/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	cp assets/menubar/MenuBarIconTemplate.png $(BUNDLE)/Contents/Resources/
	cp assets/menubar/MenuBarIconTemplate@2x.png $(BUNDLE)/Contents/Resources/
	cp assets/menubar/MenuBarIconTemplate@3x.png $(BUNDLE)/Contents/Resources/
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

# `make release` - build the distributable zip and its checksum.
#
# The zip and SHA256SUMS are the release artefacts and survive; the .app does not.
# `ditto -c -k --keepParent` puts ActiveBrowser.app/ at the top level of the zip,
# which is the name install.sh extracts. `rm -rf $(BUNDLE)` is the same duplicate-
# registration fix as `install:`: the Launch Services scanner registers whatever
# .app is on disk ~1-3s *after* this ~1s target has returned, so the build copy is
# deleted rather than raced; the `-u` must follow that `rm`, never precede it.
# shasum writes a *bare* filename, so the sums are verified from build/.
release: bundle
	rm -f build/$(APP).app.zip build/SHA256SUMS
	ditto -c -k --keepParent $(BUNDLE) build/$(APP).app.zip
	cd build && shasum -a 256 $(APP).app.zip > SHA256SUMS
	rm -rf $(BUNDLE)
	-$(LSREG) -u $(BUNDLE)

# `make clean` - unregister the build copy, delete .build/ and build/
clean:
	-$(LSREG) -u $(BUNDLE)
	rm -rf .build build
