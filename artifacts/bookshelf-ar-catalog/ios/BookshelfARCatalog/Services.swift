import CoreLocation
import Foundation

struct OpenLibraryBook {
    var title: String
    var authors: String
    var publisher: String
    var subjects: String
    var coverURL: String
}

enum OpenLibraryError: LocalizedError {
    case notFound
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Book not found. Enter the book details manually before saving."
        case .invalidResponse:
            return "Open Library returned an unexpected response."
        }
    }
}

struct OpenLibraryClient {
    func lookup(isbn: String) async throws -> OpenLibraryBook {
        var request = URLRequest(url: URL(string: "https://openlibrary.org/isbn/\(isbn).json")!)
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OpenLibraryError.notFound
        }
        let decoded = try JSONDecoder().decode(OpenLibraryResponse.self, from: data)
        guard let title = decoded.title, !title.isEmpty else {
            throw OpenLibraryError.invalidResponse
        }
        let authorNames = decoded.authors?.compactMap(\.name).joined(separator: ", ") ?? ""
        let subjects = decoded.subjects?.prefix(4).joined(separator: ", ") ?? ""
        return OpenLibraryBook(
            title: title,
            authors: authorNames,
            publisher: decoded.publishers?.first ?? "",
            subjects: subjects,
            coverURL: "https://covers.openlibrary.org/b/isbn/\(isbn)-M.jpg"
        )
    }
}

private struct OpenLibraryResponse: Decodable {
    var title: String?
    var authors: [OpenLibraryAuthor]?
    var publishers: [String]?
    var subjects: [String]?
}

private struct OpenLibraryAuthor: Decodable {
    var name: String?
}

struct ShelfLocationCapture {
    var location: ShelfLocation?
    var status: Status

    enum Status {
        case saved
        case denied
        case unavailable
    }
}

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<ShelfLocationCapture, Never>?
    private var timeoutWorkItem: DispatchWorkItem?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func capture() async -> ShelfLocationCapture {
        if CLLocationManager.authorizationStatus() == .denied ||
            CLLocationManager.authorizationStatus() == .restricted {
            return ShelfLocationCapture(location: nil, status: .denied)
        }
        guard CLLocationManager.locationServicesEnabled() else {
            return ShelfLocationCapture(location: nil, status: .unavailable)
        }

        if CLLocationManager.authorizationStatus() == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let timeout = DispatchWorkItem { [weak self] in
                self?.finish(ShelfLocationCapture(location: nil, status: .unavailable))
            }
            self.timeoutWorkItem = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: timeout)
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if continuation != nil { manager.requestLocation() }
        case .denied, .restricted:
            finish(ShelfLocationCapture(location: nil, status: .denied))
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.first?.coordinate,
              coordinate.latitude.isFinite,
              coordinate.longitude.isFinite else {
            finish(ShelfLocationCapture(location: nil, status: .unavailable))
            return
        }
        let source = locations.first!
        finish(ShelfLocationCapture(
            location: ShelfLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                accuracy: source.horizontalAccuracy >= 0 ? source.horizontalAccuracy : nil,
                capturedAt: AppDate.nowISO8601()
            ),
            status: .saved
        ))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(ShelfLocationCapture(location: nil, status: .unavailable))
    }

    private func finish(_ result: ShelfLocationCapture) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        let pending = continuation
        continuation = nil
        pending?.resume(returning: result)
    }
}

enum LocationMath {
    static func distanceInMeters(from: ShelfLocation, to: ShelfLocation) -> Double {
        let earthRadius = 6_371_000.0
        let latitudeDelta = radians(to.latitude - from.latitude)
        let longitudeDelta = radians(to.longitude - from.longitude)
        let latitude1 = radians(from.latitude)
        let latitude2 = radians(to.latitude)
        let haversine = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(latitude1) * cos(latitude2)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return earthRadius * 2 * atan2(sqrt(haversine), sqrt(1 - haversine))
    }

    static func isNear(distance: Double, savedAccuracy: Double?, currentAccuracy: Double?) -> Bool {
        distance <= max(75, (savedAccuracy ?? 0) + (currentAccuracy ?? 0))
    }

    static func formatDistance(_ distance: Double) -> String {
        distance < 1000 ? "\(Int(distance.rounded())) m away" : String(format: "%.1f km away", distance / 1000)
    }

    private static func radians(_ value: Double) -> Double { value * .pi / 180 }
}
