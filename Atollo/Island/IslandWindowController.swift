import AppKit
import SwiftUI

/// Pannello senza bordi, non attivante, sopra la barra dei menu e su tutti gli Spazi.
final class IslandPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        // Va impostato dopo `isFloatingPanel` (che lo riporterebbe a `.floating`): sopra la barra dei menu.
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        isReleasedWhenClosed = false
        animationBehavior = .none
        // I click passano all'elemento della barra dei menu che sta sotto (lui apre il menu).
        ignoresMouseEvents = true
        // Visibile anche nella condivisione e nelle registrazioni dello schermo.
        sharingType = .readOnly
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Le finestre normali vengono tenute sotto la barra dei menu: questa no.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}


/// Un'isola su uno schermo. Porta lo stato disegnato del modello verso quello voluto.
/// La finestra ha misura fissa (quella dell'isola più larga) ed è agganciata al bordo destro:
/// durante le animazioni non si muove mai, così niente scatti tra AppKit e SwiftUI.
final class IslandWindowController {
    let panel = IslandPanel()
    let model: IslandModel
    private(set) var screen: NSScreen
    private let hostingView: NSHostingView<IslandView>
    private var orderOutTask: Task<Void, Never>?
    private var isObserving = true

    init(screen: NSScreen, model: IslandModel) {
        self.screen = screen
        self.model = model
        hostingView = NSHostingView(rootView: IslandView(model: model))
        // La finestra la ridimensiona questo controller, non SwiftUI.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        model.displayedShapeSize = model.shapeSize(for: .visible)
        model.displayedMidX = model.targetMidX(for: .visible)
        observe()
    }

    func update(screen: NSScreen) {
        self.screen = screen
        model.geometry = IslandGeometry(screen: screen)
    }

    func invalidate() {
        isObserving = false
        orderOutTask?.cancel()
        panel.orderOut(nil)
    }

    private func observe() {
        guard isObserving else { return }
        withObservationTracking {
            _ = model.presentation
            _ = model.shapeSize(for: .visible)
            _ = model.targetMidX(for: .visible)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.sync()
                self?.observe()
            }
        }
        sync()
    }

    private struct Target: Equatable {
        var presentation: IslandModel.Presentation
        var size: CGSize
        var midX: CGFloat
    }

    private var current: Target {
        Target(presentation: model.displayedPresentation, size: model.displayedShapeSize, midX: model.displayedMidX)
    }

    private func sync() {
        let presentation = model.presentation
        let target = Target(presentation: presentation, size: model.shapeSize(for: .visible),
                            midX: model.targetMidX(for: .visible))
        guard target != current || (presentation != .hidden && !panel.isVisible) else { return }
        orderOutTask?.cancel()

        // Sparire: dissolvenza sul posto, poi togli la finestra.
        if presentation == .hidden {
            guard panel.isVisible else {
                apply(target)
                return
            }
            withAnimation(Theme.Motion.fade) { model.displayedPresentation = .hidden }
            scheduleOrderOut(after: Theme.Motion.fadeDuration)
            return
        }

        // Comparire: mettila al suo posto ancora invisibile, poi dissolvenza. Nessuno spostamento.
        if !panel.isVisible || current.presentation == .hidden {
            withoutAnimation { apply(Target(presentation: .hidden, size: target.size, midX: target.midX)) }
            setWindow(frame(for: target))
            if !panel.isVisible {
                hostingView.layoutSubtreeIfNeeded()
                panel.orderFrontRegardless()
                panel.displayIfNeeded()
            }
            DispatchQueue.main.async { [weak self] in
                withAnimation(Theme.Motion.fade) { self?.model.displayedPresentation = .visible }
            }
            return
        }

        // Se l'elemento nella barra si è spostato, la finestra lo segue subito (come le altre icone);
        // la larghezza invece si anima dentro la finestra ferma, crescendo verso sinistra.
        let targetFrame = frame(for: target)
        if targetFrame != panel.frame {
            var start = current
            start.midX = target.midX + target.size.width / 2 - start.size.width / 2
            withoutAnimation { model.displayedMidX = start.midX }
            setWindow(targetFrame)
        }
        withAnimation(Theme.Motion.island) { apply(target) }
    }

    private func withoutAnimation(_ body: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }

    private func apply(_ target: Target) {
        model.displayedPresentation = target.presentation
        model.displayedShapeSize = target.size
        model.displayedMidX = target.midX
    }

    /// Cambia la finestra senza spostare l'isola: l'offset interno compensa nello stesso giro.
    private func setWindow(_ frame: CGRect) {
        withoutAnimation { model.windowMidX = frame.midX }
        panel.setFrame(frame, display: true)
    }

    private func scheduleOrderOut(after delay: TimeInterval) {
        orderOutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.panel.orderOut(nil)
        }
    }

    /// In alto, con il bordo destro sul bordo destro dell'isola, senza uscire dallo schermo.
    private func frame(for target: Target) -> CGRect {
        let size = model.windowSize
        let screenFrame = screen.frame
        let x = (target.midX + target.size.width / 2 + Theme.Island.windowMargin - size.width).rounded()
            .clamped(to: screenFrame.minX...(screenFrame.maxX - size.width))
        return CGRect(x: x, y: screenFrame.maxY - size.height, width: size.width, height: size.height)
    }
}
