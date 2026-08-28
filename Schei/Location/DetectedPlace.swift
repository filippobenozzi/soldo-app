import CoreLocation
import Foundation
import MapKit

/// A place Schei believes an expense happened at, resolved either from GPS or
/// from the shop name printed on a receipt.
struct DetectedPlace: Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var categoryIdentifier: String?
    var street: String?
    var locality: String?
    var latitude: Double
    var longitude: Double
    /// Metres from the user, when the place came from a nearby search.
    var distance: CLLocationDistance?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var subtitle: String {
        var parts: [String] = []
        if let street, !street.isEmpty { parts.append(street) }
        if let locality, !locality.isEmpty { parts.append(locality) }
        if let distance {
            parts.append(distance < 1000
                         ? "\(Int(distance.rounded())) m"
                         : String(format: "%.1f km", distance / 1000))
        }
        return parts.joined(separator: " · ")
    }

    init?(mapItem: MKMapItem, from origin: CLLocation? = nil) {
        let placemark = mapItem.placemark
        guard let coordinate = placemark.location?.coordinate else { return nil }

        self.name = mapItem.name ?? placemark.name ?? "Luogo"
        self.categoryIdentifier = mapItem.pointOfInterestCategory?.rawValue
        self.street = [placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        self.locality = placemark.locality
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.distance = origin.map { placemark.location?.distance(from: $0) ?? 0 }
        self.id = "\(self.name)|\(coordinate.latitude.rounded(to: 5))|\(coordinate.longitude.rounded(to: 5))"
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        categoryIdentifier: String? = nil,
        street: String? = nil,
        locality: String? = nil,
        latitude: Double,
        longitude: Double,
        distance: CLLocationDistance? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryIdentifier = categoryIdentifier
        self.street = street
        self.locality = locality
        self.latitude = latitude
        self.longitude = longitude
        self.distance = distance
    }
}

extension Double {
    func rounded(to places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
