import SwiftUI

/// Pill-shaped segmented control — ports the design's `segTrackStyle`/`segStyle`
/// pattern used for backend/appearance/language switches throughout the app.
struct SegmentedPillControl<Item: Identifiable>: View {
    let items: [Item]
    let label: (Item) -> String
    let isSelected: (Item) -> Bool
    let onSelect: (Item) -> Void
    let theme: Theme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                Text(label(item))
                    .font(AppFont.body(13, weight: .semibold))
                    .foregroundColor(isSelected(item) ? theme.onAccentText : theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(isSelected(item) ? theme.accent : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(item) }
            }
        }
        .padding(4)
        .background(Capsule().fill(theme.surface2))
    }
}
