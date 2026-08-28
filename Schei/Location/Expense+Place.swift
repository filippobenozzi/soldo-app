import Foundation

extension Expense {
    /// Applies a resolved place to the expense.
    ///
    /// Lives on the app side: the model itself is shared with the widget extension,
    /// which has no reason to link MapKit.
    func apply(place: DetectedPlace?) {
        guard let place else {
            latitude = nil
            longitude = nil
            placeName = nil
            placeCategoryIdentifier = nil
            return
        }
        latitude = place.latitude
        longitude = place.longitude
        placeName = place.name
        placeCategoryIdentifier = place.categoryIdentifier
    }
}
