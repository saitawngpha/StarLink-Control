import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var snapshot: StarlinkSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var isPerformingAction = false
    @Published var alert: AppAlert?
    @Published var wifiSSID = ""
    @Published var wifiPassword = ""
    @Published var isWiFiHidden = false
    @Published var isBypassModeEnabled = false
    @Published var selectedSnowMeltMode: SnowMeltMode = .automatic
    @Published var isPowerSaveEnabled = false
    @Published var isSideMenuPresented = false
    @Published var starlinkCookieInput = ""
    @Published private(set) var remoteProfile: RemoteStarlinkProfile?
    @Published private(set) var isRemoteAuthenticated = false
    @Published private(set) var isAuthenticatingRemote = false

    private let service: StarlinkServicing
    private let remoteClient: StarlinkRemoteClient
    private let cookieStore: StarlinkCookieStore

    init(
        service: StarlinkServicing,
        remoteClient: StarlinkRemoteClient = StarlinkRemoteClient(),
        cookieStore: StarlinkCookieStore = StarlinkCookieStore()
    ) {
        self.service = service
        self.remoteClient = remoteClient
        self.cookieStore = cookieStore
    }

    func load() {
        Task {
            await loadRemoteSession()
            await refresh()
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let freshSnapshot = try await service.fetchSnapshot()
            apply(freshSnapshot)
        } catch {
            alert = AppAlert(title: "Refresh failed", message: error.localizedDescription)
        }
    }

    func perform(_ action: QuickAction) {
        Task {
            isPerformingAction = true
            defer { isPerformingAction = false }

            do {
                switch action {
                case .refresh:
                    await refresh()
                case .reboot:
                    try await service.rebootDish()
                    await refresh()
                    alert = AppAlert(title: "Dish rebooting", message: "Starlink is restarting and will reconnect shortly.")
                case .stow:
                    try await service.stowDish()
                    await refresh()
                    alert = AppAlert(title: "Dish stowed", message: "The dish has moved into a safe position.")
                case .speedTest:
                    let stats = try await service.runSpeedTest()
                    snapshot?.network = stats
                    alert = AppAlert(title: "Speed test complete", message: "\(Int(stats.downloadMbps)) Mbps down, \(Int(stats.uploadMbps)) Mbps up.")
                }
            } catch {
                alert = AppAlert(title: "\(action.rawValue) failed", message: error.localizedDescription)
            }
        }
    }

    func saveWiFi() {
        Task {
            isPerformingAction = true
            defer { isPerformingAction = false }

            do {
                let updated = try await service.updateWiFi(
                    ssid: wifiSSID,
                    password: wifiPassword.isEmpty ? nil : wifiPassword,
                    isHidden: isWiFiHidden,
                    bypassModeEnabled: isBypassModeEnabled
                )
                snapshot?.wifi = updated
                alert = AppAlert(title: "Wi-Fi updated", message: "\(updated.ssid) is ready.")
            } catch {
                alert = AppAlert(title: "Wi-Fi update failed", message: error.localizedDescription)
            }
        }
    }

    func saveDishSettings() {
        Task {
            isPerformingAction = true
            defer { isPerformingAction = false }

            do {
                var updatedDish = try await service.setSnowMeltMode(selectedSnowMeltMode)
                updatedDish = try await service.setPowerSaveEnabled(isPowerSaveEnabled)
                snapshot?.dish = updatedDish
                alert = AppAlert(title: "Dish settings saved", message: "Configuration changes were applied.")
            } catch {
                alert = AppAlert(title: "Settings update failed", message: error.localizedDescription)
            }
        }
    }

    func saveRemoteCookie() {
        Task {
            isAuthenticatingRemote = true
            defer { isAuthenticatingRemote = false }

            do {
                let result = try await remoteClient.loadProfile(cookieInput: starlinkCookieInput)
                try cookieStore.save(result.refreshedCookie)
                remoteProfile = result.profile
                isRemoteAuthenticated = true
                applyRemoteProfile(result.profile)
                alert = AppAlert(title: "Starlink account connected", message: "\(result.profile.accountName) is linked.")
            } catch {
                alert = AppAlert(title: "Starlink login failed", message: error.localizedDescription)
            }
        }
    }

    func clearRemoteCookie() {
        do {
            try cookieStore.clear()
            starlinkCookieInput = ""
            remoteProfile = nil
            isRemoteAuthenticated = false
            alert = AppAlert(title: "Starlink account removed", message: "The saved browser cookie was deleted from Keychain.")
        } catch {
            alert = AppAlert(title: "Could not remove account", message: error.localizedDescription)
        }
    }

    func loadRemoteSession() async {
        do {
            guard let cookie = try cookieStore.load(), cookie.isEmpty == false else {
                return
            }

            let result = try await remoteClient.loadProfile(cookieInput: cookie)
            try cookieStore.save(result.refreshedCookie)
            remoteProfile = result.profile
            isRemoteAuthenticated = true
            starlinkCookieInput = ""
            applyRemoteProfile(result.profile)
        } catch {
            isRemoteAuthenticated = false
        }
    }

    private func apply(_ snapshot: StarlinkSnapshot) {
        var nextSnapshot = snapshot
        if let remoteProfile {
            nextSnapshot = merged(snapshot: nextSnapshot, remoteProfile: remoteProfile)
        }

        self.snapshot = nextSnapshot
        wifiSSID = snapshot.wifi.ssid
        isWiFiHidden = snapshot.wifi.isHidden
        isBypassModeEnabled = snapshot.wifi.bypassModeEnabled
        selectedSnowMeltMode = snapshot.dish.snowMeltMode
        isPowerSaveEnabled = snapshot.dish.powerSaveEnabled
    }

    private func applyRemoteProfile(_ profile: RemoteStarlinkProfile) {
        guard let snapshot else {
            return
        }

        self.snapshot = merged(snapshot: snapshot, remoteProfile: profile)
    }

    private func merged(snapshot: StarlinkSnapshot, remoteProfile: RemoteStarlinkProfile) -> StarlinkSnapshot {
        var merged = snapshot
        merged.account = StarlinkAccount(
            customerName: remoteProfile.accountName,
            email: remoteProfile.email,
            serviceLine: remoteProfile.serviceLine,
            planName: remoteProfile.planName
        )
        merged.dish.location = DishLocation(
            latitude: remoteProfile.latitude,
            longitude: remoteProfile.longitude,
            h3Cell: remoteProfile.address
        )

        if merged.dish.serialNumber == "Unknown" {
            merged.dish.serialNumber = remoteProfile.dishID
        }

        return merged
    }
}

struct AppAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}
