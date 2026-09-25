import AppKit
import Carbon.HIToolbox
import ServiceManagement

private let finderDomain = "com.apple.finder" as CFString
private let showAllFilesKey = "AppleShowAllFiles" as CFString
private let noRestartKey = "toggleWithoutRestartingFinder"

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let noRestartMenuItem = NSMenuItem(title: "Toggle Without Restarting Finder", action: #selector(toggleNoRestartMode), keyEquivalent: "")
    private let loginMenuItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [noRestartKey: true])

        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        noRestartMenuItem.target = self
        noRestartMenuItem.toolTip = "Uses Finder's ⌘⇧. shortcut (needs Accessibility permission). When off, Finder is relaunched instead."
        menu.addItem(noRestartMenuItem)
        loginMenuItem.target = self
        menu.addItem(loginMenuItem)
        menu.addItem(.separator())
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        menu.addItem(NSMenuItem(title: "Version \(version)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit Hidden Toggle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        registerLoginItemOnFirstLaunch()
        updateIcon()
        // Keep the icon in sync if hidden files are toggled elsewhere (e.g. ⌘⇧. in Finder).
        Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(updateIcon), userInfo: nil, repeats: true)
    }

    // Left click toggles; right click (or control-click) opens the options menu.
    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            noRestartMenuItem.state = UserDefaults.standard.bool(forKey: noRestartKey) ? .on : .off
            loginMenuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggleHiddenFiles()
        }
    }

    private var hiddenFilesShown: Bool {
        CFPreferencesAppSynchronize(finderDomain)
        return CFPreferencesGetAppBooleanValue(showAllFilesKey, finderDomain, nil)
    }

    private func saveHiddenFilesShown(_ shown: Bool) {
        CFPreferencesSetAppValue(showAllFilesKey, shown ? kCFBooleanTrue : kCFBooleanFalse, finderDomain)
        CFPreferencesAppSynchronize(finderDomain)
    }

    private func toggleHiddenFiles() {
        if UserDefaults.standard.bool(forKey: noRestartKey) {
            toggleWithShortcut()
        } else {
            toggleByRelaunchingFinder()
        }
    }

    // Finder only reads the setting at launch; macOS relaunches it automatically.
    private func toggleByRelaunchingFinder() {
        saveHiddenFilesShown(!hiddenFilesShown)
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/killall"), arguments: ["Finder"])
        updateIcon()
    }

    // Presses ⌘⇧. in Finder, which toggles hidden files live without relaunching it.
    private func toggleWithShortcut() {
        // Sending keystrokes to another app needs Accessibility permission; this shows the system prompt if missing.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options),
              let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        else { return }

        let previousApp = NSWorkspace.shared.frontmostApplication
        Task {
            // The shortcut only works in Finder's key window, so Finder has to be frontmost.
            guard await bringToFront(finder) else { return }
            await pressShowHiddenFilesShortcut(in: finder)
            // ⌘⇧. doesn't save the setting, so save it too; this keeps the icon right and survives Finder restarts.
            saveHiddenFilesShown(!hiddenFilesShown)
            if let previousApp, previousApp != finder {
                _ = await bringToFront(previousApp)
            }
            updateIcon()
        }
    }

    private func bringToFront(_ app: NSRunningApplication) async -> Bool {
        AXUIElementSetAttributeValue(AXUIElementCreateApplication(app.processIdentifier),
                                     kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        for _ in 0..<20 where !app.isActive {
            try? await Task.sleep(for: .milliseconds(25))
        }
        return app.isActive
    }

    // Finder remaps ⌘⇧. on some layouts (on Turkish Q it enlarges icons instead),
    // so switch to the ABC layout just for the moment the shortcut is pressed.
    private func pressShowHiddenFilesShortcut(in finder: NSRunningApplication) async {
        let original = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let filter = [kTISPropertyInputSourceID as String: "com.apple.keylayout.ABC"] as CFDictionary
        let abc = (TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource])?.first
        let abcWasEnabled = abc.flatMap { TISGetInputSourceProperty($0, kTISPropertyInputSourceIsEnabled) }
            .map { Unmanaged<CFBoolean>.fromOpaque($0).takeUnretainedValue() == kCFBooleanTrue } ?? false
        if let abc {
            TISEnableInputSource(abc)
            TISSelectInputSource(abc)
            try? await Task.sleep(for: .milliseconds(300))
        }

        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_Period), keyDown: keyDown)
            event?.flags = [.maskCommand, .maskShift]
            event?.postToPid(finder.processIdentifier)
        }
        try? await Task.sleep(for: .milliseconds(300))

        TISSelectInputSource(original)
        if let abc, !abcWasEnabled { TISDisableInputSource(abc) }
    }

    @objc private func updateIcon() {
        let shown = hiddenFilesShown
        let image = NSImage(systemSymbolName: shown ? "eye" : "eye.slash",
                            accessibilityDescription: shown ? "Hidden files visible" : "Hidden files not visible")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "Hidden files are \(shown ? "visible" : "hidden"). Click to toggle, right-click for options."
    }

    // Enable launch at login once; after that the user controls it from the menu.
    private func registerLoginItemOnFirstLaunch() {
        let key = "didRegisterLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            NSLog("Could not register login item: \(error)")
        }
    }

    @objc private func toggleNoRestartMode() {
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: noRestartKey), forKey: noRestartKey)
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Could not change login item: \(error)")
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
