import SwiftUI
import WidgetKit

@main
struct SoldoWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpendingWidget()
        RecentExpensesWidget()
        if #available(iOS 18.0, *) {
            QuickAddControl()
            OpenSoldoControl()
        }
    }
}
