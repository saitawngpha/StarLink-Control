import Foundation
import GRPC
import NIO

final class GeneratedStarlinkService: StarlinkServicing {
    private let host: String
    private let port: Int
    private let group: EventLoopGroup
    private let channel: GRPCChannel
    private let client: SpaceX_API_Device_DeviceAsyncClient
    private let callOptions: CallOptions
    private var nextRequestID: UInt64 = 1

    init(host: String = "192.168.100.1", port: Int = 9200) {
        self.host = host
        self.port = port
        self.group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
        self.channel = ClientConnection
            .insecure(group: group)
            .connect(host: host, port: port)
        self.callOptions = CallOptions(timeLimit: .timeout(.seconds(6)))
        self.client = SpaceX_API_Device_DeviceAsyncClient(channel: channel)
    }

    deinit {
        try? group.syncShutdownGracefully()
    }

    func fetchSnapshot() async throws -> StarlinkSnapshot {
        var request = nextRequest()
        request.getStatus = SpaceX_API_Device_GetStatusRequest()
        let response = try await handle(request)
        let status = response.dishGetStatus

        let downloadMbps = Double(status.downlinkThroughputBps) / 1_000_000
        let uploadMbps = Double(status.uplinkThroughputBps) / 1_000_000
        let obstruction = Double(status.obstructionStats.fractionObstructed * 100)
        let state: ConnectionState = status.deviceState.uptimeS > 0 ? .online : .searching

        return StarlinkSnapshot(
            account: StarlinkAccount(
                customerName: "Unavailable locally",
                email: "Requires Starlink login",
                serviceLine: status.deviceInfo.id.isEmpty ? host : status.deviceInfo.id,
                planName: "Dish gRPC"
            ),
            dish: DishStatus(
                name: "Starlink Dish",
                serialNumber: status.deviceInfo.id.isEmpty ? "Unknown" : status.deviceInfo.id,
                state: state,
                obstructionPercent: obstruction,
                uptime: TimeInterval(status.deviceState.uptimeS),
                location: DishLocation(latitude: 0, longitude: 0, h3Cell: "Local only"),
                snowMeltMode: .automatic,
                powerSaveEnabled: false
            ),
            network: NetworkStats(
                downloadMbps: downloadMbps,
                uploadMbps: uploadMbps,
                latencyMs: Double(status.popPingLatencyMs),
                packetLoss: Double(status.popPingDropRate * 100)
            ),
            wifi: WiFiStatus(
                ssid: "Starlink",
                isHidden: false,
                bypassModeEnabled: false,
                connectedClients: 0
            ),
            telemetry: [
                TelemetrySignal(title: "Dish gRPC", value: "\(host):\(port)", status: .healthy),
                TelemetrySignal(title: "Obstruction", value: status.obstructionStats.currentlyObstructed ? "Active" : "Clear", status: status.obstructionStats.currentlyObstructed ? .warning : .healthy),
                TelemetrySignal(title: "GPS", value: status.gpsStats.gpsValid ? "Valid" : "Unknown", status: status.gpsStats.gpsValid ? .healthy : .warning)
            ]
        )
    }

    func rebootDish() async throws {
        var request = nextRequest()
        request.reboot = SpaceX_API_Device_RebootRequest()
        _ = try await handle(request)
    }

    func stowDish() async throws {
        var request = nextRequest()
        request.dishStow = SpaceX_API_Device_DishStowRequest()
        _ = try await handle(request)
    }

    func runSpeedTest() async throws -> NetworkStats {
        let measured = try await ClientSpeedTester().run()
        let statusSnapshot = try await fetchSnapshot()

        return NetworkStats(
            downloadMbps: measured.downloadMbps,
            uploadMbps: measured.uploadMbps,
            latencyMs: measured.latencyMs > 0 ? measured.latencyMs : statusSnapshot.network.latencyMs,
            packetLoss: statusSnapshot.network.packetLoss
        )
    }

    func updateWiFi(ssid: String, password: String?, isHidden: Bool, bypassModeEnabled: Bool) async throws -> WiFiStatus {
        throw StarlinkGeneratedServiceError.notImplemented("Wi-Fi config writes need authenticated router requests.")
    }

    func setSnowMeltMode(_ mode: SnowMeltMode) async throws -> DishStatus {
        throw StarlinkGeneratedServiceError.notImplemented("Dish config writes need authenticated signed requests.")
    }

    func setPowerSaveEnabled(_ isEnabled: Bool) async throws -> DishStatus {
        throw StarlinkGeneratedServiceError.notImplemented("Power save writes need authenticated signed requests.")
    }

    private func nextRequest() -> SpaceX_API_Device_Request {
        var request = SpaceX_API_Device_Request()
        request.id = nextRequestID
        nextRequestID += 1
        return request
    }

    private func handle(_ request: SpaceX_API_Device_Request) async throws -> SpaceX_API_Device_Response {
        do {
            return try await client.handle(request, callOptions: callOptions)
        } catch is CancellationError {
            throw StarlinkGeneratedServiceError.connectionFailed(host: host, port: port)
        } catch let error as GRPCStatus {
            throw StarlinkGeneratedServiceError.grpc(error)
        } catch {
            throw StarlinkGeneratedServiceError.wrapped(error)
        }
    }
}

private struct ClientSpeedTester {
    private let session: URLSession
    private let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=25000000")!
    private let uploadURL = URL(string: "https://speed.cloudflare.com/__up")!
    private let latencyURL = URL(string: "https://speed.cloudflare.com/__down?bytes=1")!

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        self.session = URLSession(configuration: configuration)
    }

    func run() async throws -> NetworkStats {
        async let latency = measureLatency()
        async let download = measureDownload()
        async let upload = measureUpload()

        do {
            return NetworkStats(
                downloadMbps: try await download,
                uploadMbps: try await upload,
                latencyMs: try await latency,
                packetLoss: 0
            )
        } catch {
            throw StarlinkGeneratedServiceError.speedTestFailed("Client speed test failed: \(error.localizedDescription)")
        }
    }

    private func measureDownload() async throws -> Double {
        let start = Date()
        let (data, response) = try await session.data(from: downloadURL)
        try validate(response)
        let seconds = max(Date().timeIntervalSince(start), 0.001)
        return Double(data.count * 8) / seconds / 1_000_000
    }

    private func measureUpload() async throws -> Double {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let body = Data(repeating: 7, count: 8_000_000)
        let start = Date()
        let (_, response) = try await session.upload(for: request, from: body)
        try validate(response)
        let seconds = max(Date().timeIntervalSince(start), 0.001)
        return Double(body.count * 8) / seconds / 1_000_000
    }

    private func measureLatency() async throws -> Double {
        var samples: [Double] = []

        for _ in 0..<4 {
            let start = Date()
            let (_, response) = try await session.data(from: latencyURL)
            try validate(response)
            samples.append(Date().timeIntervalSince(start) * 1_000)
        }

        return samples.sorted().dropLast().last ?? samples.min() ?? 0
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw StarlinkGeneratedServiceError.speedTestFailed("Unexpected speed test server response.")
        }
    }
}

enum StarlinkGeneratedServiceError: LocalizedError {
    case notImplemented(String)
    case connectionFailed(host: String, port: Int)
    case grpc(GRPCStatus)
    case wrapped(Error)
    case speedTestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented(let message):
            message
        case .connectionFailed(let host, let port):
            "Could not reach the Starlink dish at \(host):\(port). Make sure your iPhone is on Starlink Wi-Fi, approve Local Network access, and disable VPN/iCloud Private Relay for this test."
        case .grpc(let status):
            "Starlink gRPC error \(status.code): \(status.message ?? "No details")"
        case .wrapped(let error):
            error.localizedDescription
        case .speedTestFailed(let message):
            message
        }
    }
}
