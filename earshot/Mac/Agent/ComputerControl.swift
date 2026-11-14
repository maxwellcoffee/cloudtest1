//  ComputerControl.swift
//  Screenshots and synthetic mouse/keyboard input for Claude's computer use
//  toolset (computer_toolset_20260801).
//
//  Coordinate spaces:
//  - "screenshot space": pixels of the downscaled main-display screenshot sent
//    to the model (long edge ≤ 1366 px), origin top-left. Every coordinate the
//    model sends, and every coordinate reported back, is in this space.
//  - "display space": global display points used by CGEvent (origin top-left
//    of the main display).
//  point = coordinate × (CGDisplayBounds(main).size / screenshot pixel size).

import Foundation
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import ApplicationServices
import Carbon.HIToolbox

struct ScreenCapture: Sendable {
    var png: Data
    var width: Int      // pixel size of the image sent to the model
    var height: Int
}

private enum ComputerControlError: LocalizedError {
    case screenRecordingDenied
    case accessibilityDenied
    case captureFailed(String)
    case imageFailed(String)
    case invalidInput(String)
    case unknownMember(String)
    case unknownKey(String)
    case eventFailed(String)

    var errorDescription: String? {
        switch self {
        case .screenRecordingDenied:
            return "Screen Recording permission is not granted to Earshot. Allow it in System Settings → Privacy & Security → Screen & System Audio Recording, then try again."
        case .accessibilityDenied:
            return "Accessibility permission is not granted to Earshot, so it cannot control the mouse or keyboard. Allow it in System Settings → Privacy & Security → Accessibility, then try again."
        case .captureFailed(let detail):
            return "Failed to capture the screen: \(detail)"
        case .imageFailed(let detail):
            return "Failed to process the screenshot: \(detail)"
        case .invalidInput(let detail):
            return "Invalid input: \(detail)"
        case .unknownMember(let name):
            return "Unsupported computer action '\(name)'."
        case .unknownKey(let name):
            return "Unknown key name '\(name)'. Use names like Return, Tab, Escape, BackSpace, Delete, space, Left, Page_Down, F5, a-z, 0-9, combined with cmd/ctrl/alt/shift using '+'."
        case .eventFailed(let detail):
            return "Could not create the input event: \(detail)"
        }
    }
}

/// One key press with the modifiers held around it.
private struct KeyStroke {
    /// Modifier key codes and their flags, pressed in order and released in reverse.
    var modifiers: [(code: CGKeyCode, flag: CGEventFlags)]
    /// The main key; nil when the combination is only modifiers (e.g. hold_key "shift").
    var key: CGKeyCode?

    var flags: CGEventFlags {
        var result: CGEventFlags = []
        for modifier in modifiers { result.insert(modifier.flag) }
        return result
    }
}

/// Lock-protected mutable state shared by concurrent calls.
private final class ControlState: @unchecked Sendable {
    private let lock = NSLock()
    private var shotSize: (width: Int, height: Int)?
    private var leftHeld = false

    var lastScreenshotSize: (width: Int, height: Int)? {
        get { lock.lock(); defer { lock.unlock() }; return shotSize }
        set { lock.lock(); shotSize = newValue; lock.unlock() }
    }

    var leftButtonHeld: Bool {
        get { lock.lock(); defer { lock.unlock() }; return leftHeld }
        set { lock.lock(); leftHeld = newValue; lock.unlock() }
    }
}

final class ComputerControl: @unchecked Sendable {
    static let shared = ComputerControl()

    /// Long edge of the screenshots sent to the model.
    private static let maxLongEdge = 1366
    private static let maxWaitSeconds: Double = 300
    private static let typingChunk = 20

    private let state = ControlState()

    // MARK: Permissions

    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        Log.info("ComputerControl: accessibility trusted = \(trusted)")
    }

    static var hasScreenRecording: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestScreenRecording() {
        let granted = CGRequestScreenCaptureAccess()
        Log.info("ComputerControl: screen recording granted = \(granted)")
    }

    // MARK: Screenshots

    /// Main display via /usr/sbin/screencapture, downscaled to long edge ≤ 1366 px; remembers the scale.
    func screenshot() throws -> ScreenCapture {
        guard ComputerControl.hasScreenRecording else { throw ComputerControlError.screenRecordingDenied }
        let source = try ComputerControl.captureMainDisplay()
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: ComputerControl.maxLongEdge,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ComputerControlError.imageFailed("could not downscale the capture")
        }
        let png = try ComputerControl.pngData(image)
        state.lastScreenshotSize = (width: image.width, height: image.height)
        return ScreenCapture(png: png, width: image.width, height: image.height)
    }

    /// Runs `screencapture` into a temporary PNG and returns an image source for it.
    private static func captureMainDisplay() throws -> CGImageSource {
        let url = AppPaths.temporaryDirectory.appendingPathComponent("screen-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-m", "-t", "png", url.path]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        let errorPipe = Pipe()
        process.standardError = errorPipe
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do {
            try process.run()
        } catch {
            throw ComputerControlError.captureFailed("could not run screencapture (\(error.localizedDescription))")
        }
        if exited.wait(timeout: .now() + 20) == .timedOut {
            process.terminate()
            throw ComputerControlError.captureFailed("screencapture did not finish within 20 seconds")
        }
        let status = process.terminationStatus
        guard status == 0 else {
            let message = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmed
            throw ComputerControlError.captureFailed(message.isEmpty ? "screencapture exited with status \(status)" : message)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            throw ComputerControlError.captureFailed("no image was written (is the display asleep or locked?)")
        }
        return source
    }

    private static func pngData(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData,
                                                                 UTType.png.identifier as CFString, 1, nil) else {
            throw ComputerControlError.imageFailed("could not create a PNG encoder")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ComputerControlError.imageFailed("PNG encoding failed")
        }
        return data as Data
    }

    /// Scales `image` down (never up) so it fits inside maxWidth × maxHeight, keeping the aspect ratio.
    private static func fitted(_ image: CGImage, maxWidth: Int, maxHeight: Int) throws -> CGImage {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { throw ComputerControlError.imageFailed("empty image") }
        let scale = min(Double(maxWidth) / Double(width), Double(maxHeight) / Double(height), 1)
        if scale >= 1 { return image }
        let targetWidth = max(1, Int((Double(width) * scale).rounded()))
        let targetHeight = max(1, Int((Double(height) * scale).rounded()))
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: targetWidth, height: targetHeight, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ComputerControlError.imageFailed("could not create a drawing context")
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let scaled = context.makeImage() else { throw ComputerControlError.imageFailed("scaling failed") }
        return scaled
    }

    /// Size of the screenshot the model is working from (takes one if none was taken yet).
    private func screenshotSize() throws -> (width: Int, height: Int) {
        if let size = state.lastScreenshotSize, size.width > 0, size.height > 0 { return size }
        let shot = try screenshot()
        return (width: shot.width, height: shot.height)
    }

    /// Captures `region` (screenshot space) at full resolution, scaled to fit the screenshot size.
    private func zoom(region: [Double]) throws -> ScreenCapture {
        guard ComputerControl.hasScreenRecording else { throw ComputerControlError.screenRecordingDenied }
        let size = try screenshotSize()
        let x0 = min(region[0], region[2]), x1 = max(region[0], region[2])
        let y0 = min(region[1], region[3]), y1 = max(region[1], region[3])
        guard x1 - x0 >= 1, y1 - y0 >= 1 else {
            throw ComputerControlError.invalidInput("'region' must have a positive width and height")
        }
        guard x0 < Double(size.width), y0 < Double(size.height), x1 > 0, y1 > 0 else {
            throw ComputerControlError.invalidInput("'region' is outside the screenshot (\(size.width)x\(size.height))")
        }

        let source = try ComputerControl.captureMainDisplay()
        guard let full = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ComputerControlError.imageFailed("could not decode the capture")
        }
        let fx = Double(full.width) / Double(size.width)
        let fy = Double(full.height) / Double(size.height)
        let crop = CGRect(x: x0 * fx, y: y0 * fy, width: (x1 - x0) * fx, height: (y1 - y0) * fy)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: full.width, height: full.height))
        guard !crop.isNull, crop.width >= 1, crop.height >= 1, let cropped = full.cropping(to: crop) else {
            throw ComputerControlError.imageFailed("could not crop the requested region")
        }
        let maxWidth = min(size.width, ComputerControl.maxLongEdge)
        let maxHeight = min(size.height, ComputerControl.maxLongEdge)
        let image = try ComputerControl.fitted(cropped, maxWidth: maxWidth, maxHeight: maxHeight)
        let png = try ComputerControl.pngData(image)
        return ScreenCapture(png: png, width: image.width, height: image.height)
    }

    /// Runs blocking work (process launch, image processing) off the cooperative thread pool.
    private func offload<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: Actions

    /// Executes one computer_toolset_20260801 member. Coordinates are in screenshot pixel space.
    /// Returns text and/or an image for the tool_result.
    func perform(member: String, input: JSONValue) async throws -> (text: String, image: ScreenCapture?) {
        switch member {
        case "screenshot":
            let shot = try await offload { try self.screenshot() }
            return ("", shot)

        case "zoom":
            guard let region = ComputerControl.numbers(input["region"]), region.count == 4 else {
                throw ComputerControlError.invalidInput("'region' must be [x0, y0, x1, y1]")
            }
            let image = try await offload { try self.zoom(region: region) }
            return ("", image)

        case "cursor_position":
            let size = try await offload { try self.screenshotSize() }
            let location = CGEvent(source: nil)?.location ?? .zero
            let bounds = CGDisplayBounds(CGMainDisplayID())
            guard bounds.width > 0, bounds.height > 0 else {
                throw ComputerControlError.eventFailed("the main display has no size")
            }
            let x = Int(((location.x - bounds.minX) * CGFloat(size.width) / bounds.width).rounded())
            let y = Int(((location.y - bounds.minY) * CGFloat(size.height) / bounds.height).rounded())
            return ("[\(x), \(y)]", nil)

        case "wait":
            let seconds = min(max(ComputerControl.number(input["duration"]) ?? 1, 0), ComputerControl.maxWaitSeconds)
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return ("OK", nil)

        case "left_click", "right_click", "middle_click", "double_click", "triple_click":
            try requireAccessibility()
            let target = try await targetPoint(input["coordinate"], required: false)
            let modifiers = try modifierStroke(input["text"])
            let button: CGMouseButton
            switch member {
            case "right_click": button = .right
            case "middle_click": button = .center
            default: button = .left
            }
            let count: Int
            switch member {
            case "double_click": count = 2
            case "triple_click": count = 3
            default: count = 1
            }
            try await click(at: target, button: button, count: count, modifiers: modifiers)
            return ("OK", nil)

        case "left_click_drag":
            try requireAccessibility()
            guard let start = try await targetPointIfPresent(input["start_coordinate"], name: "start_coordinate") else {
                throw ComputerControlError.invalidInput("'start_coordinate' [x, y] is required")
            }
            guard let end = try await targetPointIfPresent(input["coordinate"], name: "coordinate") else {
                throw ComputerControlError.invalidInput("'coordinate' [x, y] is required")
            }
            let modifiers = try modifierStroke(input["text"])
            try await drag(from: start, to: end, modifiers: modifiers)
            return ("OK", nil)

        case "mouse_move":
            try requireAccessibility()
            guard let target = try await targetPointIfPresent(input["coordinate"], name: "coordinate") else {
                throw ComputerControlError.invalidInput("'coordinate' [x, y] is required")
            }
            if state.leftButtonHeld {
                try await dragMove(from: currentLocation(), to: target, flags: [])
            } else {
                try postMouse(.mouseMoved, at: target, button: .left)
            }
            await pause(milliseconds: 40)
            return ("OK", nil)

        case "left_mouse_down":
            try requireAccessibility()
            let target = try await targetPoint(input["coordinate"], required: false)
            if input["coordinate"] != nil {
                try postMouse(.mouseMoved, at: target, button: .left)
                await pause(milliseconds: 40)
            }
            try postMouse(.leftMouseDown, at: target, button: .left, clickState: 1)
            state.leftButtonHeld = true
            return ("OK", nil)

        case "left_mouse_up":
            try requireAccessibility()
            let target = try await targetPoint(input["coordinate"], required: false)
            if input["coordinate"] != nil, state.leftButtonHeld {
                try await dragMove(from: currentLocation(), to: target, flags: [])
            }
            try postMouse(.leftMouseUp, at: target, button: .left, clickState: 1)
            state.leftButtonHeld = false
            return ("OK", nil)

        case "scroll":
            try requireAccessibility()
            try await scroll(input)
            return ("OK", nil)

        case "type":
            try requireAccessibility()
            guard let text = input["text"]?.stringValue, !text.isEmpty else {
                throw ComputerControlError.invalidInput("'text' is required")
            }
            try await typeText(text)
            return ("OK", nil)

        case "key":
            try requireAccessibility()
            guard let text = input["text"]?.stringValue?.trimmed, !text.isEmpty else {
                throw ComputerControlError.invalidInput("'text' is required (e.g. \"Return\" or \"cmd+s\")")
            }
            let strokes = try ComputerControl.parseKeySequence(text)
            let repeats = ComputerControl.clampedInt(input["repeat"], fallback: 1, range: 1...100)
            for index in 0..<repeats {
                for stroke in strokes {
                    try await press(stroke)
                    await pause(milliseconds: 30)
                }
                if index < repeats - 1 { await pause(milliseconds: 20) }
            }
            return ("OK", nil)

        case "hold_key":
            try requireAccessibility()
            guard let text = input["text"]?.stringValue?.trimmed, !text.isEmpty else {
                throw ComputerControlError.invalidInput("'text' is required")
            }
            let stroke = try ComputerControl.parseCombo(text)
            let seconds = min(max(ComputerControl.number(input["duration"]) ?? 1, 0), ComputerControl.maxWaitSeconds)
            try await hold(stroke, seconds: seconds)
            return ("OK", nil)

        default:
            throw ComputerControlError.unknownMember(member)
        }
    }

    // MARK: Coordinates

    private func requireAccessibility() throws {
        guard ComputerControl.hasAccessibility else { throw ComputerControlError.accessibilityDenied }
    }

    private static func number(_ value: JSONValue?) -> Double? {
        guard let value else { return nil }
        if let d = value.doubleValue, d.isFinite { return d }
        if let s = value.stringValue, let d = Double(s.trimmed), d.isFinite { return d }
        return nil
    }

    /// A whole number from `value`, clamped to `range` (never traps on huge or fractional input).
    private static func clampedInt(_ value: JSONValue?, fallback: Int, range: ClosedRange<Int>) -> Int {
        guard let raw = number(value) else { return min(max(fallback, range.lowerBound), range.upperBound) }
        let clamped = min(max(raw.rounded(), Double(range.lowerBound)), Double(range.upperBound))
        return Int(clamped)
    }

    /// Short text for a coordinate value in error messages.
    private static func describe(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e9 { return String(Int(value)) }
        return String(value)
    }

    /// Parses `[a, b, ...]` (also tolerates a JSON string such as "[10, 20]").
    private static func numbers(_ value: JSONValue?) -> [Double]? {
        guard let value, !value.isNull else { return nil }
        var array = value.arrayValue
        if array == nil, let s = value.stringValue, let parsed = try? JSONValue.parse(s) {
            array = parsed.arrayValue
        }
        guard let items = array else { return nil }
        var result: [Double] = []
        for item in items {
            guard let n = number(item) else { return nil }
            result.append(n)
        }
        return result
    }

    private func currentLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    /// Display point for a coordinate in screenshot space, or the current cursor position when absent.
    private func targetPoint(_ value: JSONValue?, required: Bool) async throws -> CGPoint {
        if let point = try await targetPointIfPresent(value, name: "coordinate") { return point }
        if required { throw ComputerControlError.invalidInput("'coordinate' [x, y] is required") }
        return currentLocation()
    }

    private func targetPointIfPresent(_ value: JSONValue?, name: String) async throws -> CGPoint? {
        guard let value, !value.isNull else { return nil }
        guard let pair = ComputerControl.numbers(value), pair.count == 2 else {
            throw ComputerControlError.invalidInput("'\(name)' must be [x, y]")
        }
        let size = try await offload { try self.screenshotSize() }
        let x = pair[0], y = pair[1]
        guard x >= 0, y >= 0, x <= Double(size.width), y <= Double(size.height) else {
            throw ComputerControlError.invalidInput("'\(name)' [\(ComputerControl.describe(x)), \(ComputerControl.describe(y))] is outside the screenshot (\(size.width)x\(size.height))")
        }
        let bounds = CGDisplayBounds(CGMainDisplayID())
        let px = bounds.minX + CGFloat(x) * bounds.width / CGFloat(size.width)
        let py = bounds.minY + CGFloat(y) * bounds.height / CGFloat(size.height)
        return CGPoint(x: min(max(px, bounds.minX), bounds.maxX - 1),
                       y: min(max(py, bounds.minY), bounds.maxY - 1))
    }

    // MARK: Mouse

    private func pause(milliseconds: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(max(milliseconds, 0)) * 1_000_000)
    }

    private func postMouse(_ type: CGEventType, at point: CGPoint, button: CGMouseButton,
                           clickState: Int64? = nil, flags: CGEventFlags = []) throws {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                  mouseCursorPosition: point, mouseButton: button) else {
            throw ComputerControlError.eventFailed("mouse event")
        }
        if let clickState {
            event.setIntegerValueField(.mouseEventClickState, value: clickState)
        }
        if button == .center {
            event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    private func click(at point: CGPoint, button: CGMouseButton, count: Int, modifiers: KeyStroke) async throws {
        let downType: CGEventType
        let upType: CGEventType
        switch button {
        case .right:
            downType = .rightMouseDown
            upType = .rightMouseUp
        case .center:
            downType = .otherMouseDown
            upType = .otherMouseUp
        default:
            downType = .leftMouseDown
            upType = .leftMouseUp
        }
        try postMouse(.mouseMoved, at: point, button: .left)
        await pause(milliseconds: 50)
        try pressModifiers(modifiers)
        let flags = modifiers.flags
        do {
            for n in 1...max(count, 1) {
                try postMouse(downType, at: point, button: button, clickState: Int64(n), flags: flags)
                await pause(milliseconds: 15)
                try postMouse(upType, at: point, button: button, clickState: Int64(n), flags: flags)
                if n < count { await pause(milliseconds: 40) }
            }
        } catch {
            try? releaseModifiers(modifiers)
            throw error
        }
        try releaseModifiers(modifiers)
        if button == .left { state.leftButtonHeld = false }
    }

    /// Posts interpolated drag events from `start` to `end` with the left button held.
    private func dragMove(from start: CGPoint, to end: CGPoint, flags: CGEventFlags) async throws {
        let dx = Double(end.x - start.x)
        let dy = Double(end.y - start.y)
        let distance = (dx * dx + dy * dy).squareRoot()
        let steps = max(4, min(30, Int(distance / 25)))
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
            try postMouse(.leftMouseDragged, at: point, button: .left, flags: flags)
            await pause(milliseconds: 12)
        }
    }

    private func drag(from start: CGPoint, to end: CGPoint, modifiers: KeyStroke) async throws {
        try postMouse(.mouseMoved, at: start, button: .left)
        await pause(milliseconds: 50)
        try pressModifiers(modifiers)
        let flags = modifiers.flags
        do {
            try postMouse(.leftMouseDown, at: start, button: .left, clickState: 1, flags: flags)
            state.leftButtonHeld = true
            await pause(milliseconds: 60)
            try await dragMove(from: start, to: end, flags: flags)
            await pause(milliseconds: 40)
            try postMouse(.leftMouseUp, at: end, button: .left, clickState: 1, flags: flags)
            state.leftButtonHeld = false
        } catch {
            try? postMouse(.leftMouseUp, at: end, button: .left, clickState: 1, flags: flags)
            state.leftButtonHeld = false
            try? releaseModifiers(modifiers)
            throw error
        }
        try releaseModifiers(modifiers)
    }

    private func scroll(_ input: JSONValue) async throws {
        let direction = (input["scroll_direction"]?.stringValue ?? "down").trimmed.lowercased()
        let amount = ComputerControl.clampedInt(input["scroll_amount"], fallback: 3, range: 1...50)
        let linesPerClick: Int32 = 3
        let vertical: Int32
        let horizontal: Int32
        switch direction {
        case "up": vertical = linesPerClick; horizontal = 0
        case "down": vertical = -linesPerClick; horizontal = 0
        case "left": vertical = 0; horizontal = linesPerClick
        case "right": vertical = 0; horizontal = -linesPerClick
        default:
            throw ComputerControlError.invalidInput("'scroll_direction' must be up, down, left or right")
        }
        let modifiers = try modifierStroke(input["text"])
        let point: CGPoint
        if let target = try await targetPointIfPresent(input["coordinate"], name: "coordinate") {
            point = target
            try postMouse(.mouseMoved, at: point, button: .left)
            await pause(milliseconds: 50)
        } else {
            point = currentLocation()
        }
        try pressModifiers(modifiers)
        let flags = modifiers.flags
        do {
            for _ in 0..<amount {
                let source = CGEventSource(stateID: .hidSystemState)
                guard let event = CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 2,
                                          wheel1: vertical, wheel2: horizontal, wheel3: 0) else {
                    throw ComputerControlError.eventFailed("scroll event")
                }
                event.location = point
                event.flags = flags
                event.post(tap: .cghidEventTap)
                await pause(milliseconds: 25)
            }
        } catch {
            try? releaseModifiers(modifiers)
            throw error
        }
        try releaseModifiers(modifiers)
    }

    // MARK: Keyboard

    private func postKey(_ code: CGKeyCode, down: Bool, flags: CGEventFlags) throws {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else {
            throw ComputerControlError.eventFailed("keyboard event")
        }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    private func pressModifiers(_ stroke: KeyStroke) throws {
        var flags: CGEventFlags = []
        for modifier in stroke.modifiers {
            flags.insert(modifier.flag)
            try postKey(modifier.code, down: true, flags: flags)
        }
    }

    private func releaseModifiers(_ stroke: KeyStroke) throws {
        var flags = stroke.flags
        for modifier in stroke.modifiers.reversed() {
            flags.remove(modifier.flag)
            try postKey(modifier.code, down: false, flags: flags)
        }
    }

    private func press(_ stroke: KeyStroke) async throws {
        try pressModifiers(stroke)
        if let key = stroke.key {
            let flags = stroke.flags
            do {
                try postKey(key, down: true, flags: flags)
                await pause(milliseconds: 12)
                try postKey(key, down: false, flags: flags)
            } catch {
                try? releaseModifiers(stroke)
                throw error
            }
        }
        await pause(milliseconds: 8)
        try releaseModifiers(stroke)
    }

    private func hold(_ stroke: KeyStroke, seconds: Double) async throws {
        try pressModifiers(stroke)
        let flags = stroke.flags
        if let key = stroke.key {
            do {
                try postKey(key, down: true, flags: flags)
            } catch {
                try? releaseModifiers(stroke)
                throw error
            }
        }
        // Always release, even if the task is cancelled while holding.
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        if let key = stroke.key {
            try? postKey(key, down: false, flags: flags)
        }
        try releaseModifiers(stroke)
    }

    private enum TypingPiece {
        case text([UniChar])
        case key(CGKeyCode)
    }

    /// Types literal text: chunks of ≤ 20 UTF-16 units via keyboardSetUnicodeString; newlines and tabs as keys.
    private func typeText(_ text: String) async throws {
        var pieces: [TypingPiece] = []
        var chunk: [UniChar] = []
        for character in text {
            if character == "\n" || character == "\r" || character == "\r\n" {
                if !chunk.isEmpty { pieces.append(.text(chunk)); chunk = [] }
                pieces.append(.key(CGKeyCode(kVK_Return)))
                continue
            }
            if character == "\t" {
                if !chunk.isEmpty { pieces.append(.text(chunk)); chunk = [] }
                pieces.append(.key(CGKeyCode(kVK_Tab)))
                continue
            }
            let units = Array(String(character).utf16)
            if !chunk.isEmpty && chunk.count + units.count > ComputerControl.typingChunk {
                pieces.append(.text(chunk))
                chunk = []
            }
            chunk.append(contentsOf: units)
        }
        if !chunk.isEmpty { pieces.append(.text(chunk)) }

        for piece in pieces {
            switch piece {
            case .text(let units):
                try postUnicode(units)
            case .key(let code):
                try postKey(code, down: true, flags: [])
                await pause(milliseconds: 8)
                try postKey(code, down: false, flags: [])
            }
            await pause(milliseconds: 12)
        }
    }

    private func postUnicode(_ units: [UniChar]) throws {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            throw ComputerControlError.eventFailed("keyboard event")
        }
        units.withUnsafeBufferPointer { buffer in
            down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
        }
        down.flags = []
        up.flags = []
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    // MARK: Key names

    /// Modifiers given in the `text` field of click/drag/scroll members ("shift", "cmd+shift", ...).
    private func modifierStroke(_ value: JSONValue?) throws -> KeyStroke {
        guard let raw = value?.stringValue?.trimmed, !raw.isEmpty else { return KeyStroke(modifiers: [], key: nil) }
        var modifiers: [(code: CGKeyCode, flag: CGEventFlags)] = []
        for part in raw.split(whereSeparator: { $0 == "+" || $0 == " " }) {
            let name = String(part).trimmed
            guard !name.isEmpty else { continue }
            guard let modifier = ComputerControl.modifier(named: name) else {
                throw ComputerControlError.invalidInput("'text' on a mouse action may only hold modifier keys (shift, ctrl, alt, cmd); got '\(name)'")
            }
            modifiers.append(modifier)
        }
        return KeyStroke(modifiers: modifiers, key: nil)
    }

    /// "ctrl+a BackSpace" → two strokes. A lone "+" or a trailing "++" means the plus key.
    private static func parseKeySequence(_ raw: String) throws -> [KeyStroke] {
        // "cmd + s" → "cmd+s" (but keep a trailing or lone "+" as the plus key).
        let text = raw.replacingOccurrences(of: #"\s*\+\s*(?=\S)"#, with: "+", options: .regularExpression)
        let combos = text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).map(String.init)
        guard !combos.isEmpty else { throw ComputerControlError.invalidInput("'text' is empty") }
        return try combos.map { try parseCombo($0) }
    }

    private static func parseCombo(_ combo: String) throws -> KeyStroke {
        var parts = combo.components(separatedBy: "+")
        if combo == "+" {
            parts = ["plus"]
        } else if combo.hasSuffix("++") {
            parts = Array(combo.dropLast(2).components(separatedBy: "+")) + ["plus"]
        }
        let names = parts.map { $0.trimmed }.filter { !$0.isEmpty }
        guard let last = names.last else { throw ComputerControlError.unknownKey(combo) }

        var modifiers: [(code: CGKeyCode, flag: CGEventFlags)] = []
        for name in names.dropLast() {
            guard let modifier = modifier(named: name) else { throw ComputerControlError.unknownKey(name) }
            modifiers.append(modifier)
        }
        if let modifier = modifier(named: last) {
            // The combination is only modifiers, e.g. hold_key "shift".
            modifiers.append(modifier)
            return KeyStroke(modifiers: modifiers, key: nil)
        }
        guard let key = keyCode(named: last) else { throw ComputerControlError.unknownKey(last) }
        if key.shifted && !modifiers.contains(where: { $0.flag == .maskShift }) {
            modifiers.append((code: CGKeyCode(kVK_Shift), flag: CGEventFlags.maskShift))
        }
        return KeyStroke(modifiers: modifiers, key: key.code)
    }

    private static func modifier(named raw: String) -> (code: CGKeyCode, flag: CGEventFlags)? {
        switch raw.lowercased() {
        case "cmd", "command", "super", "meta", "win", "windows", "cmd_l", "command_l", "super_l", "meta_l":
            return (code: CGKeyCode(kVK_Command), flag: .maskCommand)
        case "cmd_r", "command_r", "super_r", "meta_r":
            return (code: CGKeyCode(kVK_RightCommand), flag: .maskCommand)
        case "ctrl", "control", "ctrl_l", "control_l":
            return (code: CGKeyCode(kVK_Control), flag: .maskControl)
        case "ctrl_r", "control_r":
            return (code: CGKeyCode(kVK_RightControl), flag: .maskControl)
        case "alt", "option", "opt", "alt_l", "option_l":
            return (code: CGKeyCode(kVK_Option), flag: .maskAlternate)
        case "alt_r", "option_r":
            return (code: CGKeyCode(kVK_RightOption), flag: .maskAlternate)
        case "shift", "shift_l":
            return (code: CGKeyCode(kVK_Shift), flag: .maskShift)
        case "shift_r":
            return (code: CGKeyCode(kVK_RightShift), flag: .maskShift)
        case "fn", "function":
            return (code: CGKeyCode(kVK_Function), flag: .maskSecondaryFn)
        default:
            return nil
        }
    }

    private static let letterCodes: [Character: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E,
        "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J,
        "k": kVK_ANSI_K, "l": kVK_ANSI_L, "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O,
        "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X, "y": kVK_ANSI_Y,
        "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
        "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
    ]

    /// Punctuation by character: (key code, needs shift) on a US layout.
    private static let symbolCodes: [Character: (Int, Bool)] = [
        "-": (kVK_ANSI_Minus, false), "_": (kVK_ANSI_Minus, true),
        "=": (kVK_ANSI_Equal, false), "+": (kVK_ANSI_Equal, true),
        "[": (kVK_ANSI_LeftBracket, false), "{": (kVK_ANSI_LeftBracket, true),
        "]": (kVK_ANSI_RightBracket, false), "}": (kVK_ANSI_RightBracket, true),
        "\\": (kVK_ANSI_Backslash, false), "|": (kVK_ANSI_Backslash, true),
        ";": (kVK_ANSI_Semicolon, false), ":": (kVK_ANSI_Semicolon, true),
        "'": (kVK_ANSI_Quote, false), "\"": (kVK_ANSI_Quote, true),
        ",": (kVK_ANSI_Comma, false), "<": (kVK_ANSI_Comma, true),
        ".": (kVK_ANSI_Period, false), ">": (kVK_ANSI_Period, true),
        "/": (kVK_ANSI_Slash, false), "?": (kVK_ANSI_Slash, true),
        "`": (kVK_ANSI_Grave, false), "~": (kVK_ANSI_Grave, true),
        "!": (kVK_ANSI_1, true), "@": (kVK_ANSI_2, true), "#": (kVK_ANSI_3, true),
        "$": (kVK_ANSI_4, true), "%": (kVK_ANSI_5, true), "^": (kVK_ANSI_6, true),
        "&": (kVK_ANSI_7, true), "*": (kVK_ANSI_8, true), "(": (kVK_ANSI_9, true),
        ")": (kVK_ANSI_0, true),
    ]

    /// Named keys (xdotool / X11 keysym style, lowercased).
    private static let namedCodes: [String: (Int, Bool)] = [
        "return": (kVK_Return, false), "enter": (kVK_Return, false), "kp_enter": (kVK_ANSI_KeypadEnter, false),
        "tab": (kVK_Tab, false), "iso_left_tab": (kVK_Tab, true),
        "escape": (kVK_Escape, false), "esc": (kVK_Escape, false),
        "backspace": (kVK_Delete, false),
        "delete": (kVK_ForwardDelete, false), "del": (kVK_ForwardDelete, false),
        "forwarddelete": (kVK_ForwardDelete, false), "kp_delete": (kVK_ForwardDelete, false),
        "space": (kVK_Space, false), "spacebar": (kVK_Space, false),
        "left": (kVK_LeftArrow, false), "right": (kVK_RightArrow, false),
        "up": (kVK_UpArrow, false), "down": (kVK_DownArrow, false),
        "kp_left": (kVK_LeftArrow, false), "kp_right": (kVK_RightArrow, false),
        "kp_up": (kVK_UpArrow, false), "kp_down": (kVK_DownArrow, false),
        "page_up": (kVK_PageUp, false), "pageup": (kVK_PageUp, false), "prior": (kVK_PageUp, false),
        "page_down": (kVK_PageDown, false), "pagedown": (kVK_PageDown, false), "next": (kVK_PageDown, false),
        "home": (kVK_Home, false), "end": (kVK_End, false),
        "help": (kVK_Help, false), "insert": (kVK_Help, false),
        "caps_lock": (kVK_CapsLock, false), "capslock": (kVK_CapsLock, false),
        "f1": (kVK_F1, false), "f2": (kVK_F2, false), "f3": (kVK_F3, false), "f4": (kVK_F4, false),
        "f5": (kVK_F5, false), "f6": (kVK_F6, false), "f7": (kVK_F7, false), "f8": (kVK_F8, false),
        "f9": (kVK_F9, false), "f10": (kVK_F10, false), "f11": (kVK_F11, false), "f12": (kVK_F12, false),
        "f13": (kVK_F13, false), "f14": (kVK_F14, false), "f15": (kVK_F15, false), "f16": (kVK_F16, false),
        "f17": (kVK_F17, false), "f18": (kVK_F18, false), "f19": (kVK_F19, false), "f20": (kVK_F20, false),
        "minus": (kVK_ANSI_Minus, false), "underscore": (kVK_ANSI_Minus, true),
        "equal": (kVK_ANSI_Equal, false), "plus": (kVK_ANSI_Equal, true),
        "bracketleft": (kVK_ANSI_LeftBracket, false), "bracketright": (kVK_ANSI_RightBracket, false),
        "braceleft": (kVK_ANSI_LeftBracket, true), "braceright": (kVK_ANSI_RightBracket, true),
        "backslash": (kVK_ANSI_Backslash, false), "bar": (kVK_ANSI_Backslash, true),
        "semicolon": (kVK_ANSI_Semicolon, false), "colon": (kVK_ANSI_Semicolon, true),
        "apostrophe": (kVK_ANSI_Quote, false), "quoteright": (kVK_ANSI_Quote, false),
        "quotedbl": (kVK_ANSI_Quote, true),
        "comma": (kVK_ANSI_Comma, false), "less": (kVK_ANSI_Comma, true),
        "period": (kVK_ANSI_Period, false), "greater": (kVK_ANSI_Period, true),
        "slash": (kVK_ANSI_Slash, false), "question": (kVK_ANSI_Slash, true),
        "grave": (kVK_ANSI_Grave, false), "quoteleft": (kVK_ANSI_Grave, false),
        "asciitilde": (kVK_ANSI_Grave, true),
        "exclam": (kVK_ANSI_1, true), "at": (kVK_ANSI_2, true), "numbersign": (kVK_ANSI_3, true),
        "dollar": (kVK_ANSI_4, true), "percent": (kVK_ANSI_5, true), "asciicircum": (kVK_ANSI_6, true),
        "ampersand": (kVK_ANSI_7, true), "asterisk": (kVK_ANSI_8, true),
        "parenleft": (kVK_ANSI_9, true), "parenright": (kVK_ANSI_0, true),
        "volumeup": (kVK_VolumeUp, false), "xf86audioraisevolume": (kVK_VolumeUp, false),
        "volumedown": (kVK_VolumeDown, false), "xf86audiolowervolume": (kVK_VolumeDown, false),
        "mute": (kVK_Mute, false), "xf86audiomute": (kVK_Mute, false),
    ]

    private static func keyCode(named raw: String) -> (code: CGKeyCode, shifted: Bool)? {
        if raw.count == 1, let character = raw.first {
            let lowered = String(character).lowercased()
            if lowered.count == 1, let lower = lowered.first, let code = letterCodes[lower] {
                return (code: CGKeyCode(code), shifted: false)
            }
            if let symbol = symbolCodes[character] {
                return (code: CGKeyCode(symbol.0), shifted: symbol.1)
            }
        }
        if let named = namedCodes[raw.lowercased()] {
            return (code: CGKeyCode(named.0), shifted: named.1)
        }
        return nil
    }
}
