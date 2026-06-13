import Foundation

struct BluetoothDeviceSnapshot: Equatable, Identifiable {
    let name: String
    let address: String
    let isConnected: Bool
    let timestamp: Date

    var id: String {
        "\(address)-\(timestamp.timeIntervalSince1970)"
    }
}
