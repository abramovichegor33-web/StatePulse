import SwiftUI

struct TagChipsView: View {
    @Binding var selectedTags: Set<String>
    @ObservedObject private var themeManager = ThemeManager.shared

    @AppStorage("statepulse_hidden_preset_tags") private var hiddenPresetTagsData: String = ""

    @State private var customTags: [TagModel] = []
    @State private var isAddingNewTag = false
    @State private var newTagName = ""

    private var theme: AppTheme {
        themeManager.theme
    }

    private func getHiddenPresetTags() -> Set<String> {
        let split = hiddenPresetTagsData.split(separator: "|||").map(String.init)
        return Set(split)
    }

    private var allTags: [TagModel] {
        let hidden = getHiddenPresetTags()
        var combined = TagModel.defaultPresets.filter { !hidden.contains($0.name) }
        let defaultNames = Set(combined.map { $0.name })
        for custom in customTags where !defaultNames.contains(custom.name) {
            combined.append(custom)
        }
        return combined
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("КОНТЕКСТ ДНЯ")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .tracking(0.6)

                Spacer()

                if !isAddingNewTag {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isAddingNewTag = true
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Свой тег")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Inline Add New Tag Input
            if isAddingNewTag {
                HStack(spacing: 6) {
                    TextField("Название тега...", text: $newTagName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(theme.cardBorder, lineWidth: 1)
                                )
                        )
                        .onSubmit {
                            commitNewTag()
                        }

                    Button(action: commitNewTag) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isAddingNewTag = false
                            newTagName = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Wrapping Chips Grid with Context Menu on Empty Space
            ZStack(alignment: .topLeading) {
                // Background invisible rectangle to catch right clicks on empty space
                Color.clear
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            restoreDefaultTags()
                        } label: {
                            Label("Восстановить стандартные теги", systemImage: "arrow.counterclockwise")
                        }

                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                isAddingNewTag = true
                            }
                        } label: {
                            Label("Добавить свой тег...", systemImage: "plus")
                        }
                    }

                WrappingChipsLayout(spacing: 6) {
                    ForEach(allTags) { tag in
                        let isSelected = selectedTags.contains(tag.name)
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                if isSelected {
                                    selectedTags.remove(tag.name)
                                } else {
                                    selectedTags.insert(tag.name)
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: tag.icon)
                                    .font(.system(size: 10))

                                Text(tag.name)
                                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(isSelected ? theme.accent : theme.cardBackground)
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color.clear : theme.cardBorder, lineWidth: 1)
                                    )
                            )
                            .foregroundColor(isSelected ? theme.accentText : theme.textPrimary)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteTag(tag)
                            } label: {
                                Label("Удалить тег «\(tag.name)»", systemImage: "trash")
                            }

                            Button {
                                restoreDefaultTags()
                            } label: {
                                Label("Восстановить стандартные теги", systemImage: "arrow.counterclockwise")
                            }
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                restoreDefaultTags()
            } label: {
                Label("Восстановить стандартные теги", systemImage: "arrow.counterclockwise")
            }

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isAddingNewTag = true
                }
            } label: {
                Label("Добавить свой тег...", systemImage: "plus")
            }
        }
        .onAppear {
            loadCustomTags()
        }
    }

    private func deleteTag(_ tag: TagModel) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if tag.isDefault {
                var hidden = getHiddenPresetTags()
                hidden.insert(tag.name)
                hiddenPresetTagsData = hidden.joined(separator: "|||")
            } else {
                DatabaseManager.shared.deleteCustomTag(name: tag.name)
            }
            selectedTags.remove(tag.name)
            loadCustomTags()
        }
    }

    private func restoreDefaultTags() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            hiddenPresetTagsData = ""
            loadCustomTags()
        }
    }

    private func commitNewTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        DatabaseManager.shared.saveCustomTag(name: trimmed)
        selectedTags.insert(trimmed)
        newTagName = ""
        isAddingNewTag = false
        loadCustomTags()
    }

    private func loadCustomTags() {
        customTags = DatabaseManager.shared.fetchCustomTags()
    }
}

// Custom flow layout for tags wrapping
struct WrappingChipsLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowMaxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += rowMaxHeight + spacing
                rowMaxHeight = 0
            }
            rowMaxHeight = max(rowMaxHeight, size.height)
            currentX += size.width + spacing
        }
        height = currentY + rowMaxHeight
        return CGSize(width: width, height: max(height, 24))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowMaxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowMaxHeight + spacing
                rowMaxHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            rowMaxHeight = max(rowMaxHeight, size.height)
            currentX += size.width + spacing
        }
    }
}
