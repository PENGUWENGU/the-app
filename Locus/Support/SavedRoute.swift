import CoreLocation
import Foundation

public struct SavedGPXWaypoint: Codable, Equatable {
    public var latitude: Double
    public var longitude: Double
    public var elevation: Double?
    public var time: Date?
    public var name: String?

    public init(
        latitude: Double,
        longitude: Double,
        elevation: Double? = nil,
        time: Date? = nil,
        name: String? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.time = time
        self.name = name
    }

    public init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.elevation = nil
        self.time = nil
        self.name = nil
    }

    public var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var gpxTrackPoint: GPXTrackPoint {
        GPXTrackPoint(
            coordinate: clCoordinate,
            elevation: elevation,
            time: time
        )
    }
}

public struct SavedRoute: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var waypoints: [SavedGPXWaypoint]
    public var totalDistanceMeters: Double
    public var dateCreated: Date
    /// Cached GPX XML string for 1:1 lossless export and retrieval
    public var rawGPX: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        waypoints: [SavedGPXWaypoint],
        rawGPX: String? = nil,
        dateCreated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.waypoints = waypoints
        self.rawGPX = rawGPX
        self.dateCreated = dateCreated

        var dist: Double = 0
        if waypoints.count > 1 {
            for (a, b) in zip(waypoints, waypoints.dropFirst()) {
                dist += CLLocation(latitude: a.latitude, longitude: a.longitude)
                    .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            }
        }
        self.totalDistanceMeters = dist
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        coordinates: [CLLocationCoordinate2D],
        rawGPX: String? = nil,
        dateCreated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.waypoints = coordinates.map { SavedGPXWaypoint($0) }
        self.rawGPX = rawGPX
        self.dateCreated = dateCreated

        var dist: Double = 0
        if coordinates.count > 1 {
            for (a, b) in zip(coordinates, coordinates.dropFirst()) {
                dist += CLLocation(latitude: a.latitude, longitude: a.longitude)
                    .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            }
        }
        self.totalDistanceMeters = dist
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        track: GPXTrack,
        dateCreated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.waypoints = track.allPoints.map {
            SavedGPXWaypoint(
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude,
                elevation: $0.elevation,
                time: $0.time
            )
        }
        self.rawGPX = GPXCodec.export(track)
        self.dateCreated = dateCreated

        var dist: Double = 0
        let coords = track.coordinates
        if coords.count > 1 {
            for (a, b) in zip(coords, coords.dropFirst()) {
                dist += CLLocation(latitude: a.latitude, longitude: a.longitude)
                    .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            }
        }
        self.totalDistanceMeters = dist
    }

    public var clCoordinates: [CLLocationCoordinate2D] {
        waypoints.map(\.clCoordinate)
    }

    public var coordinates: [CLLocationCoordinate2D] {
        clCoordinates
    }

    public var formattedDistance: String {
        if totalDistanceMeters >= 1000 {
            return String(format: "%.2f km", totalDistanceMeters / 1000)
        } else {
            return String(format: "%.0f m", totalDistanceMeters)
        }
    }

    // MARK: - Persistent Storage (UserDefaults / Local Storage)
    public static let storageKey = "locus.savedRoutes"

    /// Loads all saved routes from local storage
    public static func load(key: String = storageKey) -> [SavedRoute] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedRoute].self, from: data) else {
            return []
        }
        return decoded
    }

    /// Saves the full list of routes to local storage
    public static func save(_ routes: [SavedRoute], key: String = storageKey) {
        if let data = try? JSONEncoder().encode(routes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Helper: returns a list of all saved route names
    public static func getSavedRouteNames(key: String = storageKey) -> [String] {
        load(key: key).map(\.name)
    }

    /// Helper: saves the current GPS route data to local storage
    @discardableResult
    public static func saveCurrentRoute(
        name: String,
        coordinates: [CLLocationCoordinate2D],
        rawGPX: String? = nil,
        key: String = storageKey
    ) -> SavedRoute {
        var existing = load(key: key)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let routeName = trimmed.isEmpty ? "Route \(existing.count + 1)" : trimmed
        let newRoute = SavedRoute(name: routeName, coordinates: coordinates, rawGPX: rawGPX)
        existing.insert(newRoute, at: 0)
        save(existing, key: key)
        return newRoute
    }

    /// Helper: retrieves a route by its name
    public static func getRouteByName(_ name: String, key: String = storageKey) -> SavedRoute? {
        load(key: key).first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Helper: deletes a route by id
    public static func deleteRoute(id: String, key: String = storageKey) {
        var routes = load(key: key)
        routes.removeAll { $0.id == id }
        save(routes, key: key)
    }

    /// Helper: renames an existing route
    public static func renameRoute(id: String, to newName: String, key: String = storageKey) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var routes = load(key: key)
        if let idx = routes.firstIndex(where: { $0.id == id }) {
            routes[idx].name = trimmed
            save(routes, key: key)
        }
    }

    // MARK: - GPX Export
    /// Exports this route to standard GPX XML format
    public func toGPX() -> String {
        if let cached = rawGPX, !cached.isEmpty {
            return cached
        }
        let points = waypoints.map { $0.gpxTrackPoint }
        let track = GPXTrack(name: name, segments: [points])
        return GPXCodec.export(track)
    }

    /// Writes this route to a standard .gpx file in the temporary directory for downloading or sharing
    public func exportToGPXFile(fileName: String? = nil) -> URL? {
        let xml = toGPX()
        let safeName = (fileName ?? name)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
        let actualName = safeName.isEmpty ? "route_\(id.prefix(6))" : safeName
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(actualName).gpx")
        do {
            try xml.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    /// Exports a route from local storage by its ID directly to a .gpx file URL
    public static func exportRouteFromLocalStorage(id: String, key: String = storageKey) -> URL? {
        guard let route = load(key: key).first(where: { $0.id == id }) else { return nil }
        return route.exportToGPXFile()
    }

    /// Exports a route from local storage by its name directly to a .gpx file URL
    public static func exportRouteFromLocalStorage(name: String, key: String = storageKey) -> URL? {
        guard let route = getRouteByName(name, key: key) else { return nil }
        return route.exportToGPXFile()
    }
}
