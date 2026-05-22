import SwiftUI

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.07, blue: 0.16),
                Color(red: 0.10, green: 0.11, blue: 0.30),
                Color(red: 0.02, green: 0.22, blue: 0.27)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            RadialGradient(
                colors: [.cyan.opacity(0.24), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }
}

struct Panel<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(unit)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct StatusPill: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.color)
                .frame(width: 8, height: 8)
            Text(state.rawValue)
                .font(.caption.weight(.bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.16), in: Capsule())
    }
}

struct OrbitalGauge: View {
    let value: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 12)

            Circle()
                .trim(from: 0, to: max(0, min(value, 1)))
                .stroke(
                    AngularGradient(colors: [.white, .cyan, .mint, .white], center: .center),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(value * 100))")
                    .font(.system(.title, design: .rounded, weight: .black))
                Text("Signal")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
        .frame(width: 118, height: 118)
    }
}

struct MetricLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .fontWeight(.bold)
        }
        .font(.subheadline)
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 18)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

extension ConnectionState {
    var color: Color {
        switch self {
        case .online: .mint
        case .searching: .orange
        case .offline: .red
        }
    }
}

extension SignalStatus {
    var color: Color {
        switch self {
        case .healthy: .green
        case .warning: .orange
        case .critical: .red
        }
    }
}

extension TimeInterval {
    var formattedUptime: String {
        let days = Int(self) / 86_400
        let hours = (Int(self) % 86_400) / 3_600
        return "\(days)d \(hours)h"
    }
}
