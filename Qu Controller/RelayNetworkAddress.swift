import Darwin
import Foundation

struct RelayNetworkAddress: Equatable, Identifiable {
    let interfaceName: String
    let interfaceLabel: String
    let host: String

    var id: String {
        "\(interfaceName)-\(host)"
    }
}

enum RelayNetworkAddressProvider {
    static func currentIPv4Addresses(interfaceLabels: [String: String]) -> [RelayNetworkAddress] {
        var interfaceList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceList) == 0, let firstInterface = interfaceList else {
            return []
        }
        defer { freeifaddrs(interfaceList) }

        var addresses: [RelayNetworkAddress] = []
        var currentInterface: UnsafeMutablePointer<ifaddrs>? = firstInterface

        while let interface = currentInterface?.pointee {
            defer { currentInterface = interface.ifa_next }

            guard let socketAddress = interface.ifa_addr,
                  socketAddress.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            let interfaceName = String(cString: interface.ifa_name)
            guard let interfaceLabel = interfaceLabels[interfaceName] else {
                continue
            }

            let flags = Int32(interface.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else {
                continue
            }

            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                socketAddress,
                socklen_t(socketAddress.pointee.sa_len),
                &hostBuffer,
                socklen_t(hostBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            guard result == 0 else { continue }
            let host = String(cString: hostBuffer)
            guard !host.hasPrefix("169.254.") else { continue }

            addresses.append(
                RelayNetworkAddress(
                    interfaceName: interfaceName,
                    interfaceLabel: interfaceLabel,
                    host: host
                )
            )
        }

        return addresses
            .uniqued()
            .sorted {
                ($0.interfaceLabel, $0.host) < ($1.interfaceLabel, $1.host)
            }
    }
}

private extension Array where Element == RelayNetworkAddress {
    func uniqued() -> [RelayNetworkAddress] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}
