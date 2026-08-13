import AppKit
import CoreGraphics
import QuartzCore
import ObjectiveC

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // SF Symbol for displays
            if let symbol = NSImage(systemSymbolName: "display.2", accessibilityDescription: "Fix Overscan") {
                button.image = symbol
            } else {
                button.title = "🖥️"
            }
            button.toolTip = "Click to fix monitor overscan"
        }
        
        // Build dropdown menu
        let menu = NSMenu()
        
        let fixItem = NSMenuItem(title: "Fix Display Overscan", action: #selector(applyFix), keyEquivalent: "f")
        fixItem.target = self
        menu.addItem(fixItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        
        // Optionally run the fix automatically on startup
        applyFix()
    }

    @objc func applyFix() {
        dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", RTLD_LAZY)
        
        guard let cls = NSClassFromString("CADisplay") as? NSObject.Type,
              let displays = cls.perform(Selector(("displays")))? .takeUnretainedValue() as? [NSObject] else {
            return
        }

        // Set overscanAdjustment -> "none"
        let selSetAdj = Selector(("setOverscanAdjustment:"))
        for d in displays {
            if d.responds(to: selSetAdj) {
                _ = d.perform(selSetAdj, with: "none" as NSString)
            }
        }

        // Flush CoreGraphics framebuffers
        var config: CGDisplayConfigRef?
        if CGBeginDisplayConfiguration(&config) == .success {
            _ = CGCompleteDisplayConfiguration(config, .forSession)
        }
        
        // Flash a quick checkmark on the menu item for feedback
        if let menu = statusItem.menu, let firstItem = menu.items.first {
            let origTitle = firstItem.title
            firstItem.title = "✓ Overscan Fixed!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                firstItem.title = origTitle
            }
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

// Initialize as accessory app (no dock icon)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()