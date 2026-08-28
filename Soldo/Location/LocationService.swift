import CoreLocation
import Foundation
import MapKit
import Observation

/// Wraps CoreLocation and MapKit lookups behind a small async API.
///
/// Soldo only ever asks for "when in use": the location is read at the moment an
/// expense is created, never in the background, and only when the user has turned
/// the feature on.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var pending: [CheckedContinuation<CLLocation?, Never>] = []

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var lastLocation: CLLocation?
    private(set) var isResolving = false

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var statusDescription: String {
        switch authorizationStatus {
        case .notDetermined: "Non richiesto"
        case .restricted: "Non disponibile su questo dispositivo"
        case .denied: "Negato — attivalo in Impostazioni iOS"
        case .authorizedAlways, .authorizedWhenInUse: "Consentito"
        @unknown default: "Sconosciuto"
        }
    }

    func requestPermission() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    // MARK: - Fixes

    /// A fix no older than a minute, or a fresh one. `nil` when unavailable.
    func currentLocation() async -> CLLocation? {
        guard isAuthorized else { return nil }

        if let lastLocation, lastLocation.timestamp.timeIntervalSinceNow > -60 {
            return lastLocation
        }

        isResolving = true
        defer { isResolving = false }

        let location = await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
            pending.append(continuation)
            manager.requestLocation()

            // CoreLocation can stay silent indoors; don't let the UI hang on it.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(6))
                self.flushPending(with: self.lastLocation)
            }
        }
        return location
    }

    private func flushPending(with location: CLLocation?) {
        guard !pending.isEmpty else { return }
        let waiting = pending
        pending.removeAll()
        for continuation in waiting {
            continuation.resume(returning: location)
        }
    }

    // MARK: - Places

    /// Points of interest around the user, closest first.
    func nearbyPlaces(limit: Int = 10) async -> [DetectedPlace] {
        guard let location = await currentLocation() else { return [] }

        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: 160)
        request.pointOfInterestFilter = .includingAll

        guard let response = try? await MKLocalSearch(request: request).start() else {
            return [fallbackPlace(for: location)].compactMap { $0 }
        }

        let places = response.mapItems
            .compactMap { DetectedPlace(mapItem: $0, from: location) }
            .sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }

        guard places.isEmpty else { return Array(places.prefix(limit)) }
        return [fallbackPlace(for: location)].compactMap { $0 }
    }

    /// The single most likely place the user is at right now.
    func currentPlace() async -> DetectedPlace? {
        await nearbyPlaces(limit: 1).first
    }

    /// Looks up a place by name — used for the shop printed on a receipt.
    /// The search is biased towards the user's position when that is known.
    func place(matching query: String, near location: CLLocation? = nil) async -> DetectedPlace? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed

        let origin = location ?? lastLocation
        if let origin {
            request.region = MKCoordinateRegion(
                center: origin.coordinate,
                latitudinalMeters: 30_000,
                longitudinalMeters: 30_000
            )
        }

        guard let response = try? await MKLocalSearch(request: request).start() else { return nil }
        let places = response.mapItems.compactMap { DetectedPlace(mapItem: $0, from: origin) }

        // With a known position, prefer the nearest branch of a chain.
        guard origin != nil else { return places.first }
        return places.min { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
    }

    /// When no point of interest matches, keep at least the coordinates.
    private func fallbackPlace(for location: CLLocation) -> DetectedPlace? {
        DetectedPlace(
            name: "Posizione attuale",
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            distance: 0
        )
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            authorizationStatus = manager.authorizationStatus
            if !isAuthorized {
                flushPending(with: nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            if let location = locations.last {
                lastLocation = location
                flushPending(with: location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            flushPending(with: lastLocation)
        }
    }
}
