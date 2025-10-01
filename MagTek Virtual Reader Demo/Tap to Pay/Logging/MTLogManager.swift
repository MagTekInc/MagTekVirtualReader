//
//  Created by MagTek on 8/20/25.
//  Copyright © 2025 MagTek, Inc. All rights reserved.
//

import SwiftUI
import MagTekVirtualReader

enum MTLogLevel: String, CaseIterable, Identifiable, Codable {
    case debug, info, warning, error
    
    var id: String { self.rawValue }
    
    var color: Color {
        switch self {
        case .debug: return .green
        case .info: return .gray
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct MTLogEntry: Identifiable, Codable, Equatable {
    let timestamp: Date
    let message: String
    let level: MTLogLevel
    var id = UUID()
    
    static func == (lhs: MTLogEntry, rhs: MTLogEntry) -> Bool {
        lhs.timestamp == rhs.timestamp &&
        lhs.message == rhs.message &&
        lhs.level == rhs.level
    }
}

final class MTLogManager: ObservableObject {
    static let shared = MTLogManager()
    
    @Published private(set) var logEntries: [MTLogEntry] = []
    private let maxEntries: Int = 500
    
    private init() {}
    
    func debug(_ message: String) {
        Task { @MainActor in
            log(message: message, level: .debug)
        }
    }
    
    func info(_ message: String) {
        Task { @MainActor in
            log(message: message, level: .info)
        }
    }
    
    func warning(_ message: String) {
        Task { @MainActor in
            log(message: message, level: .warning)
        }
    }
    
    func error(_ message: String) {
        Task { @MainActor in
            log(message: message, level: .error)
        }
    }
    
    private func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
    
    // Basic Info we want in all logs.
    func logDeviceInfo() {
        let deviceInfo = """
                SDK: \(MagTekVirtualCardReader.getSDKVersion())
                iOS: \(UIDevice.current.systemVersion)
                Model: \(deviceModelIdentifier())
            """
        
        info(deviceInfo)
    }
    
    @MainActor
    func clearLogs() {
        logEntries = []
        logDeviceInfo()
    }
    
    @MainActor
    private func log(message: String, level: MTLogLevel) {
        let entry = MTLogEntry(timestamp: Date(), message: message, level: level)
        appendEntry(entry)
    }
    
    @MainActor
    private func appendEntry(_ entry: MTLogEntry) {
        if logEntries.count >= maxEntries {
            logEntries.removeFirst()
        }
        logEntries.append(entry)
    }
    
    func copyLogsToClipboard() {
        Task { @MainActor in
            let allLogs = logEntries.map { entry in
                "• \(logDateFormatter.string(from: entry.timestamp)) [\(entry.level.rawValue.uppercased())]: \(entry.message)"
            }.joined(separator: "\n")
            UIPasteboard.general.string = allLogs
        }
    }
    
    let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
