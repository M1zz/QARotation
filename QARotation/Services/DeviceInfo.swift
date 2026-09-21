import UIKit

@MainActor
enum DeviceInfo {
    static var osVersion: String { "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)" }

    /// 예: "iPhone (iPhone17,1)"
    static var deviceModel: String { "\(UIDevice.current.model) (\(modelIdentifier))" }

    static var modelIdentifier: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        #else
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
        #endif
    }
}
