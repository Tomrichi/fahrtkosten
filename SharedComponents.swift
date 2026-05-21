import SwiftUI

// MARK: - Empty State Row (redesigned: kompakter, frischer)
struct EmptyStateRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.09))
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundColor(color.opacity(0.7))
            }
            Text(title)
                .font(.subheadline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Hero Total Card
// MARK: - Kombinierte Übersichtskachel
struct CombinedSummaryCard: View {
    let erstattungTotal: Double
    let tripAmount: Double
    let mealAmount: Double
    let hotelAmount: Double
    let kfzTotal: Double
    let privateTotal: Double

    @State private var showErstattung = false


    @ViewBuilder
    private func summaryZeile(_ icon: String, _ color: Color, _ label: String, _ amount: Double) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(color.opacity(0.18)).frame(width: 28, height: 28)
                Image(systemName: icon).font(.system(size: 12)).foregroundColor(color)
            }
            Text(label).font(.system(size: 13)).foregroundColor(.white.opacity(0.75))
            Spacer()
            Text(amount.euroFormatted)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Gesamterstattung ──
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gesamterstattung")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text(erstattungTotal.euroFormatted)
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.17, green: 0.17, blue: 0.18), Color(red: 0.11, green: 0.11, blue: 0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
    }

}

// MARK: - Collapsible Summary Card
struct CollapsibleSummaryCard<Content: View>: View {
    let title: String
    let total: Double
    let accentColor: Color
    let isDark: Bool
    var badge: String? = nil
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // ── Header (immer sichtbar) ──
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isDark ? .white.opacity(0.7) : .secondary)
                            if let badge {
                                Text(badge)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(total.euroFormatted)
                            .font(.system(size: 26, weight: .semibold, design: .monospaced))
                            .foregroundColor(isDark ? .white : .primary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(isDark ? .white.opacity(0.4) : Color(.tertiaryLabel))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            // ── Aufgeklappter Inhalt ──
            if isExpanded {
                Divider()
                    .background(isDark ? Color.white.opacity(0.12) : Color(.separator))
                VStack(spacing: 0) {
                    content()
                }
                .background(isDark ? Color.white.opacity(0.03) : Color.clear)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isDark
                      ? AnyShapeStyle(LinearGradient(
                            colors: [Color(red: 0.17, green: 0.17, blue: 0.18),
                                     Color(red: 0.11, green: 0.11, blue: 0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: isDark ? .black.opacity(0.2) : .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Gesamterstattung Kachel (legacy, kept for compatibility)
struct HeroTotalCard: View {
    @EnvironmentObject var lm: LocalizationManager
    let total: Double
    let tripCount: Int
    let mealCount: Int
    let hotelCount: Int
    var spesenCount: Int = 0
    // unused legacy params kept for compatibility
    var fuelCost: Double = 0
    var reiseSpesenTotal: Double = 0
    var vehicleTotal: Double = 0
    var privateTotal: Double = 0

    var body: some View {
        VStack(spacing: 4) {
            Text("Gesamterstattung")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.8))
            Text(total.euroFormatted)
                .font(.system(size: 38, weight: .regular, design: .monospaced))
                .foregroundColor(.white)
            HStack(spacing: 16) {
                label("car.fill",        "\(tripCount) Fahrten")
                label("fork.knife",      "\(mealCount) Verpflegung")
                label("bed.double.fill", "\(hotelCount) Nächte")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.17, green: 0.17, blue: 0.18),
                         Color(red: 0.11, green: 0.11, blue: 0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
    }

    @ViewBuilder
    private func label(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(.system(size: 11))
        }
        .foregroundColor(.white.opacity(0.6))
    }
}

// MARK: - Gesamtausgaben Kachel (legacy, ersetzt durch CombinedSummaryCard)
struct AusgabenCard: View {
    var kfzTotal: Double = 0
    var privateTotal: Double = 0

    private var total: Double { kfzTotal + privateTotal }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Gesamtausgaben")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("nicht erstattbar")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            Text(total.euroFormatted)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider()

            if kfzTotal > 0 {
                ausgabenZeile("car.fill", .iosIndigo, "KFZ-Kosten", kfzTotal)
            }
            if privateTotal > 0 {
                ausgabenZeile("person.fill", Color.pink, "Private Ausgaben", privateTotal)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private func ausgabenZeile(_ icon: String, _ color: Color, _ label: String, _ amount: Double) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            Spacer()
            Text(amount.euroFormatted)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        Divider().padding(.leading, 60)
    }
}


// MARK: - Stat Tile (3 Kacheln unter dem Hero – kompakter)
struct StatTile: View {
    let icon: String
    let color: Color
    let label: String
    let amount: Double
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(color)
            }
            Spacer()
            Text(amount.euroFormatted)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Section Card
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().padding(.horizontal, 16)

            content()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

// MARK: - List Header Card (kompakter)
struct ListHeaderCard: View {
    let icon: String
    let color: Color
    let title: String
    let countLabel: String
    let total: Double

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(countLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(total.euroFormatted)
                .font(.system(size: 19, weight: .regular, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }
}

// MARK: - Labeled Row
struct LabeledRow: View {
    let label: String
    let value: String
    var valueColor: Color = .secondary

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundColor(valueColor)
        }
    }
}

// MARK: - Summary Row (Legacy-Kompatibilität)
struct SummaryRow: View {
    let label: String
    let value: String
    let subValue: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(subValue)
                    .font(.system(size: 18, weight: .regular, design: .monospaced))
                    .foregroundColor(color)
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Info Box
struct InfoBox: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.primary)
                .font(.subheadline)
                .padding(.top, 1)
            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color(.systemGray6))
    }
}


// MARK: - Wiederverwendbare Filter Chip Bar
struct FilterChipBar<Filter: RawRepresentable & CaseIterable & Hashable>: View where Filter.RawValue == String {
    @Binding var selection: Filter
    var labelFor: ((Filter) -> String)? = nil

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(Filter.allCases) as! [Filter], id: \.self) { filter in
                let isActive = selection == filter
                let label = labelFor?(filter) ?? filter.rawValue
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        selection = filter
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isActive {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 5, height: 5)
                        }
                        Text(label)
                            .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                            .foregroundColor(isActive ? .white : Color(.label))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isActive ? Color(red: 0.0, green: 0.38, blue: 0.75) : Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        Capsule()
                            .stroke(isActive ? Color.clear : Color(.separator).opacity(0.5), lineWidth: 0.5)
                    )
                    .shadow(color: isActive ? Color(red: 0.0, green: 0.38, blue: 0.75).opacity(0.35) : .clear, radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}


struct ScanButtonRow: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Beleg scannen")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(color)
                    Text("Kamera · Fotos – Daten automatisch übernehmen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}


struct DynamicSwipeModifier: ViewModifier {
    @AppStorage("swipeLeading1")       var leading1:  String = "delete"
    @AppStorage("swipeTrailing1")      var trailing1: String = "edit"
    @AppStorage("swipeTrailing2")      var trailing2: String = "duplicate"
    @AppStorage("swipeLeading1Color")  var leading1Color:  String = "red"
    @AppStorage("swipeTrailing1Color") var trailing1Color: String = "orange"
    @AppStorage("swipeTrailing2Color") var trailing2Color: String = "blue"

    let onDelete:    () -> Void
    let onEdit:      () -> Void
    let onDuplicate: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                actionButton(trailing1, colorKey: trailing1Color)
                if trailing2 != "none" { actionButton(trailing2, colorKey: trailing2Color) }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                actionButton(leading1, colorKey: leading1Color)
            }
    }

    @ViewBuilder
    private func actionButton(_ key: String, colorKey: String) -> some View {
        let tint = swipeColor(colorKey)
        switch key {
        case "delete":
            Button(role: .destructive, action: onDelete) {
                Label("Löschen", systemImage: "trash")
            }.tint(tint)
        case "edit":
            Button(action: onEdit) {
                Label("Bearbeiten", systemImage: "pencil")
            }.tint(tint)
        case "duplicate":
            if let dup = onDuplicate {
                Button(action: dup) {
                    Label("Kopieren", systemImage: "doc.on.doc")
                }.tint(tint)
            }
        default:
            EmptyView()
        }
    }

    private func swipeColor(_ key: String) -> Color {
        switch key {
        case "red":    return .red
        case "orange": return .orange
        case "blue":   return .blue
        case "green":  return .green
        case "purple": return .purple
        default:       return .gray
        }
    }
}

extension View {
    func dynamicSwipeActions(
        onDelete: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDuplicate: (() -> Void)? = nil
    ) -> some View {
        modifier(DynamicSwipeModifier(onDelete: onDelete, onEdit: onEdit, onDuplicate: onDuplicate))
    }
}
