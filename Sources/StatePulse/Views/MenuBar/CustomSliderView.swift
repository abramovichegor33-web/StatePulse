import SwiftUI

struct CustomSliderView: View {
    let metric: MetricDefinition
    @Binding var value: Int

    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onAddNew: (() -> Void)? = nil
    var onResetToDefault: (() -> Void)? = nil

    @ObservedObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme {
        themeManager.theme
    }

    private var stateDescription: String {
        switch value {
        case 1...2: return "Истощение"
        case 3...4: return "Усталость"
        case 5...6: return "Норма"
        case 7...8: return "Бодрость"
        case 9...10: return "Пик ресурса"
        default: return ""
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Header Row: Icon, Title & Value
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Image(systemName: metric.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(metric.color)

                    Text(metric.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    if let onEdit = onEdit {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 9))
                                .foregroundColor(theme.textSecondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .help("Изменить название или цвет")
                    }
                }

                Spacer()

                HStack(spacing: 5) {
                    Text(stateDescription)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.textSecondary)

                    Text("\(value)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .frame(minWidth: 18, alignment: .trailing)
                }
            }

            // Interactive Segmented Slider Bar
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let segmentSpacing: CGFloat = 3
                let count = 10
                let totalSpacing = segmentSpacing * CGFloat(count - 1)
                let segmentWidth = (totalWidth - totalSpacing) / CGFloat(count)

                HStack(spacing: segmentSpacing) {
                    ForEach(1...10, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(
                                index <= value
                                    ? metric.color
                                    : (theme.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                            )
                            .frame(width: segmentWidth, height: 14)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                                    value = index
                                }
                            }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let locationX = max(0, min(totalWidth, gesture.location.x))
                            let fraction = locationX / totalWidth
                            let calculated = Int(fraction * 10) + 1
                            let clamped = max(1, min(10, calculated))
                            if clamped != value {
                                withAnimation(.spring(response: 0.18, dampingFraction: 0.8)) {
                                    value = clamped
                                }
                            }
                        }
                )
            }
            .frame(height: 14)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .contextMenu {
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("Изменить шкалу «\(metric.name)»...", systemImage: "pencil")
                }
            }

            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Удалить шкалу", systemImage: "trash")
                }
            }

            if let onAddNew = onAddNew {
                Button(action: onAddNew) {
                    Label("Добавить новую шкалу...", systemImage: "plus")
                }
            }

            if let onReset = onResetToDefault {
                Button(action: onReset) {
                    Label("Восстановить стандартные шкалы", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }
}
