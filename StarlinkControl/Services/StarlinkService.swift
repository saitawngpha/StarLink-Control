import Foundation

protocol StarlinkServicing {
    func fetchSnapshot() async throws -> StarlinkSnapshot
    func rebootDish() async throws
    func stowDish() async throws
    func runSpeedTest() async throws -> NetworkStats
    func updateWiFi(ssid: String, password: String?, isHidden: Bool, bypassModeEnabled: Bool) async throws -> WiFiStatus
    func setSnowMeltMode(_ mode: SnowMeltMode) async throws -> DishStatus
    func setPowerSaveEnabled(_ isEnabled: Bool) async throws -> DishStatus
}

enum StarlinkServiceError: LocalizedError {
    case invalidWiFiName

    var errorDescription: String? {
        switch self {
        case .invalidWiFiName:
            "Wi-Fi name cannot be empty."
        }
    }
}

final class MockStarlinkService: StarlinkServicing {
    private var snapshot = StarlinkSnapshot.sample

    func fetchSnapshot() async throws -> StarlinkSnapshot {
        try await Task.sleep(for: .milliseconds(450))
        snapshot.network.downloadMbps = Double.random(in: 145...235)
        snapshot.network.uploadMbps = Double.random(in: 16...34)
        snapshot.network.latencyMs = Double.random(in: 25...48)
        snapshot.network.packetLoss = Double.random(in: 0...0.8)
        snapshot.wifi.connectedClients = Int.random(in: 8...23)
        return snapshot
    }

    func rebootDish() async throws {
        try await Task.sleep(for: .seconds(1))
        snapshot.dish.state = .searching
    }

    func stowDish() async throws {
        try await Task.sleep(for: .milliseconds(700))
        snapshot.dish.state = .offline
    }

    func runSpeedTest() async throws -> NetworkStats {
        try await Task.sleep(for: .seconds(1))
        let result = NetworkStats(
            downloadMbps: Double.random(in: 180...280),
            uploadMbps: Double.random(in: 22...42),
            latencyMs: Double.random(in: 19...39),
            packetLoss: Double.random(in: 0...0.4)
        )
        snapshot.network = result
        return result
    }

    func updateWiFi(ssid: String, password: String?, isHidden: Bool, bypassModeEnabled: Bool) async throws -> WiFiStatus {
        let cleanSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanSSID.isEmpty == false else {
            throw StarlinkServiceError.invalidWiFiName
        }

        try await Task.sleep(for: .milliseconds(600))
        snapshot.wifi.ssid = cleanSSID
        snapshot.wifi.isHidden = isHidden
        snapshot.wifi.bypassModeEnabled = bypassModeEnabled
        return snapshot.wifi
    }

    func setSnowMeltMode(_ mode: SnowMeltMode) async throws -> DishStatus {
        try await Task.sleep(for: .milliseconds(400))
        snapshot.dish.snowMeltMode = mode
        return snapshot.dish
    }

    func setPowerSaveEnabled(_ isEnabled: Bool) async throws -> DishStatus {
        try await Task.sleep(for: .milliseconds(400))
        snapshot.dish.powerSaveEnabled = isEnabled
        return snapshot.dish
    }
}

extension StarlinkSnapshot {
    static let sample = StarlinkSnapshot(
        account: StarlinkAccount(
            customerName: "Steve Pha",
            email: "steve@example.com",
            serviceLine: "SL-4207-8841",
            planName: "Residential"
        ),
        dish: DishStatus(
            name: "Starlink Ridge",
            serialNumber: "KITP-24A9-81F2",
            state: .online,
            obstructionPercent: 1.8,
            uptime: 694_420,
            location: DishLocation(
                latitude: 13.7563,
                longitude: 100.5018,
                h3Cell: "886520d8b7fffff"
            ),
            snowMeltMode: .automatic,
            powerSaveEnabled: false
        ),
        network: NetworkStats(
            downloadMbps: 196,
            uploadMbps: 28,
            latencyMs: 34,
            packetLoss: 0.2
        ),
        wifi: WiFiStatus(
            ssid: "Starlink Home",
            isHidden: false,
            bypassModeEnabled: false,
            connectedClients: 14
        ),
        telemetry: [
            TelemetrySignal(title: "Dish Motors", value: "Nominal", status: .healthy),
            TelemetrySignal(title: "Thermals", value: "42 C", status: .healthy),
            TelemetrySignal(title: "Obstruction", value: "Low", status: .healthy),
            TelemetrySignal(title: "Router Load", value: "Medium", status: .warning)
        ]
    )
}
