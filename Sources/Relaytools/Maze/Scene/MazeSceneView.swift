import SwiftUI
import AppKit
import CoreGraphics
@preconcurrency import SceneKit

struct MazeSceneView: NSViewRepresentable {
    let game: MazeStore
    func makeNSView(context: Context) -> MazeInputView { MazeInputView(game: game) }
    func updateNSView(_ view: MazeInputView, context: Context) { view.synchronize() }
    static func dismantleNSView(_ view: MazeInputView, coordinator: ()) { view.stop() }
}

@MainActor
final class MazeInputView: SCNView {
    private let game: MazeStore
    private let world: MazeSceneBuilder
    private var timer: Timer?
    private var previousFrame = ProcessInfo.processInfo.systemUptime
    private var keys: Set<UInt16> = []
    private var captured = false
    private var cursorHidden = false
    private var tracking: NSTrackingArea?
    private var passedIDs: Set<Int> = []
    private var reactionCount = 0
    private var oldAcceptsMouseMoved = false
    private weak var captureWindow: NSWindow?

    init(game: MazeStore) {
        self.game = game
        world = MazeSceneBuilder(layout: game.layout, customers: game.customers)
        super.init(frame: .zero, options: [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue])
        scene = world.scene
        pointOfView = world.camera
        allowsCameraControl = false
        rendersContinuously = true
        isPlaying = true
        preferredFramesPerSecond = 60
        antialiasingMode = .multisampling4X
        backgroundColor = NSColor(calibratedRed: 0.04, green: 0.07, blue: 0.1, alpha: 1)
        setAccessibilityLabel("3D maze. Click to explore. W A S D to move, mouse to look, Escape to release the pointer. Arrow keys can also turn.")
        setAccessibilityRole(.group)
        let timer = Timer(timeInterval: 1.0 / 60, target: self, selector: #selector(frameTick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        NotificationCenter.default.addObserver(self, selector: #selector(deactivateControls), name: NSApplication.didResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deactivateControls), name: NSApplication.willTerminateNotification, object: nil)
        updateCamera()
    }

    required init?(coder: NSCoder) { fatalError("Use init(game:)") }
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { releasePointer() }
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect, .enabledDuringMouseDrag], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    func synchronize() {
        if !game.wantsCapture || game.encounterID != nil || game.phase != .playing { releasePointer() }
        for customer in game.customers where customer.passed && !passedIDs.contains(customer.id) {
            passedIDs.insert(customer.id)
            world.applyPass(customer.id)
            if game.soundEnabled { NSSound(named: "Glass")?.play() }
        }
        if game.attempts.count > reactionCount {
            reactionCount = game.attempts.count
            if let attempt = game.attempts.last, !attempt.evaluation.passed {
                world.applyRefusal(attempt.customerID)
                if game.soundEnabled { NSSound(named: "Tink")?.play() }
            }
        }
    }

    private func capturePointer() {
        guard !captured, let window, window.isKeyWindow, game.encounterID == nil, game.phase == .playing else { return }
        window.makeFirstResponder(self)
        captureWindow = window
        oldAcceptsMouseMoved = window.acceptsMouseMovedEvents
        window.acceptsMouseMovedEvents = true
        if CGAssociateMouseAndMouseCursorPosition(0) == .success {
            NSCursor.hide()
            cursorHidden = true
        }
        captured = true
        game.setCaptured(true)
        keys.removeAll()
    }

    private func releasePointer() {
        guard captured || cursorHidden else { return }
        if cursorHidden {
            CGAssociateMouseAndMouseCursorPosition(1)
            NSCursor.unhide()
            cursorHidden = false
        }
        captureWindow?.acceptsMouseMovedEvents = oldAcceptsMouseMoved
        captureWindow = nil
        captured = false
        keys.removeAll()
        game.setCaptured(false)
    }

    override func mouseDown(with event: NSEvent) {
        guard game.encounterID == nil, game.phase == .playing else { return }
        game.requestControls()
        capturePointer()
    }
    override func mouseMoved(with event: NSEvent) { handleLook(event) }
    override func mouseDragged(with event: NSEvent) { handleLook(event) }
    private func handleLook(_ event: NSEvent) {
        guard captured else { return }
        game.look(horizontal: -event.deltaX * 0.003, vertical: -event.deltaY * 0.003)
        updateCamera()
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) { super.keyDown(with: event); return }
        if event.keyCode == 53 {
            game.releaseControls()
            releasePointer()
            return
        }
        guard captured else { super.keyDown(with: event); return }
        if event.keyCode == 14 {
            Task { await game.approachNearest(force: true) }
        } else { keys.insert(event.keyCode) }
    }
    override func keyUp(with event: NSEvent) { keys.remove(event.keyCode) }

    @objc private func frameTick() {
        let now = ProcessInfo.processInfo.systemUptime
        let delta = min(0.05, max(0, now - previousFrame))
        previousFrame = now
        if window?.isKeyWindow != true && captured {
            game.releaseControls()
            releasePointer()
        }
        if game.wantsCapture, !captured, window?.isKeyWindow == true { capturePointer() }
        if !game.wantsCapture || game.encounterID != nil { releasePointer() }
        let forward = (keys.contains(13) ? 1.0 : 0) - (keys.contains(1) ? 1.0 : 0)
        let strafe = (keys.contains(2) ? 1.0 : 0) - (keys.contains(0) ? 1.0 : 0)
        if captured {
            game.look(horizontal: ((keys.contains(124) ? 1.0 : 0) - (keys.contains(123) ? 1.0 : 0)) * -delta * 1.5,
                      vertical: ((keys.contains(126) ? 1.0 : 0) - (keys.contains(125) ? 1.0 : 0)) * delta)
        }
        game.step(delta: delta, forward: forward, strafe: strafe)
        updateCamera()
        synchronize()
        if captured, game.encounterID == nil, !game.isBusy {
            Task { await game.approachNearest() }
        }
    }

    private func updateCamera() {
        world.camera.position = SCNVector3(game.player.x, 1.63, game.player.z)
        world.camera.eulerAngles = SCNVector3(game.pitch, game.yaw, 0)
    }

    @objc private func deactivateControls() {
        game.releaseControls()
        releasePointer()
    }

    func stop() {
        NotificationCenter.default.removeObserver(self, name: NSApplication.didResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSApplication.willTerminateNotification, object: nil)
        timer?.invalidate()
        timer = nil
        game.releaseControls()
        releasePointer()
        isPlaying = false
        rendersContinuously = false
    }
}
