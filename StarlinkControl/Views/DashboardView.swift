import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        if let snapshot = viewModel.snapshot {
                            HeroStatusCard(snapshot: snapshot)
                            QuickActionsView(isBusy: viewModel.isPerformingAction, perform: viewModel.perform)
                            MetricsGrid(stats: snapshot.network)
                            WiFiPanel(viewModel: viewModel, wifi: snapshot.wifi)
                            DishConfigurationPanel(viewModel: viewModel, dish: snapshot.dish)
                            TelemetryPanel(signals: snapshot.telemetry)
                            AccountPanel(account: snapshot.account, dish: snapshot.dish)
                        } else {
                            LoadingPanel()
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await viewModel.refresh()
                }

                if viewModel.isSideMenuPresented {
                    Color.black.opacity(0.42)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                viewModel.isSideMenuPresented = false
                            }
                        }
                        .transition(.opacity)

                    HStack(spacing: 0) {
                        StarlinkSideMenu(viewModel: viewModel)
                            .frame(width: min(UIScreen.main.bounds.width * 0.84, 360))
                            .transition(.move(edge: .leading).combined(with: .opacity))

                        Spacer(minLength: 0)
                    }
                    .ignoresSafeArea(edges: .vertical)
                }
            }
            .navigationTitle("Starlink")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            viewModel.isSideMenuPresented = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel("Open menu")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.perform(.refresh)
                    } label: {
                        Image(systemName: viewModel.isLoading ? "hourglass" : "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh")
                }
            }
            .toolbar(viewModel.isSideMenuPresented ? .hidden : .visible, for: .navigationBar)
        }
        .tint(.white)
        .task {
            if viewModel.snapshot == nil {
                viewModel.load()
            }
        }
        .alert(item: $viewModel.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

private struct StarlinkSideMenu: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.17),
                    Color(red: 0.11, green: 0.11, blue: 0.28),
                    Color(red: 0.02, green: 0.20, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Account")
                                .font(.system(.largeTitle, design: .rounded, weight: .black))
                            Text(viewModel.isRemoteAuthenticated ? "Remote API linked" : "Paste Starlink cookie")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.68))
                        }

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                viewModel.isSideMenuPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline.weight(.bold))
                                .frame(width: 38, height: 38)
                                .background(.white.opacity(0.12), in: Circle())
                        }
                        .accessibilityLabel("Close menu")
                    }

                    if let profile = viewModel.remoteProfile {
                        RemoteProfileCard(profile: profile)
                    } else {
                        RemoteEmptyCard()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Browser Cookie", systemImage: "key.horizontal.fill")
                            .font(.headline.weight(.bold))

                        TextEditor(text: $viewModel.starlinkCookieInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.black)
                            .tint(.blue)
                            .frame(minHeight: 150)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .environment(\.colorScheme, .light)

                        Text("Accepts either a Cookie header like name=value; name2=value2, or exported cookie JSON from a browser extension.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    VStack(spacing: 10) {
                        Button {
                            viewModel.saveRemoteCookie()
                        } label: {
                            Label(viewModel.isAuthenticatingRemote ? "Connecting" : "Connect Account", systemImage: "checkmark.shield.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .disabled(viewModel.isAuthenticatingRemote)

                        Button(role: .destructive) {
                            viewModel.clearRemoteCookie()
                        } label: {
                            Label("Remove Saved Cookie", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        CapabilityRow(title: "Account, service line, H3/location", isAvailable: viewModel.isRemoteAuthenticated)
                        CapabilityRow(title: "Local dish telemetry", isAvailable: true)
                        CapabilityRow(title: "Router Wi-Fi admin calls", isAvailable: viewModel.isRemoteAuthenticated)
                    }
                    .padding(.top, 4)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.top, 54)
                .padding(.bottom, 34)
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 22, x: 8)
    }
}

private struct RemoteProfileCard: View {
    let profile: RemoteStarlinkProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.mint)
                Spacer()
            }

            RemoteDetailRow(title: "Name", value: profile.accountName)
            RemoteDetailRow(title: "Email", value: profile.email)
            RemoteDetailRow(title: "Service", value: profile.serviceLine)
            RemoteDetailRow(title: "Dish", value: profile.dishID)
            RemoteDetailRow(title: "Router", value: profile.routerID)
        }
        .padding(16)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct RemoteDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RemoteEmptyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Remote API not connected", systemImage: "exclamationmark.lock.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.orange)
            Text("Local Starlink data still works. Connect your account to unlock customer, service line, router, and account location data.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(16)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct CapabilityRow: View {
    let title: String
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isAvailable ? .mint : .white.opacity(0.36))
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(isAvailable ? 0.9 : 0.55))
        }
    }
}

private struct HeroStatusCard: View {
    let snapshot: StarlinkSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.dish.name)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(snapshot.account.planName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                StatusPill(state: snapshot.dish.state)
            }

            HStack(spacing: 22) {
                OrbitalGauge(value: 1 - min(snapshot.dish.obstructionPercent / 100, 1))

                VStack(alignment: .leading, spacing: 12) {
                    MetricLine(title: "Latency", value: "\(Int(snapshot.network.latencyMs)) ms")
                    MetricLine(title: "Clients", value: "\(snapshot.wifi.connectedClients)")
                    MetricLine(title: "Uptime", value: snapshot.dish.uptime.formattedUptime)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Obstruction \(snapshot.dish.obstructionPercent, specifier: "%.1f")% | \(snapshot.dish.location.h3Cell)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(
            LinearGradient(
                colors: [.indigo, .purple, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .indigo.opacity(0.28), radius: 24, y: 14)
    }
}

private struct QuickActionsView: View {
    let isBusy: Bool
    let perform: (QuickAction) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(QuickAction.allCases) { action in
                Button {
                    perform(action)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: action.symbolName)
                            .font(.system(size: 19, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.16), in: Circle())
                        Text(action.rawValue)
                            .font(.caption2.weight(.bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 86)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(isBusy)
            }
        }
    }
}

private struct MetricsGrid: View {
    let stats: NetworkStats

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(title: "Download", value: "\(Int(stats.downloadMbps))", unit: "Mbps", symbol: "arrow.down.circle.fill", tint: .cyan)
            MetricCard(title: "Upload", value: "\(Int(stats.uploadMbps))", unit: "Mbps", symbol: "arrow.up.circle.fill", tint: .mint)
            MetricCard(title: "Latency", value: "\(Int(stats.latencyMs))", unit: "ms", symbol: "waveform.path.ecg", tint: .orange)
            MetricCard(title: "Packet Loss", value: String(format: "%.1f", stats.packetLoss), unit: "%", symbol: "point.3.connected.trianglepath.dotted", tint: .pink)
        }
    }
}

private struct WiFiPanel: View {
    @ObservedObject var viewModel: DashboardViewModel
    let wifi: WiFiStatus

    var body: some View {
        Panel(title: "Wi-Fi", symbol: "wifi") {
            VStack(spacing: 14) {
                TextField("Network name", text: $viewModel.wifiSSID)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)

                SecureField("New password optional", text: $viewModel.wifiPassword)
                    .textFieldStyle(.roundedBorder)

                Toggle("Hide SSID", isOn: $viewModel.isWiFiHidden)
                Toggle("Bypass mode", isOn: $viewModel.isBypassModeEnabled)

                HStack {
                    Label("\(wifi.connectedClients) connected", systemImage: "person.2.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Save") {
                        viewModel.saveWiFi()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
            }
        }
    }
}

private struct DishConfigurationPanel: View {
    @ObservedObject var viewModel: DashboardViewModel
    let dish: DishStatus

    var body: some View {
        Panel(title: "Dish Configuration", symbol: "antenna.radiowaves.left.and.right") {
            VStack(spacing: 14) {
                Picker("Snow melt", selection: $viewModel.selectedSnowMeltMode) {
                    ForEach(SnowMeltMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Power saving", isOn: $viewModel.isPowerSaveEnabled)

                HStack {
                    Text("Serial \(dish.serialNumber)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer()

                    Button("Apply") {
                        viewModel.saveDishSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
            }
        }
    }
}

private struct TelemetryPanel: View {
    let signals: [TelemetrySignal]

    var body: some View {
        Panel(title: "Telemetry", symbol: "sensor.tag.radiowaves.forward") {
            VStack(spacing: 10) {
                ForEach(signals) { signal in
                    HStack {
                        Circle()
                            .fill(signal.status.color)
                            .frame(width: 10, height: 10)

                        Text(signal.title)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Text(signal.value)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(signal.status.color)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct AccountPanel: View {
    let account: StarlinkAccount
    let dish: DishStatus

    private var formattedLocation: String {
        if dish.location.latitude == 0, dish.location.longitude == 0 {
            return "Unavailable locally"
        }

        return String(format: "%.4f, %.4f", dish.location.latitude, dish.location.longitude)
    }

    private var isLocalOnlyAccount: Bool {
        account.email == "Requires Starlink login"
    }

    var body: some View {
        Panel(title: "Account", symbol: "person.crop.circle") {
            VStack(spacing: 12) {
                DetailRow(title: isLocalOnlyAccount ? "Customer" : "Customer", value: account.customerName)
                DetailRow(title: isLocalOnlyAccount ? "Profile" : "Email", value: account.email)
                DetailRow(title: isLocalOnlyAccount ? "Dish ID" : "Service line", value: account.serviceLine)
                DetailRow(title: "Location", value: formattedLocation)
            }
        }
    }
}

private struct LoadingPanel: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
            Text("Contacting Starlink")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
