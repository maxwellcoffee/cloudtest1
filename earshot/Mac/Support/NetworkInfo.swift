//  NetworkInfo.swift
//  Local IPv4 addresses to show next to the pairing code ("http://192.168.1.20:8737").

import Foundation
import Darwin

enum NetworkInfo {
    /// Non-loopback, non-link-local IPv4 addresses of interfaces that are up; en0 first.
    static func localIPv4Addresses() -> [String] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else {
            Log.error("NetworkInfo: getifaddrs failed (errno \(errno))")
            return []
        }
        defer { freeifaddrs(head) }

        var found: [(interface: String, address: String)] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            cursor = entry.pointee.ifa_next
            let flags = Int32(truncatingIfNeeded: entry.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0,
                  let address = entry.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(address, socklen_t(address.pointee.sa_len),
                                     &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            guard result == 0 else { continue }
            let ip = host.withUnsafeBufferPointer { buffer -> String in
                guard let base = buffer.baseAddress else { return "" }
                return String(cString: base)
            }
            guard !ip.isEmpty, !ip.hasPrefix("127."), !ip.hasPrefix("169.254.") else { continue }
            let interface = String(cString: entry.pointee.ifa_name)
            found.append((interface: interface, address: ip))
        }

        // en0 first, then other Ethernet/Wi-Fi interfaces, then everything else (VPNs, bridges).
        func rank(_ interface: String) -> Int {
            if interface == "en0" { return 0 }
            if interface.hasPrefix("en") { return 1 }
            return 2
        }
        let ordered = found.enumerated().sorted { lhs, rhs in
            let left = rank(lhs.element.interface)
            let right = rank(rhs.element.interface)
            if left != right { return left < right }
            return lhs.offset < rhs.offset
        }

        var seen = Set<String>()
        var addresses: [String] = []
        for item in ordered where !seen.contains(item.element.address) {
            seen.insert(item.element.address)
            addresses.append(item.element.address)
        }
        return addresses
    }
}
