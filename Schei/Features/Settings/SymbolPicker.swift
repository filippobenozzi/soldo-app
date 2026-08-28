import SwiftUI

/// Curated SF Symbols — a full browser would be overkill for a expense tracker.
enum ScheiSymbols {
    static let all = [
        "cart.fill", "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        "car.fill", "fuelpump.fill", "bus.fill", "tram.fill", "bicycle", "airplane",
        "house.fill", "bolt.fill", "drop.fill", "flame.fill", "wifi", "iphone",
        "bag.fill", "tshirt.fill", "shoe.fill", "gift.fill", "sparkles",
        "cross.case.fill", "pills.fill", "heart.fill", "figure.run", "dumbbell.fill",
        "gamecontroller.fill", "film.fill", "music.note", "book.fill", "ticket.fill",
        "pawprint.fill", "leaf.fill", "graduationcap.fill", "briefcase.fill",
        "creditcard.fill", "banknote.fill", "wallet.pass.fill", "eurosign.circle.fill",
        "building.columns.fill", "chart.line.uptrend.xyaxis", "arrow.triangle.2.circlepath",
        "scissors", "wrench.and.screwdriver.fill", "shippingbox.fill", "tag.fill",
        "person.2.fill", "phone.fill", "envelope.fill", "ellipsis.circle.fill",
    ]
}

struct SymbolColorPicker: View {
    @Binding var symbolName: String
    @Binding var colorHex: String

    private let columns = Array(repeating: GridItem(.adaptive(minimum: 46), spacing: 10), count: 1)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Colore")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 10)], spacing: 10) {
                    ForEach(ScheiPalette.hexes, id: \.self) { hex in
                        Button {
                            colorHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if colorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Icona")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(ScheiSymbols.all, id: \.self) { symbol in
                        Button {
                            symbolName = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 18))
                                .frame(width: 44, height: 44)
                                .foregroundStyle(symbolName == symbol ? Color.white : Color(hex: colorHex))
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(symbolName == symbol ? Color(hex: colorHex) : Color(hex: colorHex).opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
