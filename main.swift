import AppKit
import ServiceManagement

private let finderDomain = "com.apple.finder" as CFString
private let showAllFilesKey = "AppleShowAllFiles" as CFString

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let loginMenuItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        loginMenuItem.target = self
        menu.addItem(loginMenuItem)
        menu.addItem(.separator())
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

    private func toggleHiddenFiles() {
        CFPreferencesSetAppValue(showAllFilesKey, hiddenFilesShown ? kCFBooleanFalse : kCFBooleanTrue, finderDomain)
        CFPreferencesAppSynchronize(finderDomain)
        // Finder only reads this preference at launch; macOS relaunches it automatically.
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/killall"), arguments: ["Finder"])
        updateIcon()
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
