APP         = HiddenToggle
BUNDLE      = build/$(APP).app
INSTALL_DIR = /Applications
MIN_MACOS   = 13.0
ARCHS       = arm64 x86_64
# The version comes from git tags: v1.2.0 → 1.2.0, and later commits → 1.2.0-3-g<hash>.
VERSION     = $(or $(shell git describe --tags --always --dirty 2>/dev/null | sed 's/^v//'),unknown)
BUILD       = $(or $(shell git rev-list --count HEAD 2>/dev/null),0)

.PHONY: all zip icon install uninstall clean

all: $(BUNDLE)

# Universal binary, ad-hoc signed.
$(BUNDLE): main.swift Info.plist icon/AppIcon.icns
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	for arch in $(ARCHS); do \
		swiftc -O -target $$arch-apple-macos$(MIN_MACOS) -o build/$(APP)-$$arch main.swift || exit 1; \
	done
	lipo -create $(ARCHS:%=build/$(APP)-%) -output $(BUNDLE)/Contents/MacOS/$(APP)
	cp Info.plist $(BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" \
		-c "Set :CFBundleVersion $(BUILD)" $(BUNDLE)/Contents/Info.plist
	cp icon/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	codesign --force --sign - $(BUNDLE)

zip: $(BUNDLE)
	rm -f build/$(APP).zip
	ditto -c -k --norsrc --noextattr --keepParent $(BUNDLE) build/$(APP).zip

# Regenerates the committed icon files from icon/make-icon.swift.
icon:
	rm -rf build/AppIcon.iconset
	mkdir -p build/AppIcon.iconset
	swift icon/make-icon.swift build/AppIcon.iconset icon/icon.png
	iconutil -c icns build/AppIcon.iconset -o icon/AppIcon.icns

install: $(BUNDLE)
	-pkill -x $(APP)
	rm -rf $(INSTALL_DIR)/$(APP).app
	cp -R $(BUNDLE) $(INSTALL_DIR)/
	open $(INSTALL_DIR)/$(APP).app

uninstall:
	-pkill -x $(APP)
	rm -rf $(INSTALL_DIR)/$(APP).app

clean:
	rm -rf build
