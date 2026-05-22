import Foundation

struct StarlinkSnapshot: Equatable {
    var account: StarlinkAccount
    var dish: DishStatus
    var network: NetworkStats
    var wifi: WiFiStatus
    var telemetry: [TelemetrySignal]
}

struct StarlinkAccount: Equatable {
    var customerName: String
    var email: String
    var serviceLine: String
    var planName: String
}

struct DishStatus: Equatable {
    var name: String
    var serialNumber: String
    var state: ConnectionState
    var obstructionPercent: Double
    var uptime: TimeInterval
    var location: DishLocation
    var snowMeltMode: SnowMeltMode
    var powerSaveEnabled: Bool
}

struct NetworkStats: Equatable {
    var downloadMbps: Double
    var uploadMbps: Double
    var latencyMs: Double
    var packetLoss: Double
}

struct WiFiStatus: Equatable {
    var ssid: String
    var isHidden: Bool
    var bypassModeEnabled: Bool
    var connectedClients: Int
}

struct DishLocation: Equatable {
    var latitude: Double
    var longitude: Double
    var h3Cell: String
}

struct TelemetrySignal: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var value: String
    var status: SignalStatus
}

enum ConnectionState: String, Equatable {
    case online = "Online"
    case searching = "Searching"
    case offline = "Offline"
}

enum SignalStatus: String, Equatable {
    case healthy = "Healthy"
    case warning = "Warning"
    case critical = "Critical"
}

enum SnowMeltMode: String, CaseIterable, Identifiable, Equatable {
    case automatic = "Auto"
    case alwaysOn = "Heat"
    case off = "Off"

    var id: String { rawValue }
}

enum QuickAction: String, CaseIterable, Identifiable {
    case refresh = "Refresh"
    case reboot = "Reboot"
    case stow = "Stow"
    case speedTest = "Speed Test"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .refresh: "arrow.clockwise"
        case .reboot: "power"
        case .stow: "antenna.radiowaves.left.and.right.slash"
        case .speedTest: "gauge.with.dots.needle.67percent"
        }
    }
}
