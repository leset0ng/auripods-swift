import Foundation

struct BatteryState: Equatable {
    var left: UInt8?
    var right: UInt8?
    var batteryCase: UInt8?

    static let unknown = BatteryState(left: nil, right: nil, batteryCase: nil)

    var averageLevel: Int? {
        let values = [left, right, batteryCase].compactMap { $0 }
        guard !values.isEmpty else { return nil }

        let total = values.reduce(0) { $0 + Int($1) }
        return total / values.count
    }

    func text(for component: BatteryComponent) -> String {
        let value: UInt8?
        switch component {
        case .left:
            value = left
        case .right:
            value = right
        case .batteryCase:
            value = batteryCase
        }

        guard let value else {
            return "--"
        }

        return "\(value)%"
    }
}

enum BatteryComponent {
    case left
    case right
    case batteryCase
}
