//  Pairing.swift
//  Pairs watches with the Mac using a short-lived 6-digit code shown on the Mac.
//  A successful pairing yields a random 256-bit bearer token stored with the device.

import Foundation
import Security

final class PairingManager: @unchecked Sendable {
    private static let rotationInterval: TimeInterval = 10 * 60
    /// After this many wrong guesses the code is replaced, so it cannot be brute-forced.
    private static let maxFailedAttemptsPerCode = 5

    private let db: Database
    private let lock = NSLock()
    private var currentCode = ""
    private var expiry = Date.distantPast
    private var failedAttempts = 0

    init(db: Database) {
        self.db = db
        lock.lock()
        rotateLocked()
        lock.unlock()
    }

    /// The current 6-digit code (rotated lazily once it expires).
    var code: String {
        lock.lock()
        defer { lock.unlock() }
        refreshIfNeededLocked()
        return currentCode
    }

    /// When the current code stops being accepted.
    var codeExpiresAt: Date {
        lock.lock()
        defer { lock.unlock() }
        refreshIfNeededLocked()
        return expiry
    }

    func regenerateCode() {
        lock.lock()
        rotateLocked()
        lock.unlock()
        EarshotEvents.post(.devices)
    }

    /// Validates the code in constant time and registers the device with a fresh token.
    /// The code is single-use: it rotates after a successful pairing.
    func pair(_ request: PairRequest) -> PairedDevice? {
        let submitted = String(request.code.filter { $0.isASCII && $0.isWholeNumber })
        let deviceName = request.deviceName.nilIfEmpty ?? "Apple Watch"
        let deviceKind = request.deviceKind.nilIfEmpty ?? "watch"

        lock.lock()
        refreshIfNeededLocked()
        let matches = PairingManager.constantTimeEquals(submitted, currentCode)
        var rotatedAfterFailures = false
        if matches {
            rotateLocked()
        } else {
            failedAttempts += 1
            if failedAttempts >= PairingManager.maxFailedAttemptsPerCode {
                rotateLocked()
                rotatedAfterFailures = true
            }
        }
        lock.unlock()

        guard matches else {
            Log.info("Pairing rejected for “\(deviceName)”: wrong or expired code")
            if rotatedAfterFailures {
                Log.info("Pairing: too many wrong codes; issued a new code")
                // The Devices screen shows the code, so let it refresh.
                EarshotEvents.post(.devices)
            }
            return nil
        }

        let now = Date()
        let device = PairedDevice(token: PairingManager.makeToken(), name: deviceName, kind: deviceKind,
                                  pairedAt: now, lastSeen: now, lastStatus: nil)
        db.upsertDevice(device)
        Log.info("Pairing: paired \(deviceKind) “\(deviceName)”")
        EarshotEvents.post(.devices)
        return device
    }

    /// Accepts "Bearer <token>" (scheme is case-insensitive).
    func authenticate(authorizationHeader: String?) -> PairedDevice? {
        guard let header = authorizationHeader?.trimmingCharacters(in: .whitespacesAndNewlines),
              !header.isEmpty else { return nil }
        let parts = header.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2, parts[0].lowercased() == "bearer" else { return nil }
        let token = parts[1].trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty, token.count <= 256,
              token.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return db.device(token: token)
    }

    func unpair(token: String) {
        db.deleteDevice(token: token)
        Log.info("Pairing: removed a paired device")
        EarshotEvents.post(.devices)
    }

    // MARK: - Private

    /// Call with `lock` held.
    private func refreshIfNeededLocked() {
        if Date() >= expiry { rotateLocked() }
    }

    /// Call with `lock` held.
    private func rotateLocked() {
        currentCode = PairingManager.makeCode()
        expiry = Date().addingTimeInterval(PairingManager.rotationInterval)
        failedAttempts = 0
    }

    private static func makeCode() -> String {
        var generator = SystemRandomNumberGenerator()
        let number = Int.random(in: 0..<1_000_000, using: &generator)
        let digits = String(number)
        return String(repeating: "0", count: max(0, 6 - digits.count)) + digits
    }

    /// 32 random bytes, hex encoded (64 characters).
    private static func makeToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            Log.error("Pairing: SecRandomCopyBytes failed (\(status)); using the system RNG")
            var generator = SystemRandomNumberGenerator()
            for index in bytes.indices {
                bytes[index] = UInt8.random(in: UInt8.min...UInt8.max, using: &generator)
            }
        }
        let hexDigits = Array("0123456789abcdef")
        var token = ""
        token.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            token.append(hexDigits[Int(byte >> 4)])
            token.append(hexDigits[Int(byte & 0x0F)])
        }
        return token
    }

    /// Compares every byte regardless of where the first difference is.
    private static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        var difference: UInt8 = a.count == b.count ? 0 : 1
        let length = max(a.count, b.count)
        for index in 0..<length {
            let x: UInt8 = index < a.count ? a[index] : 0
            let y: UInt8 = index < b.count ? b[index] : 0
            difference |= x ^ y
        }
        return difference == 0 && !a.isEmpty
    }
}
