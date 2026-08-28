import AppKit

// MARK: - Settings

enum Settings {
    private static let defaults = UserDefaults.standard

    static var radius: CGFloat {
        get {
            let v = defaults.double(forKey: "radius")
            return v > 0 ? CGFloat(v) : 180
        }
        set { defaults.set(Double(newValue), forKey: "radius") }
    }

    static var darkness: CGFloat {
        get {
            let v = defaults.double(forKey: "darkness")
            return v > 0 ? CGFloat(v) : 0.9
        }
        set { defaults.set(Double(newValue), forKey: "darkness") }
    }

    static var sharpness: CGFloat {
        get {
            guard let v = defaults.object(forKey: "sharpness") as? Double else { return 0.55 }
            return CGFloat(v)
        }
        set { defaults.set(Double(newValue), forKey: "sharpness") }
    }
}

// MARK: - Focus beam view

final class FocusBeamView: NSView {
    private let gradient = CAGradientLayer()
    private var cursor = CGPoint.zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        gradient.type = .radial
        gradient.actions = ["startPoint": NSNull(), "endPoint": NSNull(),
                            "colors": NSNull(), "locations": NSNull(),
                            "bounds": NSNull(), "position": NSNull()]
        layer?.addSublayer(gradient)
        rebuildAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    func rebuildAppearance() {
        gradient.colors = [CGColor(red: 0, green: 0, blue: 0, alpha: 0),
                           CGColor(red: 0, green: 0, blue: 0, alpha: 0),
                           CGColor(red: 0, green: 0, blue: 0, alpha: Settings.darkness)]
        let stop = min(max(Double(Settings.sharpness), 0.01), 0.97)
        gradient.locations = [0, NSNumber(value: stop), 1]
        moveBeam(to: cursor)
    }

    func moveBeam(to point: CGPoint) {
        cursor = point
        let w = bounds.width, h = bounds.height
        guard w > 0, h > 0 else { return }
        let r = Settings.radius
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        gradient.startPoint = CGPoint(x: point.x / w, y: point.y / h)
        gradient.endPoint = CGPoint(x: (point.x + r) / w, y: (point.y + r) / h)
        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        moveBeam(to: cursor)
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var overlay: NSWindow?
    private var focusBeamView: FocusBeamView?
    private var eventMonitors: [Any] = []
    private var scrollMonitor: Any?
    private var toggleMenuItem: NSMenuItem!
    private var sizeSlider: NSSlider!

    private var isActive: Bool { overlay != nil }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = statusImage(active: false)
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        buildMenu()

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let button = self.statusItem.button,
                  event.window === button.window else { return event }
            Settings.radius = min(400, max(80, Settings.radius + event.scrollingDeltaY * 2))
            self.sizeSlider.doubleValue = Double(Settings.radius)
            self.focusBeamView?.rebuildAppearance()
            return nil
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    // MARK: Status item / menu

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
        } else {
            toggle()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    private func buildMenu() {
        menu = NSMenu()
        menu.delegate = self

        toggleMenuItem = NSMenuItem(title: "Focus Beam", action: #selector(toggleFromMenu), keyEquivalent: "")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)
        menu.addItem(.separator())

        sizeSlider = NSSlider(value: Double(Settings.radius), minValue: 80, maxValue: 400,
                              target: self, action: #selector(radiusChanged))
        menu.addItem(labelItem("Size"))
        menu.addItem(sliderItem(sizeSlider))
        menu.addItem(labelItem("Darkness"))
        menu.addItem(sliderItem(NSSlider(value: Double(Settings.darkness), minValue: 0.5,
                                         maxValue: 1.0, target: self,
                                         action: #selector(darknessChanged))))
        menu.addItem(labelItem("Sharpness"))
        menu.addItem(sliderItem(NSSlider(value: Double(Settings.sharpness), minValue: 0,
                                         maxValue: 1, target: self,
                                         action: #selector(sharpnessChanged))))

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit focusbeam", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func labelItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func sliderItem(_ slider: NSSlider) -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 26))
        slider.frame = NSRect(x: 22, y: 3, width: 200, height: 20)
        slider.isContinuous = true
        container.addSubview(slider)
        let item = NSMenuItem()
        item.view = container
        return item
    }

    @objc private func radiusChanged(_ sender: NSSlider) {
        Settings.radius = CGFloat(sender.doubleValue)
        focusBeamView?.rebuildAppearance()
    }

    @objc private func darknessChanged(_ sender: NSSlider) {
        Settings.darkness = CGFloat(sender.doubleValue)
        focusBeamView?.rebuildAppearance()
    }

    @objc private func sharpnessChanged(_ sender: NSSlider) {
        Settings.sharpness = CGFloat(sender.doubleValue)
        focusBeamView?.rebuildAppearance()
    }

    // MARK: Overlay lifecycle

    @objc private func toggleFromMenu() { toggle() }

    private func toggle() {
        isActive ? hideOverlay() : showOverlay()
        toggleMenuItem.state = isActive ? .on : .off
        statusItem.button?.image = statusImage(active: isActive)
    }

    // Miniature of the app icon: a square with a circle in the top-left.
    // Active: filled square with the circle knocked out; inactive: inverted.
    // Template image, so "black" follows the menu bar appearance.
    private func statusImage(active: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let square = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5),
                                      xRadius: 3, yRadius: 3)
            let r: CGFloat = 3
            let circle = NSBezierPath(ovalIn: NSRect(x: 5.5 - r, y: 12.5 - r,
                                                     width: 2 * r, height: 2 * r))
            NSColor.black.set()
            if active {
                square.lineWidth = 1.5
                square.stroke()
                circle.fill()
            } else {
                square.append(circle)
                square.windingRule = .evenOdd
                square.fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "focusbeam"
        return image
    }

    private func showOverlay() {
        guard let screen = NSScreen.screens.first else { return }
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                              backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let view = FocusBeamView(frame: NSRect(origin: .zero, size: screen.frame.size))
        window.contentView = view
        window.orderFrontRegardless()

        overlay = window
        focusBeamView = view
        view.rebuildAppearance()
        updateCursor()
        installMonitors()
    }

    private func hideOverlay() {
        removeMonitors()
        overlay?.orderOut(nil)
        overlay = nil
        focusBeamView = nil
    }

    @objc private func screensChanged() {
        guard isActive else { return }
        hideOverlay()
        showOverlay()
        toggleMenuItem.state = .on
    }

    // MARK: Cursor tracking

    private func installMonitors() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged,
                                             .rightMouseDragged, .otherMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            self?.updateCursor()
        }) {
            eventMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            self?.updateCursor()
            return event
        }) {
            eventMonitors.append(local)
        }
    }

    private func removeMonitors() {
        eventMonitors.forEach { NSEvent.removeMonitor($0) }
        eventMonitors.removeAll()
    }

    private func updateCursor() {
        guard let window = overlay, let view = focusBeamView else { return }
        let global = NSEvent.mouseLocation
        view.moveBeam(to: CGPoint(x: global.x - window.frame.origin.x,
                                       y: global.y - window.frame.origin.y))
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
