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
            if let symbol = NSImage(systemSymbolName: "display.2", accessibilityDescription: "Fix Overscan & Unmirror") {
                button.image = symbol
            } else {
                button.title = "🖥️"
            }
            button.toolTip = "Click to fix monitor overscan and switch to extended desktop"
        }
        
        // Build dropdown menu
        let menu = NSMenu()
        
        let fixItem = NSMenuItem(title: "Fix Display", action: #selector(applyFix), keyEquivalent: "f")
        fixItem.target = self
        menu.addItem(fixItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        
        // Run fix automatically on launch
        applyFix()
    }

    @objc func applyFix() {
        // 1. QuartzCore CADisplay Overscan Fix ("none")
        dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", RTLD_LAZY)
        
        guard let cls = NSClassFromString("CADisplay") as? NSObject.Type,
              let displays = cls.perform(Selector(("displays")))? .takeUnretainedValue() as? [NSObject] else {
            return
        }

        let selSetAdj = Selector(("setOverscanAdjustment:"))
        for d in displays {
            if d.responds(to: selSetAdj) {
                _ = d.perform(selSetAdj, with: "none" as NSString)
            }
        }

        // 2. CoreGraphics Transaction: Unmirror Displays & Flush Framebuffers
        var config: CGDisplayConfigRef?
        if CGBeginDisplayConfiguration(&config) == .success {
            
            // Get all connected active displays
            var displayCount: UInt32 = 0
            var activeDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
            
            if CGGetActiveDisplayList(16, &activeDisplays, &displayCount) == .success {
                for i in 0..<Int(displayCount) {
                    let displayID = activeDisplays[i]
                    
                    // Passing kCGNullDirectDisplay detaches any active mirroring relationship
                    // and forces the display into Extended Desktop mode.
                    CGConfigureDisplayMirrorOfDisplay(config, displayID, kCGNullDirectDisplay)
                }
            }
            
            // Commit all configuration changes (Overscan + Unmirror) atomically
            _ = CGCompleteDisplayConfiguration(config, .forSession)
        }
        
        // 3. UI Feedback
        if let menu = statusItem.menu, let firstItem = menu.items.first {
            let origTitle = firstItem.title
            firstItem.title = "✓ Fixed & Unmirrored!"
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