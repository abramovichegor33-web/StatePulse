import SwiftUI

struct MetricSummaryCardsView: View {
    let summary: MetricSummary
    @Binding var selectedPeriod: AnalyticsPeriod

    @ObservedObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme {
        themeManager.theme
    }

    var body: some View {
        VStack(spacing: 16) {
            // Period Selector & Stats Summary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Сводка состояния")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(theme.textPrimary)

                    Text("Всего чек-инов за период: \(summary.totalEntries)")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                // Period Switcher
                HStack(spacing: 4) {
                    ForEach(AnalyticsPeriod.allCases) { period in
                        let isSelected = selectedPeriod == period
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedPeriod = period
                            }
                        }) {
                            Text(period.title)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? theme.accent : Color.clear)
                                )
                                .foregroundColor(isSelected ? theme.accentText : theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    Capsule()
                        .fill(theme.cardBackground)
                        .overlay(
                            Capsule()
                                .stroke(theme.cardBorder, lineWidth: 1)
                        )
                )
            }

            // Cards Grid (Dynamic Cards for all metrics + Composite Balance)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 240))], spacing: 12) {
                ForEach(summary.metricStats) { stat in
                    metricCard(
                        title: stat.name,
                        value: stat.average,
                        delta: stat.delta,
                        icon: stat.icon,
                        accentColor: stat.color
                    )
                }

                metricCard(
                    title: "Баланс состояния",
                    value: summary.compositeAvg,
                    delta: summary.compositeDelta,
                    icon: "sparkles",
                    accentColor: theme.compositeColor
                )
            }
        }
    }

    @ViewBuilder
    private func metricCard(title: String, value: Double, delta: Double, icon: String, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(accentColor)

                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if abs(delta) >= 0.5 {
                    let isPositive = delta > 0
                    HStack(spacing: 2) {
                        Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "%.0f%%", abs(delta)))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(isPositive ? .green : .red)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background((isPositive ? Color.green : Color.red).opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value > 0 ? String(format: "%.1f", value) : "—")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                if value > 0 {
                    Text("/ 10")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
    }
}
