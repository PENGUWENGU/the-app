import XCTest
import CoreLocation

final class SavedRouteTests: XCTestCase {

    func testSavedRouteSerialization() throws {
        let coords = [
            CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
            CLLocationCoordinate2D(latitude: 37.3355, longitude: -122.0080),
            CLLocationCoordinate2D(latitude: 37.3360, longitude: -122.0070)
        ]

        let route = SavedRoute(name: "Test Apple Park Loop", coordinates: coords)
        XCTAssertEqual(route.name, "Test Apple Park Loop")
        XCTAssertEqual(route.waypoints.count, 3)
        XCTAssertGreaterThan(route.totalDistanceMeters, 0)

        // Test persistent storage encoding and decoding
        let testKey = "locus.test.routes.\(UUID().uuidString)"
        SavedRoute.save([route], key: testKey)
        defer { UserDefaults.standard.removeObject(forKey: testKey) }

        let loaded = SavedRoute.load(key: testKey)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "Test Apple Park Loop")
        XCTAssertEqual(loaded[0].clCoordinates.count, 3)
        XCTAssertEqual(loaded[0].clCoordinates[0].latitude, 37.3349, accuracy: 1e-6)
        XCTAssertEqual(loaded[0].clCoordinates[0].longitude, -122.0090, accuracy: 1e-6)
    }

    func testGPXTrackSavedRoute() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <name>Mountain Trail</name>
            <trkseg>
              <trkpt lat="45.5231" lon="-122.6765"><ele>150.5</ele></trkpt>
              <trkpt lat="45.5240" lon="-122.6770"><ele>175.2</ele></trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        let track = try GPXCodec.parseTrack(data: Data(gpx.utf8))
        let route = SavedRoute(name: "Mountain Trail", track: track)

        XCTAssertEqual(route.name, "Mountain Trail")
        XCTAssertEqual(route.waypoints.count, 2)
        XCTAssertEqual(route.waypoints[0].elevation, 150.5)

        let testKey = "locus.test.gpxroutes.\(UUID().uuidString)"
        SavedRoute.save([route], key: testKey)
        defer { UserDefaults.standard.removeObject(forKey: testKey) }

        let loaded = SavedRoute.load(key: testKey)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].waypoints[0].elevation, 150.5)
        XCTAssertNotNil(loaded[0].rawGPX)
    }
}
