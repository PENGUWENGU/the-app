import CoreLocation
import SwiftUI

public struct RoutePlannerSheet: View {
    @Binding public var start: CLLocationCoordinate2D?
    @Binding public var end: CLLocationCoordinate2D?
    @Binding public var isRouting: Bool
    public var onBuild: () -> Void
    public var onPlay: () -> Void
    public var onImportGPX: () -> Void
    public var onExportGPX: () -> Void
    public var onUseDrawn: () -> Void
    public var onSelectSavedRoute: ((SavedRoute) -> Void)?

    @EnvironmentObject private var session: SpoofSession
    @Environment(\.dismiss) private var dismiss

    @State private var showSaveRouteAlert = false
    @State private var newRouteName = ""
    @State private var routeToRename: SavedRoute?
    @State private var renameRouteText = ""

    public init(
        start: Binding<CLLocationCoordinate2D?>,
        end: Binding<CLLocationCoordinate2D?>,
        isRouting: Binding<Bool>,
        onBuild: @escaping () -> Void,
        onPlay: @escaping () -> Void,
        onImportGPX: @escaping () -> Void,
        onExportGPX: @escaping () -> Void,
        onUseDrawn: @escaping () -> Void,
        onSelectSavedRoute: ((SavedRoute) -> Void)? = nil
    ) {
        self._start = start
        self._end = end
        self._isRouting = isRouting
        self.onBuild = onBuild
        self.onPlay = onPlay
        self.onImportGPX = onImportGPX
        self.onExportGPX = onExportGPX
        self.onUseDrawn = onUseDrawn
        self.onSelectSavedRoute = onSelectSavedRoute
    }

    public var body: some View {
        NavigationStack {
            List {
                // Live Route & ETA Status Banner when a route is actively playing
                if session.isRouteActive {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Route in Progress", systemImage: "figure.walk.motion")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(LocusTheme.accent)
                                Spacer()
                                Button("Stop Route", role: .destructive) {
                                    session.stopRoute()
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.bordered)
                                .tint(LocusTheme.danger)
                            }

                            ProgressView(value: session.routeProgress)
                                .tint(LocusTheme.accent)

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ETA Remaining")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(session.formattedETA.isEmpty ? "Calculating…" : session.formattedETA)
                                        .font(.subheadline.monospaced().weight(.semibold))
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Distance Left")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(session.formattedDistanceRemaining)
                                        .font(.subheadline.monospaced().weight(.semibold))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Active Simulation")
                    }
                }

                Section("Road route") {
                    Button("Use current pin / spoof as start") {
                        start = session.simulated ?? session.pin
                    }
                    Button("Use current pin as end") {
                        end = session.pin
                    }
                    LabeledContent("Start") {
                        Text(coordText(start)).font(.caption.monospaced())
                    }
                    LabeledContent("End") {
                        Text(coordText(end)).font(.caption.monospaced())
                    }
                    Button {
                        onBuild()
                    } label: {
                        if isRouting {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Calculating route…")
                            }
                        } else {
                            Label("Build walk/drive route on roads", systemImage: "road.lanes")
                        }
                    }
                    .disabled(isRouting || start == nil || end == nil)
                }

                Section("Play / draw / GPX") {
                    Button {
                        onUseDrawn()
                    } label: {
                        Label("Use drawn path from map", systemImage: "pencil.tip")
                    }

                    Button(action: onPlay) {
                        Label("Follow route", systemImage: "play.fill")
                            .foregroundStyle(LocusTheme.statusGood)
                    }

                    Button {
                        newRouteName = "Route \(session.savedRoutes.count + 1)"
                        showSaveRouteAlert = true
                    } label: {
                        Label("Save current route", systemImage: "bookmark.fill")
                    }

                    Button(action: onImportGPX) {
                        Label("Import GPX file", systemImage: "square.and.arrow.down")
                    }

                    Button(action: onExportGPX) {
                        Label("Export GPX file", systemImage: "square.and.arrow.up")
                    }
                }

                // MARK: - Saved Routes Library
                if !session.savedRoutes.isEmpty {
                    Section("Saved Routes") {
                        ForEach(session.savedRoutes) { route in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(route.name)
                                        .font(.subheadline.weight(.semibold))
                                    HStack(spacing: 8) {
                                        Text(route.formattedDistance)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(LocusTheme.accent)
                                        Text("•")
                                            .foregroundStyle(.secondary)
                                        Text("\(route.coordinates.count) points")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Button("Load") {
                                    onSelectSavedRoute?(route)
                                    dismiss()
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.borderedProminent)
                                .tint(LocusTheme.accent)
                                .foregroundStyle(.black)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    session.removeSavedRoute(route)
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }

                                Button {
                                    routeToRename = route
                                    renameRouteText = route.name
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }

                Section {
                    Text("Routes follow Apple Maps roads/footpaths for the selected travel mode. Live ETA and speed calculations update automatically in real-time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Routes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Save Route", isPresented: $showSaveRouteAlert) {
                TextField("Route Name", text: $newRouteName)
                Button("Save") {
                    NotificationCenter.default.post(
                        name: .locusSaveCurrentRouteRequest,
                        object: newRouteName
                    )
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for this route to save it to your library.")
            }
            .alert("Rename Route", isPresented: Binding(
                get: { routeToRename != nil },
                set: { if !$0 { routeToRename = nil } }
            )) {
                TextField("Route Name", text: $renameRouteText)
                Button("Save") {
                    if let route = routeToRename {
                        session.renameSavedRoute(route, to: renameRouteText)
                    }
                    routeToRename = nil
                }
                Button("Cancel", role: .cancel) {
                    routeToRename = nil
                }
            }
        }
    }

    private func coordText(_ c: CLLocationCoordinate2D?) -> String {
        guard let c else { return "—" }
        return String(format: "%.5f, %.5f", c.latitude, c.longitude)
    }
}

extension Notification.Name {
    public static let locusSaveCurrentRouteRequest = Notification.Name("locus.saveCurrentRouteRequest")
}
