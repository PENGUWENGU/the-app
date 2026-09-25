import SwiftUI
import UniformTypeIdentifiers
import UIKit

public struct SettingsView: View {
    @EnvironmentObject private var pairing: PairingStore
    @EnvironmentObject private var session: SpoofSession
    @Environment(\.dismiss) private var dismiss

    @State private var showImporter = false
    @State private var showPairOnDevice = false
    @State private var showNameEasterEgg = false
    @State private var tunnelIP = TunnelConfig.targetIP
    @State private var localDevVPNInstalled = LocalDevVPN.isInstalled
    @State private var copiedCSS = false
    @Environment(\.scenePhase) private var scenePhase

    private var supportsOnDevicePairing: Bool {
        if #available(iOS 27.0, *) { return true }
        return false
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // MARK: - Interface Appearance (Light / Dark Mode & CSS Variables)
                Section {
                    Picker("Appearance", selection: Binding(
                        get: { session.appearanceMode },
                        set: { newMode in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                ThemeStore.currentAppearance = newMode
                                session.appearanceMode = newMode
                            }
                        }
                    )) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

                    // CSS Theme Variables Disclosure
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(session.appearanceMode.cssVariables.sorted(by: { $0.key < $1.key }), id: \.key) { key, val in
                                HStack {
                                    Text(key)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    HStack(spacing: 6) {
                                        if val.hasPrefix("#") {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color(hex: val) ?? .clear)
                                                .frame(width: 14, height: 14)
                                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                                        }
                                        Text(val)
                                            .font(.caption2.monospaced().weight(.semibold))
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }

                            Button {
                                UIPasteboard.general.string = session.appearanceMode.cssVariablesString
                                copiedCSS = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedCSS = false
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: copiedCSS ? "checkmark" : "doc.on.doc")
                                    Text(copiedCSS ? "CSS Variables Copied!" : "Copy CSS Variables")
                                }
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(session.currentTheme.accentColor)
                            Text("Theme CSS Variables")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(session.appearanceMode.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Interface Appearance")
                } footer: {
                    Text("Toggle between Light and Dark interface mode or match the system appearance.")
                }

                // MARK: - Theme & Customization
                Section {
                    ForEach(AppTheme.allCases) { theme in
                        let isSelected = session.currentTheme == theme
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                ThemeStore.currentTheme = theme
                                session.currentTheme = theme
                            }
                        } label: {
                            HStack(spacing: 12) {
                                // Double color swatch ring
                                ZStack {
                                    Circle()
                                        .fill(theme.accentColor)
                                        .frame(width: 24, height: 24)
                                    Circle()
                                        .fill(theme.accentSecondaryColor)
                                        .frame(width: 12, height: 12)
                                }
                                .shadow(color: theme.accentColor.opacity(0.3), radius: 3)

                                Text(theme.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.headline)
                                        .foregroundStyle(theme.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Theme & Accent Colors")
                } footer: {
                    Text("Customizes map paths, joystick knob, active speed indicators, and buttons across Locus.")
                }

                // MARK: - Developer Pairing
                Section {
                    Label {
                        Text(pairing.hasPairingFile ? "RPPairing file installed" : "No pairing file")
                    } icon: {
                        Image(systemName: pairing.hasPairingFile ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(pairing.hasPairingFile ? LocusTheme.statusGood : LocusTheme.statusWarn)
                    }

                    if supportsOnDevicePairing {
                        Button {
                            showPairOnDevice = true
                        } label: {
                            Label("Pair on this iPhone", systemImage: "iphone.gen3.radiowaves.left.and.right")
                        }
                    }

                    Button("Import RPPairing file…") { showImporter = true }
                    Button("Paste RPPairing from clipboard") {
                        do {
                            try pairing.importPairingFromClipboard()
                        } catch {
                            session.lastError = error.localizedDescription
                        }
                    }
                    if pairing.hasPairingFile {
                        Button("Remove pairing file", role: .destructive) {
                            try? pairing.removePairing()
                        }
                    }
                } header: {
                    Text("Developer pairing")
                } footer: {
                    Text(supportsOnDevicePairing
                         ? "On iOS 27, use Pair on this iPhone — no computer. Locus advertises a pairable host; confirm the 6-digit code under Settings › Privacy & Security › Developer Mode › Pair with Host. On older iOS, import an RPPairing file from idevice_pair (not a SideStore lockdown .mobiledevicepairing)."
                         : "Import an RPPairing file from idevice_pair (not a SideStore lockdown .mobiledevicepairing). If the file picker fails (common in LiveContainer), enable Fix File Picker on the app, share the file into LiveContainer → Locus, or copy the plist and use Paste.")
                }

                // MARK: - Tunnel Config
                Section {
                    TextField("Device tunnel IP", text: $tunnelIP)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            TunnelConfig.setTargetIP(tunnelIP)
                        }
                    LabeledContent("Status") {
                        Text(LocalDevVPN.isConnected ? "Connected" : "Not connected")
                            .foregroundStyle(LocalDevVPN.isConnected ? LocusTheme.statusGood : LocusTheme.statusWarn)
                    }
                    Button("Save tunnel IP") {
                        TunnelConfig.setTargetIP(tunnelIP)
                    }
                    Button {
                        if localDevVPNInstalled {
                            LocalDevVPN.openInstalled()
                        } else {
                            LocalDevVPN.openAppStore()
                        }
                    } label: {
                        Label(
                            localDevVPNInstalled ? "Open LocalDevVPN" : "Get LocalDevVPN (App Store)",
                            systemImage: localDevVPNInstalled ? "lock.shield.fill" : "arrow.down.app.fill"
                        )
                    }
                } header: {
                    Text("Tunnel")
                } footer: {
                    Text("Connect LocalDevVPN before teleporting. Default tunnel IP is 10.7.0.1. Start a spoof on Wi‑Fi first; it can keep working on cellular afterward.")
                }

                // MARK: - Privacy & About
                Section("Privacy") {
                    Text("Fully on-device. Favorites, routes, and preferences stay in UserDefaults. No analytics, no accounts, nothing uploaded.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Engine", value: "idevice DVT location simulation")
                    Text("Locus is free and open source (MIT). Location injection uses the MIT-licensed idevice FFI.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        showNameEasterEgg = true
                    } label: {
                        Text("locus, n. — a place. From the Latin for where you are.")
                            .font(.footnote.italic())
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        TunnelConfig.setTargetIP(tunnelIP)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImporter) {
                PairingDocumentPicker(
                    onPick: { url in
                        showImporter = false
                        do {
                            try pairing.importPairing(from: url)
                        } catch {
                            session.lastError = error.localizedDescription
                        }
                    },
                    onCancel: { showImporter = false }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPairOnDevice) {
                PairOnDeviceView()
                    .environmentObject(pairing)
            }
            .fullScreenCover(isPresented: $showNameEasterEgg) {
                LocusEasterEggView()
            }
            .onAppear {
                localDevVPNInstalled = LocalDevVPN.isInstalled
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    localDevVPNInstalled = LocalDevVPN.isInstalled
                }
            }
        }
    }
}
