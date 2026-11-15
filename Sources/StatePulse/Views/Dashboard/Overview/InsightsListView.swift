import SwiftUI

struct InsightsListView: View {
    let insights: [InsightModel]

    @ObservedObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme {
        themeManager.theme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(theme.compositeColor)

                        Text("Инсайты и корреляции")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                    }

                    Text("Алгоритмический поиск скрытых закономерностей")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(insights) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insight.category.icon)
                            .font(.system(size: 18))
                            .foregroundColor(iconColor(for: insight.category))
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(insight.title)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(theme.textPrimary)

                                Spacer()

                                if abs(insight.deltaPercentage) > 0 {
                                    let isPos = insight.deltaPercentage > 0
                                    Text("\(isPos ? "+" : "")\(String(format: "%.0f%%", insight.deltaPercentage))")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(isPos ? .green : (insight.category == .screenTime ? .orange : .red))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background((isPos ? Color.green : Color.red).opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }

                            Text(insight.description)
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(theme.cardBorder, lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    private func iconColor(for category: InsightCategory) -> Color {
        switch category {
        case .positive: return .green
        case .negative: return .red
        case .screenTime: return .orange
        case .neutral: return theme.textSecondary
        }
    }
}
