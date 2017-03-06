import Cocoa
import MediaKeyTap

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate,
                   NSUserNotificationCenterDelegate, MediaKeyTapDelegate {
    let controller = Controller(nibName: "Controller", bundle: Bundle.main)
    let popover = NSPopover()
    let statusItem = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)

    var mediaKeyTap: MediaKeyTap?
    var popoverDismissMonitor: Any?
    var preferenceWindow: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSUserNotificationCenter.default.delegate = self
        NSUserNotificationCenter.default.removeAllDeliveredNotifications()

        controller!.loadView()
        controller!.appDelegate = self
        popover.contentViewController = controller

        let playButtonImage = Bundle.main.image(forResource: "StatusPaused")!
        playButtonImage.isTemplate = true
        statusItem.image = playButtonImage
        statusItem.action = #selector(AppDelegate.togglePopover)
        statusItem.button?.appearsDisabled = true

        mediaKeyTap = MediaKeyTap(delegate: self)
        mediaKeyTap?.start()
        mediaKeyTap?.activate()

        MPDController.sharedController.connect()
    }

    /// Close the controller popover and remove dismiss monitoring.
    func closePopover() {
        popover.performClose(self)
        if popoverDismissMonitor != nil {
            NSEvent.removeMonitor(popoverDismissMonitor!)
            popoverDismissMonitor = nil
        }
    }

    /// Executes the appropriate MPDController methods when media keys are pressed.
    func handle(mediaKey: MediaKey, event: KeyEvent) {
        guard MPDController.sharedController.connected else {
            return
        }

        switch mediaKey {
        case .playPause:
            MPDController.sharedController.playPause()
        case .next, .fastForward:
            MPDController.sharedController.next()
        case .previous, .rewind:
            MPDController.sharedController.previous()
        }
    }

    /// Open the controller popover and monitor when user clicks outside kmbmpdc UI to dismiss the
    /// popover.
    func openPopover(_ button: NSStatusBarButton) {
        mediaKeyTap?.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if popoverDismissMonitor == nil {
            let eventHandler: (NSEvent) -> Void = {_ in
                self.closePopover()
            }
            let eventMask = NSEventMask.leftMouseDown.union(NSEventMask.rightMouseDown)
            popoverDismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask,
                                                                      handler: eventHandler)
        }
    }

    /// Create a preference window object, tie it to the AppDelegate and launch it.
    func openPreferences() {
        if preferenceWindow == nil {
            let viewController = Preferences()
            viewController.owner = self
            preferenceWindow = NSWindow(contentViewController: viewController)
            let nonResizableMask: UInt = preferenceWindow!.styleMask.rawValue &
                ~NSWindowStyleMask.resizable.rawValue
            preferenceWindow!.styleMask = NSWindowStyleMask(rawValue: nonResizableMask)
            preferenceWindow!.title = "kmbmpdc Preferences"
        }
        preferenceWindow!.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Opens or closes the popover depending on its current state.
    func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                closePopover()
            } else {
                openPopover(button)
            }
        }
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                didActivate notification: NSUserNotification) {
        if !popover.isShown {
            togglePopover()
        }
    }

}
