import Cocoa
import RxSwift

// For performance reasons Chromium only makes the webview accessible when there it detects voiceover through the `AXEnhancedUserInterface` attribute on the Chrome application itself:
// http://dev.chromium.org/developers/design-documents/accessibility
// Similarly, electron uses `AXManualAccessibility`:
// https://electronjs.org/docs/tutorial/accessibility#assistive-technology
class AXEnhancedUserInterfaceActivator {
    private static let lock = NSLock()
    private static var activatedPids = Set<pid_t>()

    static func activate(_ app: NSRunningApplication) {
        lock.lock()
        activatedPids.insert(app.processIdentifier)
        lock.unlock()
        activate(AXUIElementCreateApplication(app.processIdentifier))
    }
    
    static func activate(_ app: AXUIElement) {
        _ = setAttribute(app: app, value: true)
    }
    
    static func deactivate(_ app: NSRunningApplication) {
        lock.lock()
        activatedPids.remove(app.processIdentifier)
        lock.unlock()
        deactivate(AXUIElementCreateApplication(app.processIdentifier))
    }
    
    static func deactivate(_ app: AXUIElement) {
        _ = setAttribute(app: app, value: false)
    }
    
    static func deactivateAll() {
        lock.lock()
        let pids = activatedPids
        activatedPids.removeAll()
        lock.unlock()

        for pid in pids {
            let element = AXUIElementCreateApplication(pid)
            _ = setAttribute(app: element, value: false)
        }
    }
    
    private static func setAttribute(app: AXUIElement, value: Bool) -> AXError {
        let attribute = "AXEnhancedUserInterface"
        return AXUIElementSetAttributeValue(app, attribute as CFString, value as AnyObject)
    }
}
