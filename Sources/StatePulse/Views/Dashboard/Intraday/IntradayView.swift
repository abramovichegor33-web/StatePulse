import SwiftUI
import Charts

struct IntradayView: View {
    let checkIns: [CheckInRecord]

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var metricManager = MetricManager.shared

    enum RhythmScope: Int {
        case day = 0
        case allTime = 1
    }

    @State private var selectedDayDate: Date = Date()
    @State private var activeMetricToggles: Set<String> = []
    @State private var scope: RhythmScope = .day

    private var theme: AppTheme {
        themeManager.theme
    }

    private var scopedRecords: [CheckInRecord] {
        switch scope {
        case .day:
            return selectedDayRecords
        case .allTime:
            return checkIns
        }
    }

    private var phaseStats: [IntradayPhaseStat] {
        AnalyticsEngine.shared.calculatePhaseStats(records: scopedRecords, metrics: metricManager.metrics)
    }

    private var hourlyCurve: [HourlyCurvePoint] {
        AnalyticsEngine.shared.generateHourlyCurve(records: scopedRecords, metrics: metricManager.metrics)
    }

    // Filter check-ins for the selected day
    private var selectedDayRecords: [CheckInRecord] {
        let calendar = Calendar.current
        return checkIns.filter {
            calendar.isDate($0.timestamp, inSameDayAs: selectedDayDate)
        }.sorted(by: { $0.timestamp < $1.timestamp })
    }

    private var selectedDayFormatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDayDate) {
            return "Сегодня"
        } else if calendar.isDateInYesterday(selectedDayDate) {
            return "Вчера"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "d MMMM yyyy"
            return formatter.string(from: selectedDayDate)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section 1: Day Phases Cards (Morning, Afternoon, Evening, Night)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ритм фаз суток")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(theme.textPrimary)

                            Text(scope == .day ? "Самочувствие за выбранный день (\(selectedDayFormatted.lowercased()))" : "Усредненный биоритм за всё время наблюдений")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        Picker("", selection: $scope) {
                            Text("За день (\(selectedDayFormatted))").tag(RhythmScope.day)
                            Text("За всё время").tag(RhythmScope.allTime)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(phaseStats) { stat in
                            phaseCard(stat: stat)
                        }
                    }
                }

                // Section 2: 24-Hour Circadian Curve Chart
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Суточный профиль энергии (24 ч)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(theme.textPrimary)

                            Text("Почасовая динамика показателей от пробуждения до сна")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        // Metric Toggles
                        HStack(spacing: 6) {
                            ForEach(metricManager.metrics) { metric in
                                let isOn = activeMetricToggles.contains(metric.id)
                                Button(action: {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                        if isOn {
                                            if activeMetricToggles.count > 1 {
                                                activeMetricToggles.remove(metric.id)
                                            }
                                        } else {
                                            activeMetricToggles.insert(metric.id)
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(isOn ? metric.color : Color.gray.opacity(0.3))
                                            .frame(width: 6, height: 6)
                                        Text(metric.name)
                                            .font(.system(size: 11, weight: isOn ? .semibold : .regular))
                                            .foregroundColor(isOn ? theme.textPrimary : theme.textSecondary)
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
                    }

                    // Chart
                    let pointsWithData = hourlyCurve.filter { $0.sampleCount > 0 }
                    if pointsWithData.isEmpty {
                        VStack {
                            Text("Сделайте несколько чек-инов в разное время дня, чтобы увидеть суточную кривую")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)
                        }
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                    } else {
                        Chart {
                            ForEach(hourlyCurve) { pt in
                                ForEach(metricManager.metrics) { metric in
                                    if activeMetricToggles.contains(metric.id) {
                                        let val = pt.metricScores[metric.id] ?? 0
                                        if val > 0 {
                                            LineMark(
                                                x: .value("Время", pt.hourLabel),
                                                y: .value(metric.name, val),
                                                series: .value("Серия", metric.name)
                                            )
                                            .foregroundStyle(metric.color)
                                            .interpolationMethod(.catmullRom)
                                            .lineStyle(StrokeStyle(lineWidth: 2.2))

                                            PointMark(
                                                x: .value("Время", pt.hourLabel),
                                                y: .value(metric.name, val)
                                            )
                                            .foregroundStyle(metric.color)
                                            .symbolSize(18)
                                        }
                                    }
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
                            AxisMarks(values: ["06:00", "09:00", "12:00", "15:00", "18:00", "21:00", "23:00"]) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(theme.cardBorder)
                                AxisValueLabel()
                            }
                        }
                        .frame(height: 180)
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

                // Section 3: Day Diary / Timeline of Selected Day
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Хроника срезов за день")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(theme.textPrimary)

                            Text("Поминутная история самочувствия в течение конкретного дня")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        // Day Switcher Controls
                        HStack(spacing: 6) {
                            Button(action: {
                                if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDayDate) {
                                    selectedDayDate = prev
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(6)
                                    .background(theme.background)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Text(selectedDayFormatted)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(theme.textPrimary)
                                .frame(minWidth: 80)

                            Button(action: {
                                if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDayDate) {
                                    // Don't go into the future
                                    if next <= Date() {
                                        selectedDayDate = next
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(6)
                                    .background(theme.background)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(Calendar.current.isDateInToday(selectedDayDate))

                            Button("Сегодня") {
                                selectedDayDate = Date()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.background)
                            .cornerRadius(6)
                            .foregroundColor(theme.textSecondary)
                        }
                    }

                    // Slices for this day
                    if selectedDayRecords.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 24))
                                .foregroundColor(theme.textSecondary)
                            Text("В этот день срезов состояния не было")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(selectedDayRecords) { record in
                                dayRecordTimelineRow(record: record)
                            }
                        }
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
            }
            .padding(24)
        }
        .onAppear {
            if activeMetricToggles.isEmpty {
                activeMetricToggles = Set(metricManager.metrics.map { $0.id })
            }
        }
    }

    @ViewBuilder
    private func phaseCard(stat: IntradayPhaseStat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: stat.phase.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(stat.phase.color)

                    Text(stat.phase.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                }

                Spacer()

                Text("\(stat.checkInCount)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.background)
                    .clipShape(Capsule())
            }

            Text(stat.phase.timeRangeString)
                .font(.system(size: 9))
                .foregroundColor(theme.textSecondary)

            Divider()

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(stat.averageScore > 0 ? String(format: "%.1f", stat.averageScore) : "—")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                if stat.averageScore > 0 {
                    Text("/ 10")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSecondary)
                }
            }

            // Metric breakdown in this phase
            if stat.checkInCount > 0 {
                VStack(spacing: 3) {
                    ForEach(metricManager.metrics.prefix(3)) { metric in
                        let val = stat.metricAverages[metric.id] ?? 0
                        HStack {
                            Text(metric.name)
                                .font(.system(size: 9))
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text(val > 0 ? String(format: "%.1f", val) : "—")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(metric.color)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func dayRecordTimelineRow(record: CheckInRecord) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Phase icon & Time
            HStack(spacing: 6) {
                Image(systemName: record.phase.icon)
                    .font(.system(size: 12))
                    .foregroundColor(record.phase.color)

                Text(record.timeString)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.textPrimary)

                Text(record.phase.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
            .frame(width: 140, alignment: .leading)

            // Scores Pills
            HStack(spacing: 6) {
                ForEach(metricManager.metrics) { metric in
                    let val = record.score(for: metric.id)
                    let firstLetter = String(metric.name.prefix(1)).uppercased()
                    HStack(spacing: 2) {
                        Text(firstLetter)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(metric.color)
                        Text("\(val)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(metric.color.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            // Tags
            if !record.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(record.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.cardBorder.opacity(0.6))
                            .clipShape(Capsule())
                            .foregroundColor(theme.textPrimary)
                    }
                }
            }

            // Note
            if !record.note.isEmpty {
                Text(record.note)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
    }
}
