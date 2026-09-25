import SwiftUI
import NetworkExtension

public struct RootView: View {
    @EnvironmentObject private var session: SpoofSession
    @EnvironmentObject private var pairing: PairingStore
    @State private var showSettings = false
    @State private var showPlaces = false

    public init() {}

    public var body: some View {
        // Bottom chrome is a sibling overlay aligned to the bottom — no full-screen
        // Spacer layer that can steal / pass map taps through the tray.
        ZStack(alignment: .bottom) {
            MapHomeView()

            BottomControlsView(
                showSettings: $showSettings,
                showPlaces: $showPlaces
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showPlaces) {
            PlacesView()
        }
        .alert("Locus", isPresented: Binding(
            get: { session.lastError != nil },
            set: { if !$0 { session.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { session.lastError = nil }
        } message: {
            Text(session.lastError ?? "")
        }
    }
}

public struct StatusBarView: View {
    @EnvironmentObject private var session: SpoofSession
    @Environment(\.scenePhase) private var scenePhase

    @State private var tunnelConnected = LocalDevVPN.isConnected

    public init() {}

    private enum Display {
        case notSpoofing
        case connectVPN
        case status(String)
    }

    private var display: Display {
        if session.isRouteActive {
            return .status("Route • \(session.formattedETA)")
        }
        switch session.status {
        case .idle:
            return tunnelConnected ? .notSpoofing : .connectVPN
        case .connecting:
            return .status("Connecting…")
        case .active:
            return .status("Spoofing")
        case .reconnecting:
            return .status("Reconnecting…")
        case .dropped(let reason):
            return .status(reason.isEmpty ? "Disconnected" : "Disconnected — \(reason)")
        }
    }

    private var color: Color {
        if session.isRouteActive {
            return LocusTheme.accent
        }
        switch display {
        case .notSpoofing:
            return Color.primary.opacity(0.55)
        case .connectVPN:
            return LocusTheme.statusWarn
        case .status:
            switch session.status {
            case .active: return LocusTheme.statusGood
            case .connecting, .reconnecting: return LocusTheme.statusWarn
            case .dropped: return LocusTheme.statusBad
            case .idle: return Color.primary.opacity(0.55)
            }
        }
    }

    private var title: String {
        switch display {
        case .notSpoofing: return "Not Spoofing"
        case .connectVPN: return "Connect LocalDevVPN"
        case .status(let text): return text
        }
    }

    public var body: some View {
        Group {
            if case .connectVPN = display {
                Button(action: LocalDevVPN.openOrInstall) {
                    statusContent
                }
                .buttonStyle(.plain)
            } else {
                statusContent
            }
        }
        .onAppear { refreshTunnel() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshTunnel() }
        }
        .onChange(of: session.status) { _, _ in
            refreshTunnel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NEVPNStatusDidChange)) { _ in
            refreshTunnel()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                refreshTunnel()
            }
        }
    }

    private var statusContent: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.7), radius: 4)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if case .connectVPN = display {
                Image(systemName: "lock.shield.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LocusTheme.accent)
            } else if session.isRouteActive {
                Text(session.formattedDistanceRemaining)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(LocusTheme.accent)
            } else if case .active = session.status, let sim = session.simulated {
                Text(String(format: "%.4f, %.4f", sim.latitude, sim.longitude))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .locusGlass(.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func refreshTunnel() {
        tunnelConnected = LocalDevVPN.isConnected
    }
}

public struct BottomControlsView: View {
    @EnvironmentObject private var session: SpoofSession
    @EnvironmentObject private var pairing: PairingStore
    @Binding public var showSettings: Bool
    @Binding public var showPlaces: Bool

    private let trayShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    public init(showSettings: Binding<Bool>, showPlaces: Binding<Bool>) {
        self._showSettings = showSettings
        self._showPlaces = showPlaces
    }

    public var body: some View {
        VStack(spacing: 12) {
            if session.joystickActive {
                JoystickPad { vector in
                    session.updateJoystick(vector: vector)
                }
                .frame(width: 148, height: 148)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 8) {
                ForEach(TravelMode.allCases) { mode in
                    let selected = session.travelMode == mode
                    Button {
                        session.travelMode = mode
                    } label: {
                        Image(systemName: mode.icon)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(selected ? .black : .primary)
                            .frame(width: 44, height: 40)
                            .background(
                                Capsule().fill(selected ? LocusTheme.accent : Color.primary.opacity(0.08))
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                SpeedChip()
            }

            HStack(spacing: 10) {
                trayIcon("gearshape.fill") { showSettings = true }
                trayIcon("star.fill") { showPlaces = true }

                Button {
                    if session.joystickActive {
                        session.stopJoystick()
                    } else {
                        session.startJoystick(pairing: pairing)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "dot.circle.and.hand.point.up.left.fill")
                        Text(session.joystickActive ? "On" : "Joy")
                            .lineLimit(1)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(session.joystickActive ? .black : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(session.joystickActive ? LocusTheme.accentSecondary : Color.primary.opacity(0.08))
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)

                if session.isRouteActive {
                    Button {
                        session.stopRoute()
                    } label: {
                        Text("End Route")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 84)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                            .background(Capsule().fill(LocusTheme.danger))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if session.isSpoofing {
                    Button {
                        session.stop(pairing: pairing)
                    } label: {
                        Text("Stop")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 72)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                            .background(Capsule().fill(LocusTheme.danger))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        guard let pin = session.pin else {
                            session.lastError = "Tap the map to drop a pin first."
                            return
                        }
                        session.teleport(to: pin, pairing: pairing)
                    } label: {
                        Text("Teleport")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(minWidth: 96)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 10)
                            .background(Capsule().fill(LocusTheme.accent))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(session.isBusy)
                }
            }
        }
        .padding(14)
        .locusGlass(.regular, in: trayShape)
        .contentShape(trayShape)
    }

    private func trayIcon(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.primary.opacity(0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Compact control showing the current effective movement speed, and letting the user
/// type in a custom one. Lives in the always-visible mode-picker row, so it stays
/// reachable even while the joystick is active.
public struct SpeedChip: View {
    @EnvironmentObject private var session: SpoofSession
    @State private var showEditor = false
    @State private var speedText = ""
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        Button {
            speedText = Self.formatter.string(from: NSNumber(value: session.currentSpeedMPS)) ?? ""
            errorMessage = nil
            showEditor = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                Text(speedLabel)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(session.customSpeedMPS != nil ? .black : .primary)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(
                Capsule().fill(session.customSpeedMPS != nil ? LocusTheme.accent : Color.primary.opacity(0.08))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showEditor) {
            speedEditor
                .presentationCompactAdaptation(.popover)
        }
    }

    private var speedLabel: String {
        (Self.formatter.string(from: NSNumber(value: session.currentSpeedMPS)) ?? "0") + " m/s"
    }

    private var speedEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Custom speed")
                .font(.headline)
            Text("Applies to both the joystick and route/GPX playback, in meters per second.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField("e.g. 5.0", text: $speedText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Text("m/s")
                    .foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(LocusTheme.danger)
            }
            HStack {
                Button("Use preset") {
                    session.clearCustomSpeed()
                    errorMessage = nil
                    showEditor = false
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Set") {
                    if session.setCustomSpeed(fromText: speedText) {
                        errorMessage = nil
                        showEditor = false
                    } else {
                        errorMessage = "Enter a number greater than 0 (e.g. 2.5)."
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 260)
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

public struct PlacesView: View {
    @EnvironmentObject private var session: SpoofSession
    @EnvironmentObject private var pairing: PairingStore
    @Environment(\.dismiss) private var dismiss

    @State private var placeToRename: SavedPlace?
    @State private var renameText = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Favorites") {
                    if session.favorites.isEmpty {
                        Text("Star a pin from the map to save it.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(session.favorites) { place in
                        placeButton(place)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    session.removeFavorite(place)
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                                Button {
                                    placeToRename = place
                                    renameText = place.name
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                }

                Section("Recents") {
                    if session.recents.isEmpty {
                        Text("Teleported locations appear here.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(session.recents) { place in
                        placeButton(place)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    session.removeRecent(place)
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Places")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename Place", isPresented: Binding(
                get: { placeToRename != nil },
                set: { if !$0 { placeToRename = nil } }
            )) {
                TextField("Place Name", text: $renameText)
                Button("Save") {
                    if let place = placeToRename {
                        session.renameFavorite(place, to: renameText)
                    }
                    placeToRename = nil
                }
                Button("Cancel", role: .cancel) {
                    placeToRename = nil
                }
            }
        }
    }

    private func placeButton(_ place: SavedPlace) -> some View {
        Button {
            session.teleport(to: place.coordinate, pairing: pairing)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(String(format: "%.4f, %.4f", place.latitude, place.longitude))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
