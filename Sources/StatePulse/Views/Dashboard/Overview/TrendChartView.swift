import SwiftUI
import Charts

struct TrendChartView: View {
    let points: [DailyChartPoint]

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var metricManager = MetricManager.shared

    @State private var visibleMetricIds: Set<String> = []
    @State private var showMovingAverage: Bool = true

    private var theme: AppTheme {
        themeManager.theme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header & Series Toggles
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Динамика и тренды")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(theme.textPrimary)

                    Text("Интерактивный анализ колебаний состояния")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                // Series Toggle Pills
                HStack(spacing: 6) {
                    ForEach(metricManager.metrics) { metric in
                        let isVisible = visibleMetricIds.contains(metric.id)
                        togglePill(
                            title: metric.name,
                            color: metric.color,
                            isOn: isVisible
                        ) {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                if isVisible {
                                    if visibleMetricIds.count > 1 {
                                        visibleMetricIds.remove(metric.id)
                                    }
                                } else {
                                    visibleMetricIds.insert(metric.id)
                                }
                            }
                        }
                    }

                    togglePill(
                        title: "Тренд (7д)",
                        color: theme.textSecondary,
                        isOn: showMovingAverage
                    ) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            showMovingAverage.toggle()
                        }
                    }
                }
            }

            // Swift Chart
            if points.isEmpty {
                VStack {
                    Text("Нет данных за выбранный период")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                }
                .frame(height: 220)
                .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(points) { pt in
                        ForEach(metricManager.metrics) { metric in
                            if visibleMetricIds.contains(metric.id) {
                                let scoreVal = pt.score(for: metric.id)
                                if scoreVal > 0 {
                                    LineMark(
                                        x: .value("Дата", pt.date),
                                        y: .value(metric.name, scoreVal),
                                        series: .value("Серия", metric.name)
                                    )
                                    .foregroundStyle(metric.color)
                                    .interpolationMethod(.catmullRom)
                                    .lineStyle(StrokeStyle(lineWidth: 2.2))

                                    PointMark(
                                        x: .value("Дата", pt.date),
                                        y: .value(metric.name, scoreVal)
                                    )
                                    .foregroundStyle(metric.color)
                                    .symbolSize(18)
                                }
                            }
                        }

                        if showMovingAverage, let ma = pt.movingAverage, ma > 0 {
                            LineMark(
                                x: .value("Дата", pt.date),
                                y: .value("Тренд", ma),
                                series: .value("Серия", "Тренд")
                            )
                            .foregroundStyle(theme.textSecondary.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1.8, dash: [4, 4]))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .chartYScale(domain: 1...10)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [2, 4, 6, 8, 10]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(theme.cardBorder)
                        AxisValueLabel {
                            if let intVal = value.as(Int.self) {
                                Text("\(intVal)")
                                    .font(.system(size: 9))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(theme.cardBorder)
                        AxisValueLabel(format: .dateTime.month().day(), centered: true)
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
        .onAppear {
            if visibleMetricIds.isEmpty {
                visibleMetricIds = Set(metricManager.metrics.map { $0.id })
            }
        }
    }

    @ViewBuilder
    private func togglePill(title: String, color: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(isOn ? color : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)

                Text(title)
                    .font(.system(size: 11, weight: isOn ? .semibold : .regular))
                    .foregroundColor(isOn ? theme.textPrimary : theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isOn ? theme.cardBackground : Color.clear)
                    .overlay(
                        Capsule()
                            .stroke(theme.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
