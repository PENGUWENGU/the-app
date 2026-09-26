import SwiftUI
import CoreLocation

/// Dedicated Route Details screen featuring a D3.js line chart visualization of latitude and longitude
/// variations across the route's duration, accompanied by key route metrics, speed simulation,
/// coordinate boundaries, and direct spoofing playback controls.
public struct RouteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SpoofSession
    @EnvironmentObject private var pairing: PairingStore

    public var route: SavedRoute
    public var onLoadRoute: ((SavedRoute) -> Void)?
    public var onFollowRoute: ((SavedRoute) -> Void)?

    @State private var selectedSpeedMPS: Double = 1.4 // ~5 km/h (Walk default)
    @State private var selectedPresetId: String = "walk"
    @State private var showWaypointsList: Bool = false
    @State private var showExportShareSheet: Bool = false

    public init(
        route: SavedRoute,
        onLoadRoute: ((SavedRoute) -> Void)? = nil,
        onFollowRoute: ((SavedRoute) -> Void)? = nil
    ) {
        self.route = route
        self.onLoadRoute = onLoadRoute
        self.onFollowRoute = onFollowRoute
    }

    private var coordinates: [CLLocationCoordinate2D] {
        route.clCoordinates
    }

    private var lats: [Double] {
        route.waypoints.map(\.latitude)
    }

    private var lngs: [Double] {
        route.waypoints.map(\.longitude)
    }

    private var minLat: Double { lats.min() ?? 0 }
    private var maxLat: Double { lats.max() ?? 0 }
    private var minLng: Double { lngs.min() ?? 0 }
    private var maxLng: Double { lngs.max() ?? 0 }

    private var totalDurationSeconds: Double {
        if route.waypoints.count > 1,
           let firstTime = route.waypoints.first?.time,
           let lastTime = route.waypoints.last?.time,
           lastTime.timeIntervalSince(firstTime) > 0 {
            return lastTime.timeIntervalSince(firstTime)
        }
        return route.totalDistanceMeters / max(0.1, selectedSpeedMPS)
    }

    private var formattedDuration: String {
        let secs = Int(totalDurationSeconds)
        let hours = secs / 3600
        let minutes = (secs % 3600) / 60
        let remainingSecs = secs % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%02dm %02ds", minutes, remainingSecs)
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Route Header Card
                    headerCard

                    // Speed & Duration Presets
                    speedPresetSection

                    // Coordinate Bounds & Spatial Delta
                    spatialBoundsSection

                    // Waypoint Milestones Breakdown
                    waypointsSection

                    // Action Controls
                    actionsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Route Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if let gpxUrl = route.exportToGPXFile() {
                        ShareLink(item: gpxUrl) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "point.topleft.filled.down.to.point.bottomright.curvepath")
                    .font(.title)
                    .foregroundStyle(LocusTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(LocusTheme.accent.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Saved \(route.dateCreated.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()
                .overlay(Color.white.opacity(0.10))

            // Quick Stats Grid
            HStack(spacing: 0) {
                statColumn(
                    title: "DISTANCE",
                    value: route.formattedDistance,
                    systemImage: "figure.walk",
                    color: LocusTheme.accent
                )

                Divider()
                    .frame(height: 36)
                    .overlay(Color.white.opacity(0.10))

                statColumn(
                    title: "EST. DURATION",
                    value: formattedDuration,
                    systemImage: "timer",
                    color: Color(red: 0.22, green: 0.74, blue: 0.97)
                )

                Divider()
                    .frame(height: 36)
                    .overlay(Color.white.opacity(0.10))

                statColumn(
                    title: "WAYPOINTS",
                    value: "\(route.waypoints.count)",
                    systemImage: "mappin.and.ellipse",
                    color: Color(red: 0.66, green: 0.33, blue: 0.97)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func statColumn(title: String, value: String, systemImage: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(value)
                    .font(.subheadline.monospaced().weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Speed Presets
    private var speedPresetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Simulation Speed & Duration", systemImage: "gauge.with.needle")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.1f km/h", selectedSpeedMPS * 3.6))
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(LocusTheme.accent)
            }

            HStack(spacing: 8) {
                ForEach(SpeedPreset.standardPresets) { preset in
                    let isSelected = selectedPresetId == preset.id
                    Button {
                        selectedPresetId = preset.id
                        selectedSpeedMPS = preset.speedMPS
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: preset.icon)
                                .font(.caption)
                            Text(preset.name)
                                .font(.caption.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? LocusTheme.accent : Color.white.opacity(0.05))
                        )
                        .foregroundStyle(isSelected ? Color.black : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Spatial Bounds Section
    private var spatialBoundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Coordinate Range & Extent", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("START COORDINATE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        if let first = coordinates.first {
                            Text(String(format: "%.5f°, %.5f°", first.latitude, first.longitude))
                                .font(.caption.monospaced())
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("END COORDINATE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        if let last = coordinates.last {
                            Text(String(format: "%.5f°, %.5f°", last.latitude, last.longitude))
                                .font(.caption.monospaced())
                        }
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.06))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LATITUDE SPAN (ΔLat)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(red: 0.22, green: 0.74, blue: 0.97))
                        Text(String(format: "%.5f° → %.5f° (Δ %.5f°)", minLat, maxLat, abs(maxLat - minLat)))
                            .font(.caption.monospaced())
                    }
                    Spacer()
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LONGITUDE SPAN (ΔLng)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(red: 0.66, green: 0.33, blue: 0.97))
                        Text(String(format: "%.5f° → %.5f° (Δ %.5f°)", minLng, maxLng, abs(maxLng - minLng)))
                            .font(.caption.monospaced())
                    }
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Waypoints List
    private var waypointsSection: some View {
        DisclosureGroup(
            isExpanded: $showWaypointsList,
            content: {
                VStack(spacing: 6) {
                    ForEach(Array(route.waypoints.prefix(30).enumerated()), id: \.offset) { index, wp in
                        HStack {
                            Text("#\(index + 1)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(width: 32, alignment: .leading)

                            Text(String(format: "%.5f, %.5f", wp.latitude, wp.longitude))
                                .font(.caption.monospaced())

                            Spacer()

                            if let elev = wp.elevation {
                                Text(String(format: "%.0f m", elev))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                    }

                    if route.waypoints.count > 30 {
                        Text("… and \(route.waypoints.count - 30) more waypoints")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 8)
            },
            label: {
                HStack {
                    Label("Waypoints Breakdown", systemImage: "list.bullet")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(route.waypoints.count) pts")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        )
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Actions
    private var actionsSection: some View {
        VStack(spacing: 10) {
            // Follow / Spoof Route Button
            Button {
                if let onFollow = onFollowRoute {
                    onFollow(route)
                } else {
                    session.followRoute(route.clCoordinates, pairing: pairing)
                }
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Follow / Simulate Route")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LocusTheme.statusGood)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            // Load onto Map Button
            Button {
                onLoadRoute?(route)
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "map")
                    Text("Load onto Map")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LocusTheme.accent)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
