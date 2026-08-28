import SwiftUI

/// Numeric keypad tuned for one-handed use.
struct Keypad: View {
    let onDigit: (String) -> Void
    let onSeparator: () -> Void
    let onDelete: () -> Void
    let onLongDelete: () -> Void

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [",", "0", "\u{232B}"],
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { value in
                        keyButton(value)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func keyButton(_ value: String) -> some View {
        Button {
            switch value {
            case ",": onSeparator()
            case "\u{232B}": onDelete()
            default: onDigit(value)
            }
        } label: {
            Group {
                if value == "\u{232B}" {
                    Image(systemName: "delete.left")
                        .font(.title2)
                } else {
                    Text(value)
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ScheiTheme.card)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                if value == "\u{232B}" { onLongDelete() }
            }
        )
    }
}
