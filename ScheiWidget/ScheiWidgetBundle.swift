import SwiftUI
import WidgetKit

@main
struct ScheiWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpendingWidget()
        RecentExpensesWidget()
        if #available(iOS 18.0, *) {
            QuickAddControl()
            OpenScheiControl()
        }
    }
}
