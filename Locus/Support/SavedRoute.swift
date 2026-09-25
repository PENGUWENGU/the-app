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

    public var formattedDistance: String {
        if totalDistanceMeters >= 1000 {
            return String(format: "%.2f km", totalDistanceMeters / 1000)
        } else {
            return String(format: "%.0f m", totalDistanceMeters)
        }
    }

    // MARK: - Persistent Storage (UserDefaults / Local Storage)
    private static let storageKey = "locus.savedRoutes"

    public static func load(key: String = storageKey) -> [SavedRoute] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedRoute].self, from: data) else {
            return []
        }
        return decoded
    }

    public static func save(_ routes: [SavedRoute], key: String = storageKey) {
        if let data = try? JSONEncoder().encode(routes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
