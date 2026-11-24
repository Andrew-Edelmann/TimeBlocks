import SwiftUI
import SwiftData

/// Lets the user tag a block. Type a new tag ("focus" or "project: thesis")
/// or tap any tag created before. Tapping again removes it from this block.
/// Long-press a tag to delete it everywhere.
struct TagPicker: View {
    @Environment(\.modelContext) private var context
    @Bindable var block: Block
    @Query(sort: [SortDescriptor(\Tag.key), SortDescriptor(\Tag.value)])
    private var allTags: [Tag]
    @State private var input = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("New tag, or key: value", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addInput)
                Button("Add", action: addInput)
                    .disabled(Tag.parse(input) == nil)
            }

            if !allTags.isEmpty {
                ScrollView {
                    FlowLayout(spacing: 6) {
                        ForEach(allTags) { tag in
                            chip(tag)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 130)
            }
        }
    }

    private func chip(_ tag: Tag) -> some View {
        let on = block.hasTag(tag)
        return Text(tag.displayName)
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(on ? Color.accentColor : Color.secondary.opacity(0.15))
            .foregroundStyle(on ? Color.white : Color.primary)
            .clipShape(Capsule())
            .onTapGesture { block.toggle(tag) }
            .contextMenu {
                Button("Delete tag", role: .destructive) { context.delete(tag) }
            }
    }

    private func addInput() {
        guard let (key, value) = Tag.parse(input) else { return }
        let existing = allTags.first {
            $0.key.caseInsensitiveCompare(key) == .orderedSame
                && $0.value.caseInsensitiveCompare(value) == .orderedSame
        }
        let tag = existing ?? {
            let new = Tag(key: key, value: value)
            context.insert(new)
            return new
        }()
        if !block.hasTag(tag) { block.toggle(tag) }
        input = ""
    }
}

/// Simple wrapping layout: places views left to right, then starts a new row.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
