import CoreLocation
import Foundation
import MapKit
import UIKit
import UserNotifications

// TravelMode, SpeedInput, and SpeedPreference live in TravelMode.swift so the GPX/route
// sampling code (RouteBuilder.swift) and the speed-validation logic can be unit tested
// without pulling in this file's UIKit/idevice-linked dependencies.

public enum SpoofStatus: Equatable {
    case idle
    case connecting
    case active
    case reconnecting
    case dropped(String)

    public var label: String {
        switch self {
        case .idle: return "Not Spoofing"
        case .connecting: return "Starting…"
        case .active: return "Spoofing"
        case .reconnecting: return "Reconnecting…"
        case .dropped: return "Interrupted"
        }
    }

    public var isDropped: Bool {
        if case .dropped = self { return true }
        return false
    }
}

@MainActor
public final class SpoofSession: ObservableObject {
    @Published public var status: SpoofStatus = .idle
    @Published public var pin: CLLocationCoordinate2D?
    @Published public var simulated: CLLocationCoordinate2D?
    @Published public var travelMode: TravelMode = .walk
    /// Non-nil when the user has entered a custom speed to use instead of the selected
    /// travel mode's preset. This is the ONLY other input to movement speed besides
    /// `travelMode` — see `currentSpeedMPS`, the single place that resolves the two.
    @Published public var customSpeedMPS: Double?
    @Published public var mapStyleIndex: Int = 0
    @Published public var lastError: String?
    @Published public var isBusy = false
    @Published public var joystickActive = false

    @Published public var favorites: [SavedPlace] = []
    @Published public var recents: [SavedPlace] = []
    @Published public var savedRoutes: [SavedRoute] = []

    // MARK: - Route Simulation & ETA tracking
    @Published public var isRouteActive: Bool = false
    @Published public var activeRouteCoordinates: [CLLocationCoordinate2D] = []
    @Published public var routeProgress: Double = 0.0 // 0.0 ... 1.0
    @Published public var routeDistanceRemainingMeters: CLLocationDistance = 0
    @Published public var routeTimeRemainingSeconds: TimeInterval = 0
    @Published public var routeTotalDistanceMeters: CLLocationDistance = 0
    @Published public var currentTheme: AppTheme = ThemeStore.currentTheme
    @Published public var appearanceMode: AppearanceMode = ThemeStore.currentAppearance

    private var resendTimer: Timer?
    private var healthTimer: Timer?
    private var joystickTimer: Timer?
    private var routeTask: Task<Void, Never>?
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    private var joystickVector: CGVector = .zero
    private let locationKeeper = BackgroundKeepAlive()

    private let favoritesKey = "locus.favorites"
    private let recentsKey = "locus.recents"
    private let routesKey = "locus.savedRoutes"

    public init() {
        favorites = SavedPlace.load(key: favoritesKey)
        recents = SavedPlace.load(key: recentsKey)
        savedRoutes = SavedRoute.load(key: routesKey)
        customSpeedMPS = SpeedPreference.storedValue
        currentTheme = ThemeStore.currentTheme
        appearanceMode = ThemeStore.currentAppearance

        NotificationCenter.default.addObserver(
            forName: .locusThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let newTheme = note.object as? AppTheme {
                self?.currentTheme = newTheme
            }
        }

        NotificationCenter.default.addObserver(
            forName: .locusAppearanceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let newMode = note.object as? AppearanceMode {
                self?.appearanceMode = newMode
            }
        }
    }

    public var isSpoofing: Bool {
        if case .active = status { return true }
        if case .reconnecting = status { return true }
        return false
    }

    /// The single source of truth for movement speed (meters per second). Joystick
    /// ticking and route/GPX playback both read this instead of `travelMode.baseSpeed`
    /// directly, so a custom speed applies consistently everywhere motion happens.
    public var currentSpeedMPS: CLLocationSpeed {
        customSpeedMPS ?? travelMode.baseSpeed
    }

    // MARK: - ETA Formatting Helpers
    public var formattedETA: String {
        guard isRouteActive, routeTimeRemainingSeconds > 0 else { return "" }
        let totalSecs = Int(routeTimeRemainingSeconds)
        let hours = totalSecs / 3600
        let minutes = (totalSecs % 3600) / 60
        let seconds = totalSecs % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    public var formattedDistanceRemaining: String {
        guard isRouteActive else { return "" }
        if routeDistanceRemainingMeters >= 1000 {
            return String(format: "%.2f km", routeDistanceRemainingMeters / 1000)
        } else {
            return String(format: "%.0f m", routeDistanceRemainingMeters)
        }
    }

    /// Validates and applies a custom speed typed by the user (see `SpeedInput`),
    /// persisting it so it survives relaunch. Safe to call while the joystick is
    /// active — it only changes the value `tickJoystick` reads next tick.
    /// Returns `false` without changing anything if the text isn't a valid speed.
    @discardableResult
    public func setCustomSpeed(fromText text: String) -> Bool {
        guard let value = SpeedInput.parse(text) else { return false }
        customSpeedMPS = value
        SpeedPreference.setCustomSpeed(value)
        return true
    }

    /// Clears any custom speed override, reverting to the selected travel mode's preset.
    public func clearCustomSpeed() {
        customSpeedMPS = nil
        SpeedPreference.setCustomSpeed(nil)
    }

    public func teleport(to coordinate: CLLocationCoordinate2D, pairing: PairingStore) {
        guard pairing.hasPairingFile else {
            lastError = "Import an RPPairing file in Settings first."
            return
        }
        pin = coordinate
        apply(coordinate, pairing: pairing, markRecent: true)
    }

    public func stop(pairing: PairingStore) {
        stopRoute()
        stopJoystick()
        stopResend()
        stopHealth()
        isBusy = true
        let result = LocationEngine.clear()
        isBusy = false
        switch result {
        case .success:
            simulated = nil
            status = .idle
            endBackground()
            locationKeeper.start()
        case .failure(let error):
            lastError = error.localizedDescription
            status = .dropped(error.localizedDescription)
            postDropNotification(error.localizedDescription)
        }
    }

    /// Best-known real device coordinate (not the teleport pin).
    public var realCoordinate: CLLocationCoordinate2D? {
        locationKeeper.lastKnownCoordinate
    }

    /// Start lightweight GPS updates for the map puck / locate button.
    public func startLocationUpdates() {
        locationKeeper.start()
    }

    public func startJoystick(pairing: PairingStore) {
        guard pairing.hasPairingFile else {
            lastError = "Import an RPPairing file in Settings first."
            return
        }
        let start = simulated ?? pin ?? locationKeeper.lastKnownCoordinate
        guard let start else {
            lastError = "Drop a pin or teleport somewhere before using the joystick."
            return
        }
        if simulated == nil {
            apply(start, pairing: pairing, markRecent: false)
        }
        joystickActive = true
        joystickTimer?.invalidate()
        joystickTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickJoystick(pairing: pairing)
            }
        }
    }

    public func updateJoystick(vector: CGVector) {
        joystickVector = vector
    }

    public func stopJoystick() {
        joystickActive = false
        joystickVector = .zero
        joystickTimer?.invalidate()
        joystickTimer = nil
    }

    // MARK: - Route Following with Live ETA
    public func followRoute(_ coordinates: [CLLocationCoordinate2D], pairing: PairingStore) {
        guard pairing.hasPairingFile, coordinates.count >= 2 else { return }
        routeTask?.cancel()
        stopJoystick()

        // Compute total route distance
        var totalDist: CLLocationDistance = 0
        for (a, b) in zip(coordinates, coordinates.dropFirst()) {
            totalDist += CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        }

        routeTotalDistanceMeters = totalDist
        routeDistanceRemainingMeters = totalDist
        routeTimeRemainingSeconds = totalDist / max(0.8, currentSpeedMPS)
        routeProgress = 0.0
        activeRouteCoordinates = coordinates
        isRouteActive = true

        let speedMPS = currentSpeedMPS

        routeTask = Task { [weak self] in
            guard let self else { return }
            var previous = coordinates[0]
            var distanceTraveled: CLLocationDistance = 0

            await MainActor.run {
                self.apply(previous, pairing: pairing, markRecent: true)
            }

            for next in coordinates.dropFirst() {
                if Task.isCancelled { break }
                let legDistance = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
                    .distance(from: CLLocation(latitude: next.latitude, longitude: next.longitude))
                var speed = speedMPS * Double.random(in: 0.92...1.08)
                speed = max(0.8, speed)
                let stepMeters: CLLocationDistance = min(10, max(3, speed * 0.4))
                let steps = max(1, Int(ceil(legDistance / stepMeters)))

                for i in 1...steps {
                    if Task.isCancelled { break }
                    let t = Double(i) / Double(steps)
                    let coord = CLLocationCoordinate2D(
                        latitude: previous.latitude + (next.latitude - previous.latitude) * t,
                        longitude: previous.longitude + (next.longitude - previous.longitude) * t
                    )
                    let currentStepDist = legDistance * (Double(1) / Double(steps))
                    distanceTraveled += currentStepDist

                    let remaining = max(0, totalDist - distanceTraveled)
                    let estTime = remaining / speed

                    let delay = stepMeters / speed
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    await MainActor.run {
                        self.routeDistanceRemainingMeters = remaining
                        self.routeTimeRemainingSeconds = estTime
                        self.routeProgress = min(1.0, distanceTraveled / max(1.0, totalDist))
                        self.apply(coord, pairing: pairing, markRecent: false)
                    }
                }
                previous = next
            }

            await MainActor.run {
                self.isRouteActive = false
                self.routeProgress = 1.0
                self.routeDistanceRemainingMeters = 0
                self.routeTimeRemainingSeconds = 0
            }
        }
    }

    public func stopRoute() {
        routeTask?.cancel()
        routeTask = nil
        isRouteActive = false
        routeProgress = 0.0
        routeDistanceRemainingMeters = 0
        routeTimeRemainingSeconds = 0
    }

    // MARK: - Saved Routes Management
    public func saveRoute(name: String, coordinates: [CLLocationCoordinate2D]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let routeName = trimmed.isEmpty ? "Route \(savedRoutes.count + 1)" : trimmed
        let route = SavedRoute(name: routeName, coordinates: coordinates)
        savedRoutes.insert(route, at: 0)
        SavedRoute.save(savedRoutes, key: routesKey)
    }

    public func saveRoute(name: String, track: GPXTrack) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let routeName = trimmed.isEmpty ? (track.name ?? "Route \(savedRoutes.count + 1)") : trimmed
        let route = SavedRoute(name: routeName, track: track)
        savedRoutes.insert(route, at: 0)
        SavedRoute.save(savedRoutes, key: routesKey)
    }

    public func removeSavedRoute(_ route: SavedRoute) {
        savedRoutes.removeAll { $0.id == route.id }
        SavedRoute.save(savedRoutes, key: routesKey)
    }

    public func renameSavedRoute(_ route: SavedRoute, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = savedRoutes.firstIndex(where: { $0.id == route.id }) else { return }
        savedRoutes[index].name = trimmed
        SavedRoute.save(savedRoutes, key: routesKey)
    }

    // MARK: - Favorites Management
    public func addFavorite(name: String, coordinate: CLLocationCoordinate2D) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = SavedPlace(
            name: trimmed.isEmpty ? Self.coordinateLabel(coordinate) : trimmed,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        if let existing = favorites.first(where: { $0.id == place.id }),
           Self.isGenericFavoriteName(place.name),
           !Self.isGenericFavoriteName(existing.name) {
            return
        }
        favorites.removeAll { $0.id == place.id }
        favorites.insert(place, at: 0)
        SavedPlace.save(favorites, key: favoritesKey)
    }

    public func renameFavorite(_ place: SavedPlace, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = favorites.firstIndex(where: { $0.id == place.id }) else { return }
        favorites[index].name = trimmed
        SavedPlace.save(favorites, key: favoritesKey)
    }

    public func removeFavorite(_ place: SavedPlace) {
        favorites.removeAll { $0.id == place.id }
        SavedPlace.save(favorites, key: favoritesKey)
    }

    public func removeRecent(_ place: SavedPlace) {
        recents.removeAll { $0.id == place.id }
        SavedPlace.save(recents, key: recentsKey)
    }

    public func suggestedFavoriteName(for coordinate: CLLocationCoordinate2D, fallback: String? = nil) -> String {
        if let fallback, !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let favorite = favorites.first(where: { $0.id == SavedPlace(name: "", latitude: coordinate.latitude, longitude: coordinate.longitude).id }),
           !Self.isGenericFavoriteName(favorite.name) {
            return favorite.name
        }
        if let recent = recents.first(where: {
            abs($0.latitude - coordinate.latitude) < 0.00015 && abs($0.longitude - coordinate.longitude) < 0.00015
        }), !Self.isGenericFavoriteName(recent.name) {
            return recent.name
        }
        return Self.coordinateLabel(coordinate)
    }

    private static func coordinateLabel(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    private static func isGenericFavoriteName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "Favorite" { return true }
        let parts = trimmed.split(separator: ",")
        if parts.count == 2,
           Double(parts[0].trimmingCharacters(in: .whitespaces)) != nil,
           Double(parts[1].trimmingCharacters(in: .whitespaces)) != nil {
            return true
        }
        return false
    }

    private func apply(_ coordinate: CLLocationCoordinate2D, pairing: PairingStore, markRecent: Bool) {
        if status == .idle || status.isDropped {
            status = .connecting
        }
        isBusy = true
        let result = LocationEngine.set(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            pairingPath: pairing.pairingPath,
            deviceIP: TunnelConfig.targetIP
        )
        isBusy = false
        switch result {
        case .success:
            simulated = coordinate
            status = .active
            startResend(coordinate: coordinate, pairing: pairing)
            startHealth(pairing: pairing)
            beginBackground()
            if markRecent {
                let place = SavedPlace(
                    name: suggestedFavoriteName(for: coordinate),
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                recents.removeAll { $0.id == place.id }
                recents.insert(place, at: 0)
                if recents.count > 20 { recents.removeLast() }
                SavedPlace.save(recents, key: recentsKey)
            }
        case .failure(let error):
            lastError = error.localizedDescription
            status = .dropped(error.localizedDescription)
            postDropNotification(error.localizedDescription)
        }
    }

    private func tickJoystick(pairing: PairingStore) {
        guard joystickActive, let current = simulated else { return }
        let vx = Double(joystickVector.dx)
        let vy = Double(joystickVector.dy)
        let mag = sqrt(vx * vx + vy * vy)
        guard mag > 0.05 else { return }

        let metersPerSec = currentSpeedMPS
        let distanceMeters = metersPerSec * 0.25 * min(1.0, mag)

        let latMetersPerDeg: Double = 111_132
        let lonMetersPerDeg: Double = 111_320 * cos(current.latitude * .pi / 180)

        let dLat = (-vy / mag) * (distanceMeters / latMetersPerDeg)
        let dLon = (vx / mag) * (distanceMeters / lonMetersPerDeg)

        let next = CLLocationCoordinate2D(
            latitude: current.latitude + dLat,
            longitude: current.longitude + dLon
        )
        apply(next, pairing: pairing, markRecent: false)
    }

    private func startResend(coordinate: CLLocationCoordinate2D, pairing: PairingStore) {
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isSpoofing else { return }
                _ = LocationEngine.set(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    pairingPath: pairing.pairingPath,
                    deviceIP: TunnelConfig.targetIP
                )
            }
        }
    }

    private func stopResend() {
        resendTimer?.invalidate()
        resendTimer = nil
    }

    private func startHealth(pairing: PairingStore) {
        healthTimer?.invalidate()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isSpoofing else { return }
                let ok = LocationEngine.ping(
                    pairingPath: pairing.pairingPath,
                    deviceIP: TunnelConfig.targetIP
                )
                if !ok {
                    self.status = .dropped("Connection to tunnel timed out")
                    self.postDropNotification("Connection to tunnel timed out")
                }
            }
        }
    }

    private func stopHealth() {
        healthTimer?.invalidate()
        healthTimer = nil
    }

    private func beginBackground() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "com.chrismack.locus.keepalive") { [weak self] in
            self?.endBackground()
        }
    }

    private func endBackground() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private func postDropNotification(_ reason: String) {
        let content = UNMutableNotificationContent()
        content.title = "Locus spoof dropped"
        content.body = reason.isEmpty ? "Location simulation stopped." : reason
        content.sound = .defaultCritical
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
