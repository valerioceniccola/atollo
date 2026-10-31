import AppKit

/// Misure della barra dei menu di uno schermo, da cui dipende la capsula.
struct IslandGeometry: Equatable {
    /// Cornice dello schermo in coordinate globali.
    var screenFrame: CGRect
    var menuBarHeight: CGFloat
    var displayID: CGDirectDisplayID?

    init(screen: NSScreen) {
        screenFrame = screen.frame
        displayID = screen.displayID
        // Sui MacBook con notch la barra è alta quanto il notch.
        let notchHeight = screen.safeAreaInsets.top
        let reserved = screen.frame.maxY - screen.visibleFrame.maxY
        if notchHeight > 0 {
            menuBarHeight = notchHeight
        } else if reserved > 0 {
            menuBarHeight = reserved
        } else {
            menuBarHeight = max(NSStatusBar.system.thickness, Theme.Capsule.fallbackMenuBarHeight)
        }
    }

    init(screenFrame: CGRect, menuBarHeight: CGFloat, displayID: CGDirectDisplayID? = nil) {
        self.screenFrame = screenFrame
        self.menuBarHeight = menuBarHeight
        self.displayID = displayID
    }

    /// MacBook Pro 14" (barra alta quanto il notch) per le anteprime.
    static let macBook = IslandGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), menuBarHeight: 32)

    /// Studio Display per le anteprime.
    static let studioDisplay = IslandGeometry(screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440), menuBarHeight: 30)

    var capsuleHeight: CGFloat {
        (menuBarHeight * Theme.Capsule.heightRatio).rounded()
            .clamped(to: Theme.Capsule.minHeight...Theme.Capsule.maxHeight)
    }

    /// Distanza dal bordo superiore, per centrare la capsula nella barra dei menu.
    var topInset: CGFloat {
        max(((menuBarHeight - capsuleHeight) / 2).rounded(), 1)
    }
}
