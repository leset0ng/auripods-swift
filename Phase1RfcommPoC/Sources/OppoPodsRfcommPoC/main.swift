import Foundation
import IOBluetooth

private let defaultRFCOMMChannel: BluetoothRFCOMMChannelID = 15
private let scanRange: ClosedRange<BluetoothRFCOMMChannelID> = 1...30
private let listenDuration: TimeInterval = 10

enum PoCError: Error, CustomStringConvertible {
    case invalidArgument(String)
    case deviceNotFound(String?)
    case rfcommConnectFailed(BluetoothRFCOMMChannelID, IOReturn)
    case noOpenChannel

    var description: String {
        switch self {
        case .invalidArgument(let value):
            return "Invalid argument: \(value)"
        case .deviceNotFound(let target):
            if let target {
                return "No paired Bluetooth device matched: \(target)"
            }
            return "No paired OPPO/Enco device was found"
        case .rfcommConnectFailed(let channel, let status):
            return "RFCOMM channel \(channel) connect failed: \(formatIOReturn(status))"
        case .noOpenChannel:
            return "No RFCOMM channel could be opened"
        }
    }
}

struct Options {
    var target: String?
    var explicitChannel: BluetoothRFCOMMChannelID?
    var listOnly = false
}

struct RFCOMMFailure: Error {
    let channelID: BluetoothRFCOMMChannelID
    let status: IOReturn

    var message: String {
        "RFCOMM channel \(channelID) connect failed: \(formatIOReturn(status))"
    }
}

final class RFCOMMListener: NSObject {
    private(set) var isClosed = false

    @objc func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status: IOReturn) {
        print("OPEN:")
        print(formatIOReturn(status))
    }

    @objc func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        isClosed = true
        print("CLOSED")
    }

    @objc func rfcommChannelData(
        _ rfcommChannel: IOBluetoothRFCOMMChannel!,
        data dataPointer: UnsafeMutableRawPointer!,
        length dataLength: Int
    ) {
        guard let dataPointer, dataLength > 0 else { return }
        let data = Data(bytes: dataPointer, count: dataLength)
        print("RECV:")
        print(data.hexString)
    }
}

extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

func parseOptions() throws -> Options {
    var options = Options()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()

    while let argument = iterator.next() {
        switch argument {
        case "--name", "--address", "--target":
            guard let value = iterator.next() else {
                throw PoCError.invalidArgument(argument)
            }
            options.target = value
        case "--channel":
            guard let value = iterator.next(), let channel = UInt8(value) else {
                throw PoCError.invalidArgument(argument)
            }
            options.explicitChannel = BluetoothRFCOMMChannelID(channel)
        case "--list":
            options.listOnly = true
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            if options.target == nil {
                options.target = argument
            } else {
                throw PoCError.invalidArgument(argument)
            }
        }
    }

    return options
}

func printUsage() {
    print("""
    Usage:
      OppoPodsRfcommPoC --name "OPPO Enco Air4 Pro"
      OppoPodsRfcommPoC --address "AA-BB-CC-DD-EE-FF"
      OppoPodsRfcommPoC --list

    Options:
      --channel 15       Try one RFCOMM channel only.
    """)
}

func pairedDevices() -> [IOBluetoothDevice] {
    (IOBluetoothDevice.pairedDevices() ?? []).compactMap { $0 as? IOBluetoothDevice }
}

func printPairedDevices(_ devices: [IOBluetoothDevice]) {
    print("Paired Bluetooth Devices:")
    for device in devices {
        let name = device.name ?? "(unknown)"
        let address = device.addressString ?? "(no address)"
        print("- \(name) [\(address)]")
    }
}

func findTargetDevice(in devices: [IOBluetoothDevice], target: String?) throws -> IOBluetoothDevice {
    if let target {
        let normalizedTarget = normalize(target)
        if let device = devices.first(where: { device in
            normalize(device.name ?? "").contains(normalizedTarget)
                || normalize(device.addressString ?? "").contains(normalizedTarget)
        }) {
            return device
        }
        throw PoCError.deviceNotFound(target)
    }

    if let device = devices.first(where: { device in
        let name = normalize(device.name ?? "")
        return name.contains("oppo")
            || name.contains("enco")
            || name.contains("oneplus")
            || name.contains("realme")
    }) {
        return device
    }

    throw PoCError.deviceNotFound(nil)
}

func normalize(_ value: String) -> String {
    value
        .lowercased()
        .filter { $0.isLetter || $0.isNumber }
}

func openRFCOMMChannel(
    device: IOBluetoothDevice,
    channelID: BluetoothRFCOMMChannelID,
    listener: RFCOMMListener
) -> Result<IOBluetoothRFCOMMChannel, RFCOMMFailure> {
    var channel: IOBluetoothRFCOMMChannel?
    let status = device.openRFCOMMChannelSync(&channel, withChannelID: channelID, delegate: listener)

    guard status == kIOReturnSuccess, let channel else {
        return .failure(RFCOMMFailure(channelID: channelID, status: status))
    }

    return .success(channel)
}

func tryChannel15(device: IOBluetoothDevice, listener: RFCOMMListener) -> Result<IOBluetoothRFCOMMChannel, RFCOMMFailure> {
    print("Trying RFCOMM Channel 15...")
    let result = openRFCOMMChannel(device: device, channelID: defaultRFCOMMChannel, listener: listener)

    switch result {
    case .success:
        print("SUCCESS")
    case .failure(let failure):
        print("FAILED: \(failure.message)")
    }

    return result
}

func scanRFCOMMChannels(
    device: IOBluetoothDevice,
    listener: RFCOMMListener,
    cachedChannel15Failure: RFCOMMFailure
) -> IOBluetoothRFCOMMChannel? {
    print("Scanning RFCOMM channels 1...30")

    for channelID in scanRange {
        if channelID == cachedChannel15Failure.channelID {
            print("Channel \(channelID) -> failed: \(formatIOReturn(cachedChannel15Failure.status))")
            continue
        }

        switch openRFCOMMChannel(device: device, channelID: channelID, listener: listener) {
        case .success(let channel):
            print("Channel \(channelID) -> success")
            return channel
        case .failure(let failure):
            print("Channel \(channelID) -> failed: \(formatIOReturn(failure.status))")
        }
    }

    return nil
}

func keepConnectionAlive(channel: IOBluetoothRFCOMMChannel, listener: RFCOMMListener) {
    print("Connected RFCOMM Channel: \(channel.getID())")
    print("Listening for 10 seconds...")

    let deadline = Date().addingTimeInterval(listenDuration)
    while !listener.isClosed && Date() < deadline {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
    }
}

func formatIOReturn(_ value: IOReturn) -> String {
    "0x" + String(UInt32(bitPattern: value), radix: 16, uppercase: true)
}

func run() throws {
    let options = try parseOptions()
    let devices = pairedDevices()
    printPairedDevices(devices)

    if options.listOnly {
        return
    }

    let device = try findTargetDevice(in: devices, target: options.target)
    let deviceName = device.name ?? "OPPO device"
    print("Target Device: \(deviceName)")
    print("Target Address: \(device.addressString ?? "(no address)")")

    let listener = RFCOMMListener()
    let channel: IOBluetoothRFCOMMChannel

    if let explicitChannel = options.explicitChannel {
        print("Trying RFCOMM Channel \(explicitChannel)...")
        switch openRFCOMMChannel(device: device, channelID: explicitChannel, listener: listener) {
        case .success(let openedChannel):
            print("SUCCESS")
            channel = openedChannel
        case .failure(let failure):
            print("FAILED: \(failure.message)")
            throw PoCError.rfcommConnectFailed(failure.channelID, failure.status)
        }
    } else {
        switch tryChannel15(device: device, listener: listener) {
        case .success(let openedChannel):
            channel = openedChannel
        case .failure(let failure):
            guard let scannedChannel = scanRFCOMMChannels(
                device: device,
                listener: listener,
                cachedChannel15Failure: failure
            ) else {
                throw PoCError.noOpenChannel
            }
            channel = scannedChannel
        }
    }

    defer {
        channel.close()
    }

    keepConnectionAlive(channel: channel, listener: listener)
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("ERROR: \(error)\n".utf8))
    exit(1)
}
