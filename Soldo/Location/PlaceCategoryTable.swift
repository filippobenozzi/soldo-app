import Foundation
import MapKit

/// The lookup table that turns an Apple Maps point-of-interest category into the
/// name of one of Soldo's spending categories.
///
/// Split out from `PlaceCategoryMapper` so `Tools/run-checks.sh` can exercise it
/// without pulling in SwiftData.
enum PlaceCategoryTable {

    /// Default category names, in the order Soldo seeds them.
    private static let mapping: [(names: [String], categories: Set<String>)] = [
        (["spesa", "supermercato", "groceries", "alimentari"], [
            MKPointOfInterestCategory.foodMarket.rawValue,
            MKPointOfInterestCategory.bakery.rawValue,
        ]),
        (["ristoranti", "ristorante", "bar", "cibo", "food", "dining"], [
            MKPointOfInterestCategory.restaurant.rawValue,
            MKPointOfInterestCategory.cafe.rawValue,
            MKPointOfInterestCategory.brewery.rawValue,
            MKPointOfInterestCategory.winery.rawValue,
            MKPointOfInterestCategory.nightlife.rawValue,
        ]),
        (["trasporti", "transport", "auto", "benzina", "viaggio in città"], [
            MKPointOfInterestCategory.gasStation.rawValue,
            MKPointOfInterestCategory.evCharger.rawValue,
            MKPointOfInterestCategory.parking.rawValue,
            MKPointOfInterestCategory.publicTransport.rawValue,
            MKPointOfInterestCategory.carRental.rawValue,
        ]),
        (["salute", "health", "farmacia", "medico"], [
            MKPointOfInterestCategory.pharmacy.rawValue,
            MKPointOfInterestCategory.hospital.rawValue,
            MKPointOfInterestCategory.fitnessCenter.rawValue,
        ]),
        (["svago", "tempo libero", "divertimento", "entertainment"], [
            MKPointOfInterestCategory.movieTheater.rawValue,
            MKPointOfInterestCategory.theater.rawValue,
            MKPointOfInterestCategory.museum.rawValue,
            MKPointOfInterestCategory.amusementPark.rawValue,
            MKPointOfInterestCategory.stadium.rawValue,
            MKPointOfInterestCategory.zoo.rawValue,
            MKPointOfInterestCategory.aquarium.rawValue,
            MKPointOfInterestCategory.nationalPark.rawValue,
            MKPointOfInterestCategory.park.rawValue,
            MKPointOfInterestCategory.beach.rawValue,
            MKPointOfInterestCategory.library.rawValue,
        ]),
        (["shopping", "negozi", "acquisti"], [
            MKPointOfInterestCategory.store.rawValue,
            MKPointOfInterestCategory.laundry.rawValue,
        ]),
        (["viaggi", "travel", "vacanze"], [
            MKPointOfInterestCategory.hotel.rawValue,
            MKPointOfInterestCategory.airport.rawValue,
            MKPointOfInterestCategory.campground.rawValue,
            MKPointOfInterestCategory.marina.rawValue,
        ]),
        (["casa", "home"], [
            MKPointOfInterestCategory.postOffice.rawValue,
        ]),
    ]

    /// Category names, best first, for a given point-of-interest identifier.
    static func candidateCategoryNames(for poiIdentifier: String?) -> [String] {
        guard let poiIdentifier else { return [] }
        for entry in mapping where entry.categories.contains(poiIdentifier) {
            return entry.names
        }
        return []
    }
}
