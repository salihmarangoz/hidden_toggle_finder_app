APP         = HiddenToggle
BUNDLE      = build/$(APP).app
INSTALL_DIR = /Applications
TARGET      = $(shell uname -m)-apple-macos13.0

.PHONY: all install uninstall clean

all: $(BUNDLE)

$(BUNDLE): main.swift Info.plist
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	swiftc -O -target $(TARGET) -o $(BUNDLE)/Contents/MacOS/$(APP) main.swift
	cp Info.plist $(BUNDLE)/Contents/Info.plist
	codesign --force --sign - $(BUNDLE)

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
