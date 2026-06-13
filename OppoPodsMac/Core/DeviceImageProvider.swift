import AppKit
import Foundation

struct DeviceImageSet {
    let primary: String?
    let caseImage: String?
    let leftBud: String?
    let rightBud: String?

    static let empty = DeviceImageSet(primary: nil, caseImage: nil, leftBud: nil, rightBud: nil)
}

struct DeviceImageDescriptor {
    let productId: String?
    let colorId: String?
    let modelName: String?
    let imageSet: DeviceImageSet
}

final class DeviceImageProvider {
    static let shared = DeviceImageProvider()

    private let descriptors: [DeviceImageDescriptor]
    private let defaultImageSet = DeviceImageSet(
        primary: "oppo_enco_air4_pro_white",
        caseImage: "oppo_enco_air4_pro_black",
        leftBud: nil,
        rightBud: nil
    )

    private init() {
        descriptors = [
            DeviceImageDescriptor(
                productId: "oppo_enco_air4_pro",
                colorId: "white",
                modelName: "OPPO Enco Air4 Pro",
                imageSet: DeviceImageSet(
                    primary: "oppo_enco_air4_pro_white",
                    caseImage: "oppo_enco_air4_pro_white",
                    leftBud: nil,
                    rightBud: nil
                )
            ),
            DeviceImageDescriptor(
                productId: "oppo_enco_air4_pro",
                colorId: "black",
                modelName: "OPPO Enco Air4 Pro",
                imageSet: DeviceImageSet(
                    primary: "oppo_enco_air4_pro_black",
                    caseImage: "oppo_enco_air4_pro_black",
                    leftBud: nil,
                    rightBud: nil
                )
            )
        ]
    }

    func imageSet(for state: EarbudsState) -> DeviceImageSet {
        imageSet(
            productId: nil,
            colorId: nil,
            modelName: state.currentDevice?.name ?? state.deviceName
        )
    }

    func imageSet(for snapshot: BluetoothDeviceSnapshot?) -> DeviceImageSet {
        imageSet(productId: nil, colorId: nil, modelName: snapshot?.name)
    }

    func imageSet(productId: String? = nil, colorId: String? = nil, modelName: String? = nil) -> DeviceImageSet {
        let normalizedProductId = normalized(productId)
        let normalizedColorId = colorKey(from: colorId) ?? colorKey(from: modelName)

        if let normalizedProductId {
            if let descriptor = descriptors.first(where: { descriptor in
                normalized(descriptor.productId) == normalizedProductId &&
                normalized(descriptor.colorId) == normalizedColorId
            }) {
                return validated(descriptor.imageSet)
            }

            if let descriptor = descriptors.first(where: { descriptor in
                normalized(descriptor.productId) == normalizedProductId
            }) {
                return validated(descriptor.imageSet)
            }
        }

        if let normalizedColorId,
           let descriptor = descriptors.first(where: { normalized($0.colorId) == normalizedColorId }) {
            return validated(descriptor.imageSet)
        }

        if let descriptor = descriptors.first(where: { descriptor in
            normalized(descriptor.colorId) == normalizedColorId &&
            matches(modelName: modelName, descriptor: descriptor)
        }) {
            return validated(descriptor.imageSet)
        }

        if isKnownFamily(modelName) || normalizedProductId == nil {
            return validated(defaultImageSet)
        }

        return .empty
    }

    func primaryImageName(for state: EarbudsState) -> String? {
        imageSet(for: state).primary
    }

    func primaryImageName(for snapshot: BluetoothDeviceSnapshot?) -> String? {
        imageSet(for: snapshot).primary
    }

    func primaryImageName(productId: String? = nil, colorId: String? = nil, modelName: String? = nil) -> String? {
        imageSet(productId: productId, colorId: colorId, modelName: modelName).primary
    }

    private func validated(_ imageSet: DeviceImageSet) -> DeviceImageSet {
        DeviceImageSet(
            primary: availableImageName(imageSet.primary),
            caseImage: availableImageName(imageSet.caseImage),
            leftBud: availableImageName(imageSet.leftBud),
            rightBud: availableImageName(imageSet.rightBud)
        )
    }

    private func availableImageName(_ imageName: String?) -> String? {
        guard let imageName, NSImage(named: imageName) != nil else {
            return nil
        }

        return imageName
    }

    private func matches(modelName: String?, descriptor: DeviceImageDescriptor) -> Bool {
        guard let modelName, let descriptorModelName = descriptor.modelName else {
            return false
        }

        return normalized(modelName)?.contains(normalized(descriptorModelName) ?? "") == true
    }

    private func isKnownFamily(_ modelName: String?) -> Bool {
        guard let modelName = normalized(modelName) else {
            return true
        }

        return ["oppo", "oneplus", "realme", "enco", "buds"].contains { modelName.contains($0) }
    }

    private func colorKey(from value: String?) -> String? {
        guard let value = normalized(value) else {
            return nil
        }

        if value.contains("black") || value.contains("dark") || value.contains("night") || value.contains("星夜") || value.contains("黑") {
            return "black"
        }

        if value.contains("white") || value.contains("light") || value.contains("白") {
            return "white"
        }

        return nil
    }

    private func normalized(_ value: String?) -> String? {
        let normalizedValue = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let normalizedValue, !normalizedValue.isEmpty else {
            return nil
        }

        return normalizedValue
    }
}
