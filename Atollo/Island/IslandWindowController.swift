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
        ignoresMouseEvents = false
        // Visibile anche nella condivisione e nelle registrazioni dello schermo.
        sharingType = .readOnly
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Le finestre normali vengono tenute sotto la barra dei menu: questa no.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Ospita la SwiftUI; accetta il primo click così il click destro arriva anche ad app inattiva.
final class IslandHostingView: NSHostingView<IslandView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Un'isola su uno schermo. Porta lo stato disegnato del modello verso quello voluto:
/// prima allarga la finestra, poi anima la forma, e restringe la finestra solo a molla finita.
final class IslandWindowController {
    let panel = IslandPanel()
    let model: IslandModel
    private(set) var screen: NSScreen
    private let hostingView: IslandHostingView
    private var shrinkTask: Task<Void, Never>?
    private var isObserving = true

    init(screen: NSScreen, model: IslandModel) {
        self.screen = screen
        self.model = model
        hostingView = IslandHostingView(rootView: IslandView(model: model))
        // La finestra la ridimensiona questo controller, non SwiftUI.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        model.displayedShapeSize = model.shapeSize(for: .hidden)
        model.displayedMidX = model.targetMidX(for: .hidden)
        observe()
    }

    func update(screen: NSScreen) {
        self.screen = screen
        model.geometry = IslandGeometry(screen: screen)
    }

    func invalidate() {
        isObserving = false
        shrinkTask?.cancel()
        panel.orderOut(nil)
    }

    private func observe() {
        guard isObserving else { return }
        withObservationTracking {
            _ = model.presentation
            _ = model.shapeSize(for: model.presentation)
            _ = model.targetMidX(for: model.presentation)
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
        let target = Target(presentation: presentation, size: model.shapeSize(for: presentation),
                            midX: model.targetMidX(for: presentation))
        guard target != current || (presentation != .hidden && !panel.isVisible) else { return }
        shrinkTask?.cancel()

        // Sparire: anima verso la forma nascosta, poi togli la finestra.
        if presentation == .hidden {
            guard panel.isVisible else {
                apply(target)
                return
            }
            // Resta dov'era mentre si ritira (l'elemento nella barra potrebbe essere già sparito).
            let target = Target(presentation: .hidden, size: target.size, midX: model.displayedMidX)
            withAnimation(Theme.Motion.island) { apply(target) }
            scheduleShrink { [weak self] in self?.panel.orderOut(nil) }
            return
        }

        // Comparire: disegna prima la forma nascosta nel punto giusto, poi anima.
        if !panel.isVisible {
            let hidden = model.shapeSize(for: .hidden)
            apply(Target(presentation: .hidden, size: hidden, midX: target.midX))
            setWindow(frame(for: target))
            hostingView.layoutSubtreeIfNeeded()
            panel.orderFrontRegardless()
            panel.displayIfNeeded()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                withAnimation(Theme.Motion.island) { self.apply(target) }
            }
            return
        }

        // Cambio di forma o posizione: la finestra copre subito sia il prima sia il dopo.
        let union = panel.frame.union(frame(for: target))
        if union != panel.frame { setWindow(union) }
        withAnimation(Theme.Motion.island) { apply(target) }
        scheduleShrink { [weak self] in
            guard let self else { return }
            self.setWindow(self.frame(for: self.current))
        }
    }

    private func apply(_ target: Target) {
        model.displayedPresentation = target.presentation
        model.displayedShapeSize = target.size
        model.displayedMidX = target.midX
    }

    /// Cambia la finestra senza spostare l'isola: l'offset interno compensa nello stesso giro.
    private func setWindow(_ frame: CGRect) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { model.windowMidX = frame.midX }
        panel.setFrame(frame, display: true)
    }

    private func scheduleShrink(_ action: @escaping () -> Void) {
        shrinkTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Theme.Motion.windowShrinkDelay))
            guard self != nil, !Task.isCancelled else { return }
            action()
        }
    }

    /// In alto, centrata sull'isola, senza uscire dallo schermo.
    private func frame(for target: Target) -> CGRect {
        let size = model.windowSize(for: .visible)
        let screenFrame = screen.frame
        let x = (target.midX - size.width / 2).rounded()
            .clamped(to: screenFrame.minX...(screenFrame.maxX - size.width))
        return CGRect(x: x, y: screenFrame.maxY - size.height, width: size.width, height: size.height)
    }
}
