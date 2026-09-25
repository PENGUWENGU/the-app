import SwiftUI
import CoreLocation

/// Speed unit options for user input
public enum SpeedUnit: String, CaseIterable, Identifiable {
    case kmh = "km/h"
    case mph = "mph"
    case mps = "m/s"

    public var id: String { rawValue }

    /// Converts speed in current unit to meters per second (m/s)
    public func toMPS(_ value: Double) -> Double {
        switch self {
        case .kmh: return value / 3.6
        case .mph: return value * 0.44704
        case .mps: return value
        }
    }

    /// Converts meters per second (m/s) to current unit
    public func fromMPS(_ mps: Double) -> Double {
        switch self {
        case .kmh: return mps * 3.6
        case .mph: return mps / 0.44704
        case .mps: return mps
        }
    }
}

/// Speed preset button helper
public struct SpeedPreset: Identifiable {
    public let id: String
    public let name: String
    public let icon: String
    public let speedMPS: Double

    public static let standardPresets: [SpeedPreset] = [
        SpeedPreset(id: "walk", name: "Walk", icon: "figure.walk", speedMPS: 1.4),       // ~5 km/h
        SpeedPreset(id: "run", name: "Run", icon: "figure.run", speedMPS: 3.3),          // ~12 km/h
        SpeedPreset(id: "cycle", name: "Cycle", icon: "bicycle", speedMPS: 5.5),         // ~20 km/h
        SpeedPreset(id: "drive", name: "Drive", icon: "car.fill", speedMPS: 16.6)        // ~60 km/h
    ]
}

/// UI component that calculates and displays the estimated arrival time (ETA)
/// based on the distance of a selected route and a user-input speed.
public struct RouteETACalculatorView: View {
    public var distanceMeters: Double
    public var routeName: String?

    @State private var speedInput: String = "15.0"
    @State private var selectedUnit: SpeedUnit = .kmh
    @State private var currentTime = Date()

    public init(distanceMeters: Double, routeName: String? = nil) {
        self.distanceMeters = distanceMeters
        self.routeName = routeName
    }

    public init(coordinates: [CLLocationCoordinate2D], routeName: String? = nil) {
        self.distanceMeters = RouteBuilder.calculateTotalDistance(coordinates: coordinates)
        self.routeName = routeName
    }

    public init(route: SavedRoute) {
        self.distanceMeters = route.totalDistanceMeters
        self.routeName = route.name
    }

    /// Effective speed converted to meters per second
    private var effectiveSpeedMPS: Double {
        let raw = Double(speedInput.replacingOccurrences(of: ",", with: ".")) ?? 0
        return max(0.1, selectedUnit.toMPS(max(0.1, raw)))
    }

    /// Calculated route ETA result
    private var etaResult: RouteETAResult {
        let duration = RouteBuilder.calculateETA(distanceMeters: distanceMeters, speedMPS: effectiveSpeedMPS)
        let arrival = currentTime.addingTimeInterval(duration)
        return RouteETAResult(
            totalDistanceMeters: distanceMeters,
            durationSeconds: duration,
            formattedDuration: RouteBuilder.formatDuration(duration),
            estimatedArrivalDate: arrival
        )
    }

    private var formattedArrivalTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: etaResult.estimatedArrivalDate)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Route & Distance Info
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(LocusTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(routeName ?? "Route ETA Calculator")
                        .font(.headline.weight(.bold))
                    Text(etaResult.formattedDistance)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(LocusTheme.accent)
                }

                Spacer()

                // Unit Picker
                Picker("Unit", selection: $selectedUnit) {
                    ForEach(SpeedUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            // Speed Presets
            HStack(spacing: 8) {
                ForEach(SpeedPreset.standardPresets) { preset in
                    Button {
                        let converted = selectedUnit.fromMPS(preset.speedMPS)
                        speedInput = String(format: "%.1f", converted)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: preset.icon)
                            Text(preset.name)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Speed Input Field
            HStack(spacing: 12) {
                Label("Custom Speed", systemImage: "gauge.with.dots.needle.50percent")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    TextField("Speed", text: $speedInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospaced().weight(.bold))
                        .frame(width: 80)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text(selectedUnit.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // ETA Results Display
            HStack(spacing: 12) {
                // Travel Duration
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRAVEL TIME")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(etaResult.formattedDuration)
                        .font(.title3.monospaced().weight(.bold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Estimated Clock Arrival Time
                VStack(alignment: .leading, spacing: 4) {
                    Text("ESTIMATED ARRIVAL")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formattedArrivalTime)
                            .font(.title3.monospaced().weight(.bold))
                            .foregroundStyle(LocusTheme.accent)

                        Text("ETA")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(LocusTheme.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .locusGlass(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { date in
            currentTime = date
        }
    }
}
