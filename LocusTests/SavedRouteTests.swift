import XCTest
import CoreLocation

final class SavedRouteTests: XCTestCase {

    func testSavedRouteSerialization() throws {
        let coords = [
            CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
            CLLocationCoordinate2D(latitude: 37.3355, longitude: -122.0080),
            CLLocationCoordinate2D(latitude: 37.3360, longitude: -122.0070)
        ]

        let testKey = "locus.test.routes.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: testKey) }

        let route = SavedRoute.saveCurrentRoute(
            name: "Test Apple Park Loop",
            coordinates: coords,
            key: testKey
        )
        XCTAssertEqual(route.name, "Test Apple Park Loop")
        XCTAssertEqual(route.waypoints.count, 3)
        XCTAssertGreaterThan(route.totalDistanceMeters, 0)

        let names = SavedRoute.getSavedRouteNames(key: testKey)
        XCTAssertEqual(names, ["Test Apple Park Loop"])

        let loadedRoute = SavedRoute.getRouteByName("Test Apple Park Loop", key: testKey)
        XCTAssertNotNil(loadedRoute)
        XCTAssertEqual(loadedRoute?.clCoordinates.count, 3)

        // Test rename
        SavedRoute.renameRoute(id: route.id, to: "Renamed Loop", key: testKey)
        let renamedNames = SavedRoute.getSavedRouteNames(key: testKey)
        XCTAssertEqual(renamedNames, ["Renamed Loop"])

        // Test delete
        SavedRoute.deleteRoute(id: route.id, key: testKey)
        XCTAssertTrue(SavedRoute.getSavedRouteNames(key: testKey).isEmpty)
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

    func testETACalculations() throws {
        // Test basic duration formatting
        XCTAssertEqual(RouteBuilder.formatDuration(45), "45s")
        XCTAssertEqual(RouteBuilder.formatDuration(150), "2m 30s")
        XCTAssertEqual(RouteBuilder.formatDuration(3665), "1h 1m")

        // 1000 meters at 10 m/s -> 100 seconds
        let etaSeconds = RouteBuilder.calculateETA(distanceMeters: 1000, speedMPS: 10)
        XCTAssertEqual(etaSeconds, 100, accuracy: 0.001)

        let coords = [
            CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
            CLLocationCoordinate2D(latitude: 0.0, longitude: 0.01) // ~1113 meters
        ]
        let userSpeed = 5.0 // 5 m/s
        let result = RouteBuilder.calculateRouteETA(coordinates: coords, speedMPS: userSpeed)

        XCTAssertGreaterThan(result.totalDistanceMeters, 1000)
        XCTAssertEqual(result.durationSeconds, result.totalDistanceMeters / userSpeed, accuracy: 0.01)
        XCTAssertFalse(result.formattedDuration.isEmpty)
    }

    func testGPXExportFromLocalStorage() throws {
        let testKey = "locus.test.export.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: testKey) }

        let coords = [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195)
        ]
        let route = SavedRoute.saveCurrentRoute(name: "San Francisco Walk", coordinates: coords, key: testKey)

        // Test XML string generation
        let gpxXML = route.toGPX()
        XCTAssertTrue(gpxXML.contains("<gpx"))
        XCTAssertTrue(gpxXML.contains("San Francisco Walk"))
        XCTAssertTrue(gpxXML.contains("37.7749000"))

        // Test file creation
        let fileURL = route.exportToGPXFile()
        XCTAssertNotNil(fileURL)
        if let fileURL = fileURL {
            defer { try? FileManager.default.removeItem(at: fileURL) }
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
            let readBack = try GPXCodec.parse(fileURL)
            XCTAssertEqual(readBack.count, 2)
        }

        // Test direct export by ID
        let fileURLById = SavedRoute.exportRouteFromLocalStorage(id: route.id, key: testKey)
        XCTAssertNotNil(fileURLById)
        if let fileURLById = fileURLById {
            defer { try? FileManager.default.removeItem(at: fileURLById) }
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURLById.path))
        }
    }
}
