import Foundation
import MapKit

/// Matches a detected place against the categories the user actually has.
/// Matching happens on the category *name*, so a renamed or custom category still
/// works as long as the name stays recognisable.
enum PlaceCategoryMapper {

    /// Picks the user's category that best fits the place.
    static func match(_ place: DetectedPlace, in categories: [SpendingCategory]) -> SpendingCategory? {
        let candidates = PlaceCategoryTable.candidateCategoryNames(for: place.categoryIdentifier)
        guard !candidates.isEmpty else { return nil }

        let available = categories.filter { !$0.isArchived }
        for candidate in candidates {
            if let match = available.first(where: { $0.name.lowercased() == candidate }) {
                return match
            }
        }
        for candidate in candidates {
            if let match = available.first(where: { $0.name.lowercased().contains(candidate) }) {
                return match
            }
        }
        return nil
    }

    /// Human-readable label for the detected place type, shown next to the suggestion.
    static func label(for poiIdentifier: String?) -> String? {
        guard let poiIdentifier else { return nil }
        return PlaceCategoryTable.candidateCategoryNames(for: poiIdentifier).first?.capitalized
    }
}
